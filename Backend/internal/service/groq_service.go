package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// keyRing round-robins through a list of Groq API keys. Every outgoing
// request starts with whatever key is "current"; if that key comes back
// rate-limited, over quota, or unauthorized, the caller advances the ring
// and retries with the next key. Once the last key has been tried, the ring
// wraps back around to the first key automatically (index % len).
//
// The ring is intentionally "sticky": a successful call does not reset the
// index, so once key #3 starts working the service keeps using key #3 for
// subsequent requests instead of restarting from key #1 every time — it
// only advances forward (and wraps) when a key actually fails.
type keyRing struct {
	mu   sync.Mutex
	keys []string
	idx  int
}

func newKeyRing(keys []string) *keyRing {
	if len(keys) == 0 {
		keys = []string{""}
	}
	return &keyRing{keys: keys}
}

// current returns the key currently in use.
func (r *keyRing) current() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.keys[r.idx]
}

// advance moves to the next key, wrapping back to the first key once the
// last one has been reached (e.g. index 5 -> 0 for 6 keys).
func (r *keyRing) advance() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.idx = (r.idx + 1) % len(r.keys)
}

func (r *keyRing) count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.keys)
}

// isKeyExhaustedError reports whether an error/response indicates the
// current Groq key is rate-limited, out of quota, or invalid — i.e. it's
// time to rotate to the next key rather than surface the error to the user.
func isKeyExhaustedError(statusCode int, message string) bool {
	if statusCode == http.StatusTooManyRequests || statusCode == http.StatusUnauthorized || statusCode == http.StatusForbidden {
		return true
	}
	lower := strings.ToLower(message)
	return strings.Contains(lower, "rate limit") ||
		strings.Contains(lower, "quota") ||
		strings.Contains(lower, "invalid_api_key") ||
		strings.Contains(lower, "invalid api key")
}

type GroqService struct {
	keys   *keyRing
	model  string
	apiURL string
	client *http.Client
	aiRepo *repository.AIRepository
}

// NewGroqService accepts either a single key or a comma-separated list
// (already split into apiKeys by config.Load). Requests automatically
// rotate through all provided keys as each one is exhausted, cycling back
// to the first once the last one fails too.
func NewGroqService(apiKeys []string, model, apiURL string, aiRepo *repository.AIRepository) *GroqService {
	return &GroqService{
		keys:   newKeyRing(apiKeys),
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
- BE CONCISE: possible_fault must be one short phrase (under 10 words). Limit causes to at most 2
  items, each a short phrase (under 8 words), not full sentences. Limit follow_up_questions to at
  most 3 short, direct questions (under 12 words each). Do not repeat information across fields.
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

	var reply string
	attempts := s.keys.count()
	var lastErr error
	for i := 0; i < attempts; i++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.apiURL, bytes.NewReader(payload))
		if err != nil {
			return "", nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+s.keys.current())

		resp, err := s.client.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("groq: request failed: %w", err)
			s.keys.advance()
			continue
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			s.keys.advance()
			continue
		}

		var gr groqResponse
		if err := json.Unmarshal(body, &gr); err != nil {
			lastErr = fmt.Errorf("groq: failed to parse response: %w", err)
			s.keys.advance()
			continue
		}
		if gr.Error != nil {
			if isKeyExhaustedError(resp.StatusCode, gr.Error.Message) {
				// This key is rate-limited/out of quota/invalid — rotate to
				// the next one (wrapping back to the first after the last)
				// and retry the same request transparently.
				lastErr = fmt.Errorf("groq: api error: %s", gr.Error.Message)
				s.keys.advance()
				continue
			}
			return "", nil, fmt.Errorf("groq: api error: %s", gr.Error.Message)
		}
		if len(gr.Choices) == 0 {
			lastErr = fmt.Errorf("groq: empty response from model")
			s.keys.advance()
			continue
		}

		reply = gr.Choices[0].Message.Content
		lastErr = nil
		break
	}
	if lastErr != nil {
		return "", nil, fmt.Errorf("groq: all configured API keys exhausted: %w", lastErr)
	}

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
//
// Whisper is well known to "hallucinate" plausible-sounding but unrelated
// text (stock phrases like "Thank you.", random other-language snippets,
// etc.) when it's given very short or near-silent audio instead of real
// speech. To avoid feeding that straight into the issue description, this
// asks Groq for verbose_json (which includes a no_speech_prob per segment)
// and a temperature of 0, and returns ErrNoSpeechDetected when the audio
// doesn't look like it actually contained speech instead of returning
// whatever text Whisper made up.
var ErrNoSpeechDetected = errors.New("no clear speech detected in the recording")

