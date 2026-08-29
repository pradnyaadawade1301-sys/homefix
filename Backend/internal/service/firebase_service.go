package service

import (
	"context"
	"fmt"
	"log"

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
// Returns an error only for genuinely fatal misconfiguration; callers that want push
// notifications to be best-effort should use NewFirebaseServiceOrDegraded instead.
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

// NewFirebaseServiceOrDegraded always returns a usable *FirebaseService so that in-app
// notifications keep working even when push (Firebase) isn't configured or fails to
// initialize. In that case client stays nil and SendToUser simply skips the push step
// while still writing the in-app notification row.
func NewFirebaseServiceOrDegraded(ctx context.Context, credentialsPath, projectID string, notifRepo *repository.NotificationRepository, userRepo *repository.UserRepository) *FirebaseService {
	if credentialsPath == "" || projectID == "" {
		log.Printf("[fcm] FIREBASE_CREDENTIALS_PATH/FIREBASE_PROJECT_ID not set — push notifications disabled, in-app notifications still work")
		return &FirebaseService{client: nil, notifRepo: notifRepo, userRepo: userRepo}
	}
	svc, err := NewFirebaseService(ctx, credentialsPath, projectID, notifRepo, userRepo)
	if err != nil {
		log.Printf("[fcm] failed to init Firebase (push notifications disabled, in-app notifications still work): %v", err)
		return &FirebaseService{client: nil, notifRepo: notifRepo, userRepo: userRepo}
	}
	log.Printf("[fcm] Firebase push notifications initialized for project %s", projectID)
	return svc
}

// SendToUser looks up the user's stored FCM token, sends a real push via FCM (if a
// client is configured), and logs the notification row regardless of push outcome
// (sent_via_fcm reflects actual result). Safe to call even when f.client is nil —
// in that case only the in-app notification row is written.
//
// All failure paths (user lookup, push send, in-app row insert) are logged here so
// they're visible in server logs even though most callers discard the returned
// error with `_ = s.fcm.SendToUser(...)` for fire-and-forget notification sends.
func (f *FirebaseService) SendToUser(ctx context.Context, userID, title, body string, data map[string]string) error {
	u, err := f.userRepo.GetByID(ctx, userID)
	if err != nil {
		log.Printf("[fcm] SendToUser: failed to look up user %s: %v", userID, err)
		return err
	}
	if u == nil {
		log.Printf("[fcm] SendToUser: user %s not found, skipping notification %q", userID, title)
	}

	sentOK := false
	switch {
	case f.client == nil:
		log.Printf("[fcm] SendToUser: push client not configured (FIREBASE_CREDENTIALS_PATH/FIREBASE_PROJECT_ID not set) — writing in-app notification only for user %s: %q", userID, title)
	case u == nil || u.FCMToken == nil || *u.FCMToken == "":
		log.Printf("[fcm] SendToUser: user %s has no FCM token registered — writing in-app notification only: %q", userID, title)
	default:
		// Android delivery config: "high" priority so FCM/the device doesn't
		// defer delivery in Doze/battery-saver mode, and a channel id matching
		// one of the channels the app registers in notification_service.dart —
		// this is what makes the OS show a heads-up banner + play sound even
		// while the app is backgrounded/killed, with zero Dart code needing to
		// run. Incoming consultation requests get the higher-importance
		// 'incoming_calls' channel so they can't get lost among ordinary
		// booking/payment notifications on the shared channel.
		channelID := "homefix_notifications"
		if data["type"] == "consultation_request" {
			channelID = "incoming_calls"
		}
		msg := &messaging.Message{
			Token: *u.FCMToken,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
			Data: data,
			Android: &messaging.AndroidConfig{
				Priority: "high",
				Notification: &messaging.AndroidNotification{
					ChannelID: channelID,
				},
			},
		}
		if _, err := f.client.Send(ctx, msg); err != nil {
			// Push failed (e.g. stale/invalid token, revoked credentials) - still
			// record in-app notification below, but log so this isn't invisible.
			log.Printf("[fcm] SendToUser: push send failed for user %s: %v", userID, err)
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
	if _, err := f.notifRepo.Create(ctx, n, sentOK); err != nil {
		log.Printf("[fcm] SendToUser: failed to write in-app notification row for user %s: %v", userID, err)
		return err
	}
	return nil
}