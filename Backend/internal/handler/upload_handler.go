package handler

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"homefix-backend/internal/utils"
)

// UploadHandler stores files in Cloudinary (persistent, CDN-backed) when
// credentials are configured, falling back to local disk under uploadDir
// otherwise — used for local dev without a Cloudinary account. Render's
// filesystem is ephemeral and resets on every restart/redeploy, so local
// disk isn't safe to rely on in production.
//
// Used for technician KYC documents (government ID, profile photo) and
// dispute evidence photos/videos.
type UploadHandler struct {
	uploadDir     string
	publicBaseURL string
	cld           *cloudinary.Cloudinary
}

func NewUploadHandler(uploadDir, publicBaseURL string) *UploadHandler {
	_ = os.MkdirAll(uploadDir, 0o755)
	return &UploadHandler{uploadDir: uploadDir, publicBaseURL: strings.TrimRight(publicBaseURL, "/")}
}

// NewUploadHandlerWithCloudinary wires Cloudinary as the storage backend.
// cld is nil (falls back to local disk) if cloudName/apiKey/apiSecret is empty.
func NewUploadHandlerWithCloudinary(uploadDir, publicBaseURL, cloudName, apiKey, apiSecret string) *UploadHandler {
	_ = os.MkdirAll(uploadDir, 0o755)
	h := &UploadHandler{uploadDir: uploadDir, publicBaseURL: strings.TrimRight(publicBaseURL, "/")}

	if cloudName != "" && apiKey != "" && apiSecret != "" {
		cld, err := cloudinary.NewFromParams(cloudName, apiKey, apiSecret)
		if err == nil {
			h.cld = cld
		}
	}
	return h
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

	if h.cld != nil {
		file, err := fileHeader.Open()
		if err != nil {
			utils.Error(c, http.StatusInternalServerError, "failed to read file")
			return
		}
		defer file.Close()

		result, err := h.cld.Upload.Upload(context.Background(), file, uploader.UploadParams{
			PublicID: strings.TrimSuffix(filename, ext),
			Folder:   "homefix-uploads",
		})
		if err != nil || result.Error.Message != "" {
			utils.Error(c, http.StatusInternalServerError, "failed to upload file")
			return
		}

		utils.Success(c, http.StatusCreated, gin.H{"url": result.SecureURL})
		return
	}

	destPath := filepath.Join(h.uploadDir, filename)
	if err := c.SaveUploadedFile(fileHeader, destPath); err != nil {
		utils.Error(c, http.StatusInternalServerError, "failed to save file")
		return
	}

	url := fmt.Sprintf("%s/uploads/%s", h.publicBaseURL, filename)
	utils.Success(c, http.StatusCreated, gin.H{"url": url})
}