func (s *GroqService) TranscribeAudio(ctx context.Context, audioData []byte, filename string) (string, error) {
	const transcribeURL = "https://api.groq.com/openai/v1/audio/transcriptions"

	attempts := s.keys.count()
	var lastErr error
	for i := 0; i < attempts; i++ {
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
		// verbose_json gives us per-segment no_speech_prob so we can detect
		// hallucinated output instead of trusting any text Whisper returns.
		if err := writer.WriteField("response_format", "verbose_json"); err != nil {
			return "", err
		}
		// temperature 0 = least "creative"/most deterministic decoding,
		// which noticeably cuts down on invented text for weak audio.
		if err := writer.WriteField("temperature", "0"); err != nil {
			return "", err
		}
		// Nudges Whisper's vocabulary toward what these recordings are
		// actually about, and away from generic hallucinated filler —
		// users describe home-repair problems (AC, plumbing, electrical,
		// appliances, carpentry) often in Hindi/Hinglish.
		if err := writer.WriteField("prompt",
			"Customer describing a home repair problem such as AC, plumbing, electrical, appliance, or carpentry issue. May be spoken in Hindi, English, or Hinglish."); err != nil {
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
		req.Header.Set("Authorization", "Bearer "+s.keys.current())

		resp, err := s.client.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("groq transcribe: request failed: %w", err)
			s.keys.advance()
			continue
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			s.keys.advance()
			continue
		}

		var result struct {
			Text     string  `json:"text"`
			Duration float64 `json:"duration"`
			Segments []struct {
				Text         string  `json:"text"`
				NoSpeechProb float64 `json:"no_speech_prob"`
			} `json:"segments"`
			Error *struct {
				Message string `json:"message"`
			} `json:"error,omitempty"`
		}
		if err := json.Unmarshal(respBody, &result); err != nil {
			lastErr = fmt.Errorf("groq transcribe: failed to parse response: %w", err)
			s.keys.advance()
			continue
		}
		if result.Error != nil {
			if isKeyExhaustedError(resp.StatusCode, result.Error.Message) {
				// Rotate to the next key (wrapping to the first after the
				// last) and retry the same audio transparently.
				lastErr = fmt.Errorf("groq transcribe: api error: %s", result.Error.Message)
				s.keys.advance()
				continue
			}
			return "", fmt.Errorf("groq transcribe: api error: %s", result.Error.Message)
		}

		text := strings.TrimSpace(result.Text)

		// Very short clips (accidental taps, cut-off recordings) are the
		// single biggest source of hallucinated Whisper output — Groq
		// itself can't reliably flag these via no_speech_prob because a
		// half-second of real speech still looks "speech-like" segment by
		// segment. Reject on duration first, before even looking at text.
		if result.Duration > 0 && result.Duration < 0.8 {
			return "", ErrNoSpeechDetected
		}

		// If every segment is mostly "not speech" (or there's no text /
		// no segments at all), treat it as silence rather than trust
		// whatever filler text came back.
		if text == "" {
			return "", ErrNoSpeechDetected
		}
		if len(result.Segments) > 0 {
			allLikelySilence := true
			for _, seg := range result.Segments {
				if seg.NoSpeechProb < 0.6 {
					allLikelySilence = false
					break
				}
			}
			if allLikelySilence {
				return "", ErrNoSpeechDetected
			}
		}

		return text, nil
	}
	return "", fmt.Errorf("groq transcribe: all configured API keys exhausted: %w", lastErr)
}
