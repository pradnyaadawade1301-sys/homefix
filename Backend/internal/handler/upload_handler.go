package handler

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"homefix-backend/internal/utils"
)

// UploadHandler stores files on local disk under uploadDir and serves them back at
// publicBaseURL + "/uploads/<filename>" (wired as a static route in router.go).
//
// This is the storage backend used for technician KYC documents (government ID,
// profile photo) until AWS S3 credentials are configured. To move to S3-compatible
// storage: replace the os.Create/io.Copy below with an s3.PutObject call and point
// publicBaseURL at the bucket's public URL or CDN — callers (Flutter app, technician
// registration) are unaffected because they only ever see the returned "url" field.
type UploadHandler struct {
	uploadDir     string
	publicBaseURL string
}

func NewUploadHandler(uploadDir, publicBaseURL string) *UploadHandler {
	_ = os.MkdirAll(uploadDir, 0o755)
	return &UploadHandler{uploadDir: uploadDir, publicBaseURL: strings.TrimRight(publicBaseURL, "/")}
}

var allowedUploadExt = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".pdf": true,
	// Video — issue-report attachments (see Frontend IssueDetailsScreen,
	// which records up to a 2-minute clip). .mp4/.m4v are Android's usual
	// output, .mov is iOS's.
	".mp4": true, ".mov": true, ".m4v": true, ".webm": true, ".3gp": true,
}

// 10MB was fine for photos/PDFs alone, but a 2-minute camera video easily
// exceeds that — 150MB comfortably covers a 2-minute clip at typical mobile
// camera bitrates while still bounding worst-case abuse.
const maxUploadBytes = 150 << 20 // 150 MB

// Upload handles POST /api/v1/uploads (multipart/form-data, field name "file").
// Used for technician government ID and profile photo uploads. Returns {"url": "..."}.
func (h *UploadHandler) Upload(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxUploadBytes)

	fileHeader, err := c.FormFile("file")
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "file is required (multipart field \"file\")")
		return
	}
	if fileHeader.Size > maxUploadBytes {
		utils.Error(c, http.StatusBadRequest, "file too large (max 10MB)")
		return
	}

	ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
	if !allowedUploadExt[ext] {
		utils.Error(c, http.StatusBadRequest, "unsupported file type (allowed: jpg, jpeg, png, webp, pdf, mp4, mov, m4v, webm, 3gp)")
		return
	}

	filename := fmt.Sprintf("%s%s", uuid.NewString(), ext)
	destPath := filepath.Join(h.uploadDir, filename)

	if err := c.SaveUploadedFile(fileHeader, destPath); err != nil {
		utils.Error(c, http.StatusInternalServerError, "failed to save file")
		return
	}

	url := fmt.Sprintf("%s/uploads/%s", h.publicBaseURL, filename)
	utils.Success(c, http.StatusCreated, gin.H{"url": url})
}
