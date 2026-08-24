package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"regexp"
	"strings"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type GroqService struct {
	apiKey string
	model  string
	apiURL string
	client *http.Client
	aiRepo *repository.AIRepository
}

func NewGroqService(apiKey, model, apiURL string, aiRepo *repository.AIRepository) *GroqService {
	return &GroqService{
		apiKey: apiKey,
		model:  model,
		apiURL: apiURL,
		client: &http.Client{Timeout: 30 * time.Second},
		aiRepo: aiRepo,
	}
}

type groqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type groqRequest struct {
	Model    string        `json:"model"`
	Messages []groqMessage `json:"messages"`
}

type groqChoice struct {
	Message groqMessage `json:"message"`
}

type groqResponse struct {
	Choices []groqChoice `json:"choices"`
	Error   *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// systemPrompt instructs the model to act as a triage assistant AND to always
// reply with a single strict JSON object matching AIDiagnosisResult, so the
// backend can parse it into structured fields for the Flutter diagnosis card.
//
// NOTE: the configured model (llama-3.3-70b-versatile) is text-only — it
// cannot visually inspect uploaded images. Image URLs are passed along as
// context only (so the model knows photos were attached and can factor that
// into its confidence score), not analyzed pixel-by-pixel. Swap GROQ_MODEL to
// a vision-capable model later if real image analysis is needed.
const systemPrompt = `You are HomeFix Live's AI diagnosis assistant. Customers describe home repair
problems (plumbing, electrical, appliance, carpentry, AC, roofing, painting, etc), optionally with
photo URLs attached (you cannot see the photos themselves, only that they exist).

You must ALWAYS reply with ONLY a single valid JSON object — no markdown, no code fences, no prose
before or after it — matching exactly this schema:

{
  "possible_fault": "short string describing the likely fault",
  "causes": ["cause 1", "cause 2"],
  "follow_up_questions": ["question 1", "question 2"],
  "confidence_score": 0-100 number,
  "estimated_cost_min": number (INR),
  "estimated_cost_max": number (INR),
  "estimated_time_minutes": integer,
  "can_solve_remotely": true or false,
  "recommendation": "remote" or "onsite"
}

Guidelines:
- If the description is vague or you are unsure, set confidence_score low (below 50) and include
  clarifying items in follow_up_questions.
- can_solve_remotely/recommendation="remote" only for issues genuinely fixable via guided video
  instructions (e.g. resetting a breaker, restarting an appliance). Anything involving wiring,
  gas, structural, or physical part replacement should be "onsite".
- estimated_cost_min/max should be realistic ranges in Indian Rupees for a home-service visit.
- Never claim to be a licensed professional; you are a triage/estimation assistant only.
- Output JSON only. Do not wrap it in backticks or add any explanation text.`

// StartSession opens a new AI diagnosis session persisted in Postgres.
func (s *GroqService) StartSession(ctx context.Context, userID string, categoryID *string) (*models.AIDiagnosisSession, error) {
	return s.aiRepo.CreateSession(ctx, userID, categoryID)
}

// SendMessage stores the user's message, calls the real Groq chat completions API,
// stores the assistant's raw reply, and attempts to parse it into a structured
// AIDiagnosisResult. If parsing fails (model didn't return valid JSON), diagnosis
// is nil and the caller should fall back to showing the raw reply text.
func (s *GroqService) SendMessage(ctx context.Context, sessionID, userMessage string) (string, *models.AIDiagnosisResult, error) {
	if _, err := s.aiRepo.AddMessage(ctx, sessionID, "user", userMessage); err != nil {
		return "", nil, fmt.Errorf("groq: failed to store user message: %w", err)
	}

	history, err := s.aiRepo.ListMessages(ctx, sessionID)
	if err != nil {
		return "", nil, fmt.Errorf("groq: failed to load session history: %w", err)
	}

	messages := []groqMessage{{Role: "system", Content: systemPrompt}}
	for _, m := range history {
		messages = append(messages, groqMessage{Role: m.Role, Content: m.Content})
	}

	reqBody := groqRequest{Model: s.model, Messages: messages}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return "", nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.apiURL, bytes.NewReader(payload))
	if err != nil {
		return "", nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+s.apiKey)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", nil, fmt.Errorf("groq: request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", nil, err
	}

	var gr groqResponse
	if err := json.Unmarshal(body, &gr); err != nil {
		return "", nil, fmt.Errorf("groq: failed to parse response: %w", err)
	}
	if gr.Error != nil {
		return "", nil, fmt.Errorf("groq: api error: %s", gr.Error.Message)
	}
	if len(gr.Choices) == 0 {
		return "", nil, fmt.Errorf("groq: empty response from model")
	}

	reply := gr.Choices[0].Message.Content

	if _, err := s.aiRepo.AddMessage(ctx, sessionID, "assistant", reply); err != nil {
		return "", nil, fmt.Errorf("groq: failed to store assistant reply: %w", err)
	}

	diagnosis := parseDiagnosisJSON(reply)
	return reply, diagnosis, nil
}

// parseDiagnosisJSON extracts the first {...} JSON object from the model's
// reply and unmarshals it into AIDiagnosisResult. Returns nil if no valid
// JSON diagnosis could be parsed (caller falls back to raw text display).
func parseDiagnosisJSON(reply string) *models.AIDiagnosisResult {
	trimmed := strings.TrimSpace(reply)

	// Strip accidental markdown code fences if the model added them anyway.
	if strings.HasPrefix(trimmed, "```") {
		re := regexp.MustCompile("(?s)```(?:json)?\\s*(.*?)\\s*```")
		if m := re.FindStringSubmatch(trimmed); len(m) == 2 {
			trimmed = m[1]
		}
	}

	// Fall back to grabbing the first {...} block in case of stray text.
	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start == -1 || end == -1 || end < start {
		return nil
	}
	jsonPart := trimmed[start : end+1]
	var result models.AIDiagnosisResult
	if err := json.Unmarshal([]byte(jsonPart), &result); err != nil {
		return nil
	}
	return &result
}

func (s *GroqService) History(ctx context.Context, sessionID string) ([]models.AIDiagnosisMessage, error) {
	return s.aiRepo.ListMessages(ctx, sessionID)
}

// TranscribeAudio sends an audio file to Groq's Whisper API and returns the
// transcribed text. Used by the "Record voice description" feature on the
// Issue Details screen — reuses the same GROQ_API_KEY already configured for
// chat diagnosis, just a different Groq endpoint (audio/transcriptions
// instead of chat/completions).
func (s *GroqService) TranscribeAudio(ctx context.Context, audioData []byte, filename string) (string, error) {
	const transcribeURL = "https://api.groq.com/openai/v1/audio/transcriptions"

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		return "", fmt.Errorf("groq transcribe: failed to create form file: %w", err)
	}
	if _, err := part.Write(audioData); err != nil {
		return "", fmt.Errorf("groq transcribe: failed to write audio data: %w", err)
	}
	if err := writer.WriteField("model", "whisper-large-v3"); err != nil {
		return "", err
	}
	if err := writer.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, transcribeURL, body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+s.apiKey)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("groq transcribe: request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var result struct {
		Text  string `json:"text"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error,omitempty"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("groq transcribe: failed to parse response: %w", err)
	}
	if result.Error != nil {
		return "", fmt.Errorf("groq transcribe: api error: %s", result.Error.Message)
	}

	return result.Text, nil
}