# Firebase Push Notification Fix - Progress Tracker

## Flutter App Changes
- [x] 1. Rename `google-services (1).json` → `google-services.json`
- [x] 2. Update `pubspec.yaml` - Add `firebase_core`, `firebase_messaging`, `flutter_local_notifications` dependencies
- [x] 3. Update `app/build.gradle.kts` - Apply `com.google.gms.google-services` plugin
- [x] 4. Update `AndroidManifest.xml` - Add `POST_NOTIFICATIONS` permission + RECEIVE_BOOT_COMPLETED
- [x] 5. Update `api_config.dart` - Fix Firebase sender ID (299649646704)
- [x] 6. Create `lib/services/notification_service.dart` - FCM token management, notification handling (FcmNotificationService)
- [x] 7. Create `lib/services/firebase_messaging_handler.dart` - Background message handler (top-level function)
- [x] 8. Update `main.dart` - Initialize Firebase, FcmNotificationService, set background handler
- [x] 9. Update `app.dart` - Wire FCM token registration callback, notification tap handling
- [x] 10. Fix google-services package name (com.homefixlive.homefix_live matches)

## Backend Changes
- [x] 11. Add Firebase credentials config to `.env.example`
- [x] 12. Update `consultation_service.go` - Add fcm field + constructor param, notify on:
       - Consultation request (preferred tech path)
       - Consultation request (category match path)
       - Consultation accepted (notify customer)
- [x] 13. Update `main.go` - Pass `fcmService` to `NewConsultationService`
- [x] 14. Update `testserver.go` - Pass `nil` for `fcmService` in tests
- [x] 15. Create `secrets/.gitkeep` - Directory for Firebase service account JSON

## Verification
- [x] 16. `flutter pub get` - SUCCESS
- [ ] 17. Go backend build - IN PROGRESS
- [ ] 18. Flutter Android build

