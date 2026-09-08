package handler

import (
	"errors"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type AIHandler struct {
	groq *service.GroqService
}

func NewAIHandler(groq *service.GroqService) *AIHandler {
	return &AIHandler{groq: groq}
}

type startSessionBody struct {
	CategoryID *string `json:"category_id"`
}

func (h *AIHandler) StartSession(c *gin.Context) {
	userID := c.GetString("user_id")
	var body startSessionBody
	_ = c.ShouldBindJSON(&body)
	s, err := h.groq.StartSession(c.Request.Context(), userID, body.CategoryID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, s)
}

type sendMessageBody struct {
	Message string `json:"message" binding:"required"`
}

// SendMessage sends the user's message (issue description, optionally
// including uploaded image URLs as text context) to Groq and returns both
// the raw assistant reply and — when the model returned valid JSON — a
// structured "diagnosis" object the Flutter app can render as a diagnosis
// card. "diagnosis" is null if the model's reply couldn't be parsed as JSON;
// callers should fall back to displaying "reply" as plain text in that case.
func (h *AIHandler) SendMessage(c *gin.Context) {
	sessionID := c.Param("id")
	var body sendMessageBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	reply, diagnosis, err := h.groq.SendMessage(c.Request.Context(), sessionID, body.Message)
	if err != nil {
		log.Printf("ai_handler: SendMessage failed for session %s: %v", sessionID, err)
		utils.Error(c, http.StatusBadGateway, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"reply": reply, "diagnosis": diagnosis})
}

func (h *AIHandler) History(c *gin.Context) {
	sessionID := c.Param("id")
	msgs, err := h.groq.History(c.Request.Context(), sessionID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, msgs)
}

const maxAudioBytes = 15 << 20 // 15 MB

// Below this, a recording is almost certainly an accidental tap rather than
// real speech (a fraction of a second of AAC audio) — reject before even
// calling Groq, since that's the #1 cause of Whisper hallucinating filler
// text like "Thank you." instead of a real transcription.
const minAudioBytes = 2 << 10 // 2 KB

// Transcribe accepts a multipart audio file (field name "file") and returns
// {"text": "..."} — the voice note transcribed to text via Groq Whisper.
// Used by the Issue Details screen's "Record voice description" button.
func (h *AIHandler) Transcribe(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAudioBytes)

	fileHeader, err := c.FormFile("file")
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "audio file is required (multipart field \"file\")")
		return
	}
	if fileHeader.Size > maxAudioBytes {
		utils.Error(c, http.StatusBadRequest, "audio file too large (max 15MB)")
		return
	}
	if fileHeader.Size < minAudioBytes {
		utils.Error(c, http.StatusUnprocessableEntity, "Recording was too short — please hold the button and speak for a couple of seconds")
		return
	}

	f, err := fileHeader.Open()
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "failed to read audio file")
		return
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "failed to read audio file")
		return
	}

	text, err := h.groq.TranscribeAudio(c.Request.Context(), data, fileHeader.Filename)
	if err != nil {
		if errors.Is(err, service.ErrNoSpeechDetected) {
			utils.Error(c, http.StatusUnprocessableEntity, "Couldn't hear any speech in that recording — please try again and speak clearly")
			return
		}
		log.Printf("ai_handler: TranscribeAudio failed: %v", err)
		utils.Error(c, http.StatusBadGateway, err.Error())
		return
	}

	utils.Success(c, http.StatusOK, gin.H{"text": text})
}