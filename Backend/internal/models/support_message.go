package models

import "time"

// SupportMessage is one message in the general "Contact Support" live chat,
// reachable from the Profile screen — talking directly to HomeFix support,
// not tied to any specific booking/consultation/dispute. SenderRole is
// "user" (the customer/technician) or "admin" (support).
type SupportMessage struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	SenderRole     string    `json:"sender_role"` // user | admin
	Message        string    `json:"message"`
	AttachmentURL  *string   `json:"attachment_url,omitempty"`
	AttachmentType *string   `json:"attachment_type,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
}

// SupportChatSummary is one row in the admin panel's support-inbox list —
// one per user who has ever messaged support, with a preview of the latest
// message so support can see what needs attention without opening every
// thread.
type SupportChatSummary struct {
	UserID         string    `json:"user_id"`
	UserName       string    `json:"user_name"`
	UserPhone      string    `json:"user_phone,omitempty"`
	LastMessage    string    `json:"last_message"`
	LastMessageAt  time.Time `json:"last_message_at"`
	LastSenderRole string    `json:"last_sender_role"`
}
