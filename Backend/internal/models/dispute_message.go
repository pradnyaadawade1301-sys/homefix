package models

import "time"

// DisputeMessage is one message in the live-chat thread attached to a
// dispute (complaint). SenderRole distinguishes the customer/technician
// side ("user") from the organization's support/admin side ("admin") — the
// frontend uses this to align bubbles left/right.
type DisputeMessage struct {
	ID         string    `json:"id"`
	DisputeID  string    `json:"dispute_id"`
	SenderID   *string   `json:"sender_id,omitempty"`
	SenderRole string    `json:"sender_role"` // user | admin
	Message    string    `json:"message"`
	CreatedAt  time.Time `json:"created_at"`

	// AttachmentURL/AttachmentType hold a photo or video attached to this
	// message (e.g. a customer showing the technician's shoddy wiring
	// instead of/alongside typing it out). AttachmentType is "image" or
	// "video"; both are nil for a plain text message.
	AttachmentURL  *string `json:"attachment_url,omitempty"`
	AttachmentType *string `json:"attachment_type,omitempty"`

	// Joined display field, admin panel only.
	SenderName string `json:"sender_name,omitempty"`
}
