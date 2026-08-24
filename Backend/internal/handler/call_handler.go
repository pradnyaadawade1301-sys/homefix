package handler

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

// CallHandler runs a pure WebRTC *signaling* relay: it only ever forwards the small
// JSON handshake messages (SDP offer/answer, ICE candidates) that two peers need to
// find each other. It never sees, stores, or relays the actual audio/video — once the
// two devices exchange that handshake, the call media flows directly device-to-device
// (peer-to-peer), through TURN only when a direct/STUN path isn't reachable.
type CallHandler struct {
	bookingRepo    *repository.BookingRepository
	technicianRepo *repository.TechnicianRepository
	consultRepo    *repository.ConsultationRepository
	accessSecret   string

	mu    sync.Mutex
	rooms map[string]map[*websocket.Conn]string // roomID -> {conn: userID}
}

func NewCallHandler(bookingRepo *repository.BookingRepository, technicianRepo *repository.TechnicianRepository, consultRepo *repository.ConsultationRepository, accessSecret string) *CallHandler {
	return &CallHandler{
		bookingRepo:    bookingRepo,
		technicianRepo: technicianRepo,
		consultRepo:    consultRepo,
		accessSecret:   accessSecret,
		rooms:          make(map[string]map[*websocket.Conn]string),
	}
}

var callUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

const (
	pongWait   = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10 // must be < pongWait
)

// Signal upgrades GET /ws/call/:id?token=... to a WebSocket. Exactly the two
// participants of that booking/consultation are allowed to join; anyone else is
// rejected before the upgrade completes. A room only ever holds 2 sockets — a
// third connection attempt (e.g. a stale reconnect) is rejected rather than
// silently breaking the existing pair.
func (h *CallHandler) Signal(c *gin.Context) {
	roomID := c.Param("id")
	token := c.Query("token")

	claims, err := utils.ParseAccessToken(token, h.accessSecret)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
		return
	}

	if !h.authorize(c.Request.Context(), roomID, claims.UserID) {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "not a participant of this call"})
		return
	}

	conn, err := callUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("call signaling: upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	if !h.join(roomID, conn, claims.UserID) {
		_ = conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"room-full"}`))
		return
	}
	defer h.leave(roomID, conn)

	// Keepalive: mobile networks drop idle sockets silently. Ping every
	// pingPeriod and require a pong within pongWait, or we treat the peer as
	// gone (ReadMessage below will then error out and we clean up).
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	stopPing := make(chan struct{})
	go h.pinger(conn, stopPing)
	defer close(stopPing)

	for {
		messageType, payload, err := conn.ReadMessage()
		if err != nil {
			break // peer disconnected, closed the call, or missed too many pongs
		}
		h.relay(roomID, conn, messageType, payload)
	}
}

func (h *CallHandler) pinger(conn *websocket.Conn, stop <-chan struct{}) {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		case <-stop:
			return
		}
	}
}

// authorize checks that userID is either the customer or the assigned technician
// on the given booking (falls back to trying it as a live-consultation id — same
// room, same relay, different source table for "who's allowed in").
func (h *CallHandler) authorize(ctx context.Context, roomID, userID string) bool {
	booking, err := h.bookingRepo.GetByID(ctx, roomID)
	if err == nil && booking != nil {
		if userID == booking.CustomerID {
			return true
		}
		if booking.TechnicianID != nil {
			if tech, err := h.technicianRepo.GetByID(ctx, *booking.TechnicianID); err == nil && tech != nil && tech.UserID == userID {
				return true
			}
		}
		return false
	}

	consult, err := h.consultRepo.GetByID(ctx, roomID)
	if err != nil || consult == nil {
		return false
	}
	if userID == consult.CustomerID {
		return true
	}
	if consult.TechnicianID != nil {
		if tech, err := h.technicianRepo.GetByID(ctx, *consult.TechnicianID); err == nil && tech != nil && tech.UserID == userID {
			return true
		}
	}
	return false
}

// join adds a connection to its room. Rooms cap at 2 participants.
//
// THE FIX: "peer-joined" is broadcast to BOTH sockets at the exact moment the
// room reaches 2 members — not just to whichever socket happened to already be
// waiting. Previously only the *pre-existing* socket was notified, so whichever
// side connected second (in practice, almost always the customer, since the
// technician's app jumps into the call screen immediately on accept while the
// customer's app gets there ~1.5s later via polling) never learned a peer was
// present. Since the customer is always the offer-sender, that offer never got
// sent and the call hung on "Connecting..." forever on both ends. Notifying
// both sides removes any dependency on join order.
func (h *CallHandler) join(roomID string, conn *websocket.Conn, userID string) bool {
	h.mu.Lock()
	if h.rooms[roomID] == nil {
		h.rooms[roomID] = make(map[*websocket.Conn]string)
	}
	room := h.rooms[roomID]

	if len(room) >= 2 {
		h.mu.Unlock()
		return false
	}

	room[conn] = userID
	size := len(room)

	var peers []*websocket.Conn
	if size == 2 {
		for c := range room {
			peers = append(peers, c)
		}
	}
	h.mu.Unlock()

	for _, peer := range peers {
		_ = peer.WriteMessage(websocket.TextMessage, []byte(`{"type":"peer-joined"}`))
	}
	return true
}

// leave removes a connection and tells the remaining peer (if any) that the call
// ended, so their UI can hang up cleanly instead of hanging on a dead connection.
func (h *CallHandler) leave(roomID string, conn *websocket.Conn) {
	h.mu.Lock()
	room := h.rooms[roomID]
	if room != nil {
		delete(room, conn)
		if len(room) == 0 {
			delete(h.rooms, roomID)
		}
	}
	peers := make([]*websocket.Conn, 0, len(room))
	for c := range room {
		peers = append(peers, c)
	}
	h.mu.Unlock()

	for _, peer := range peers {
		_ = peer.WriteMessage(websocket.TextMessage, []byte(`{"type":"peer-left"}`))
	}
}

// relay forwards a signaling message verbatim to the other participant in the
// room. This handler never parses, inspects, or stores the payload — it's a
// mailbox, not a media server.
func (h *CallHandler) relay(roomID string, from *websocket.Conn, messageType int, payload []byte) {
	h.mu.Lock()
	room := h.rooms[roomID]
	peers := make([]*websocket.Conn, 0, len(room))
	for c := range room {
		if c != from {
			peers = append(peers, c)
		}
	}
	h.mu.Unlock()

	for _, peer := range peers {
		if err := peer.WriteMessage(messageType, payload); err != nil {
			log.Printf("call signaling: relay failed: %v", err)
		}
	}
}