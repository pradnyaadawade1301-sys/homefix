package service

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// FirebaseService sends real push notifications via the Firebase Admin SDK (FCM HTTP v1 API).
type FirebaseService struct {
	client    *messaging.Client
	notifRepo *repository.NotificationRepository
	userRepo  *repository.UserRepository
}

// NewFirebaseService initializes the Firebase Admin SDK using a real service account JSON.
// Fails to init (returns error) if the credentials file/project id is missing — no silent no-op mode.
func NewFirebaseService(ctx context.Context, credentialsPath, projectID string, notifRepo *repository.NotificationRepository, userRepo *repository.UserRepository) (*FirebaseService, error) {
	opt := option.WithCredentialsFile(credentialsPath)
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, opt)
	if err != nil {
		return nil, fmt.Errorf("firebase: failed to init app: %w", err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase: failed to init messaging client: %w", err)
	}
	return &FirebaseService{client: client, notifRepo: notifRepo, userRepo: userRepo}, nil
}

// SendToUser looks up the user's stored FCM token, sends a real push via FCM, and logs
// the notification row regardless of push outcome (sent_via_fcm reflects actual result).
func (f *FirebaseService) SendToUser(ctx context.Context, userID, title, body string, data map[string]string) error {
	u, err := f.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	sentOK := false
	if u != nil && u.FCMToken != nil && *u.FCMToken != "" {
		msg := &messaging.Message{
			Token: *u.FCMToken,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
			Data: data,
		}
		if _, err := f.client.Send(ctx, msg); err != nil {
			// Push failed (e.g. stale token) - still record in-app notification below.
			sentOK = false
		} else {
			sentOK = true
		}
	}

	dataMap := map[string]interface{}{}
	for k, v := range data {
		dataMap[k] = v
	}
	n := &models.Notification{UserID: userID, Title: title, Body: body, Data: dataMap}
	_, err = f.notifRepo.Create(ctx, n, sentOK)
	return err
}
