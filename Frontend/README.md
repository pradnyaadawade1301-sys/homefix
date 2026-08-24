# HomeFix Live - Flutter Frontend

A complete Flutter frontend application for HomeFix Live - an on-demand home services platform with live consultation, AI diagnosis, verified technicians, and instant fixes.

## 📋 Table of Contents

- [Project Structure](#project-structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the App](#running-the-app)
- [Architecture](#architecture)
- [API Integration](#api-integration)
- [State Management](#state-management)
- [Build & Deployment](#build--deployment)
- [Troubleshooting](#troubleshooting)

## 📁 Project Structure

```
lib/
├── config/
│   └── api_config.dart           # API endpoints and configuration
├── core/
│   ├── http_client.dart          # HTTP client with JWT interceptor
│   └── theme.dart                # Material 3 theme configuration
├── models/
│   ├── user_model.dart           # User, Address, AuthResponse models
│   ├── booking_model.dart        # Booking, Technician, Category models
│   └── notification_model.dart   # Notification and Chat models
├── services/
│   ├── auth_service.dart         # Authentication service
│   ├── booking_service.dart      # Booking operations service
│   └── service_locator.dart      # Other services (Category, Technician, etc)
├── providers/
│   ├── auth_provider.dart        # Auth state management
│   ├── booking_provider.dart     # Booking state management
│   └── category_provider.dart    # Category, Technician, User providers
├── screens/
│   ├── auth/
│   │   ├── splash_screen.dart
│   │   └── login_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── booking/
│   ├── call/
│   ├── chat/
│   ├── profile/
│   └── settings/
├── widgets/              # Reusable widget components
├── utils/                # Utility functions and helpers
├── app.dart              # Multi-provider configuration
├── main.dart             # App entry point
└── firebase_options.dart # Firebase configuration
```

## ✨ Features

### Core Features Implemented

1. **Authentication**
   - Email/Password login
   - User registration with OTP verification
   - Forgot password & password reset
   - JWT token management with auto-refresh
   - Secure token storage

2. **Service Browsing**
   - Browse home services by category
   - Search and filter services
   - View technician profiles and ratings

3. **Booking Management**
   - Create new service bookings
   - Schedule appointments
   - View booking history
   - Track booking status
   - Cancel bookings

4. **Real-time Communication**
   - Live video consultation (WebRTC)
   - In-app messaging
   - Push notifications (Firebase)
   - Notification center

5. **AI-Powered Features**
   - AI diagnosis of home issues
   - Smart troubleshooting suggestions
   - Cost estimation

6. **User Management**
   - User profile management
   - Address management
   - Payment information
   - Preferences & settings

## 📦 Prerequisites

Before starting, ensure you have:

1. **Flutter SDK** (version 3.0+)
   ```bash
   flutter --version
   ```

2. **Dart** (included with Flutter)
   ```bash
   dart --version
   ```

3. **Android Setup** (for Android development)
   - Android Studio with SDK 21+
   - Android emulator or physical device

4. **iOS Setup** (for iOS development)
   - Xcode 12+
   - CocoaPods
   - iOS deployment target: 11.0+

5. **Your HomeFix Live Backend** running on:
   - Default: `http://localhost:8080` (development)
   - Update in `lib/config/api_config.dart` for different environments

## 🚀 Installation

### Step 1: Extract the project

```bash
unzip homefix_flutter_app.zip
cd homefix_flutter_app
```

### Step 2: Create Flutter platform folders

This step is crucial - it generates the platform-specific code for Android and iOS:

```bash
flutter create --org com.homefixlive .
```

When prompted to overwrite, select "y" (yes) for conflicting files.

### Step 3: Get dependencies

```bash
flutter pub get
```

### Step 4: Run code generation (if using json_serializable)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## ⚙️ Configuration

### 1. API Configuration

Edit `lib/config/api_config.dart`:

```dart
// For local development
static const String baseUrl = 'http://10.0.2.2:8080/api/v1'; // Android
// static const String baseUrl = 'http://localhost:8080/api/v1'; // iOS

// For production
// static const String baseUrl = 'https://api.homefixlive.com/api/v1';
```

### 2. Firebase Setup

1. Create a Firebase project at [firebase.google.com](https://firebase.google.com)
2. Add Android and iOS apps to your project
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place them in the correct directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

5. Update `lib/firebase_options.dart`:
   ```dart
   static FirebaseOptions get currentPlatform {
     return FirebaseOptions(
       apiKey: 'YOUR_API_KEY',
       appId: 'YOUR_APP_ID',
       messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
       projectId: 'YOUR_PROJECT_ID',
       storageBucket: 'YOUR_STORAGE_BUCKET',
     );
   }
   ```

### 3. Razorpay Configuration (Optional)

For payment processing, update in `lib/config/api_config.dart`:

```dart
static const String razorpayKey = 'rzp_test_XXXXXXXXXX';
```

Replace with your actual Razorpay test/production key from [Razorpay Dashboard](https://dashboard.razorpay.com)

### 4. Google Maps Configuration (Optional)

#### For Android:

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

#### For iOS:

Edit `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

## ▶️ Running the App

### Run on Android Emulator

```bash
flutter emulators
flutter emulators launch Pixel_4_API_30  # or your emulator name
flutter run
```

### Run on iOS Simulator

```bash
open -a Simulator
flutter run
```

### Run on Physical Device

**Android:**
```bash
flutter devices  # List connected devices
flutter run -d <device_id>
```

**iOS:**
```bash
flutter devices
flutter run -d <device_id>
```

### Run with Specific Configuration

```bash
flutter run --flavor development  # if using flavors
flutter run --debug               # Debug mode
flutter run --release             # Release mode
```

## 🏗️ Architecture

### Clean Architecture Pattern

The app follows clean architecture with clear separation of concerns:

```
Screens (UI Layer)
    ↓
Providers (State Management)
    ↓
Services (Business Logic)
    ↓
HTTP Client (Data Layer)
    ↓
API (Backend)
```

### Layers

1. **Presentation Layer** (`screens/`)
   - UI widgets and screens
   - User interactions
   - State UI updates via Providers

2. **State Management** (`providers/`)
   - ChangeNotifier-based providers
   - Business logic separation
   - Data flow management

3. **Service Layer** (`services/`)
   - API calls
   - Business logic implementation
   - Data transformation

4. **Data Layer** (`core/http_client.dart`)
   - HTTP communication
   - Request/response handling
   - JWT token management

## 🔌 API Integration

### Authentication Flow

```
1. Login → AuthService.login() → Backend /auth/login
2. Response: {user, access_token, refresh_token}
3. Store tokens → HttpClient.setTokens()
4. Auto-refresh when expired (401 response)
```

### Making API Calls

```dart
// In Service
final response = await _httpClient.post(
  ApiConfig.bookingCreate,
  data: {
    'category_id': categoryId,
    'description': description,
    // ... other data
  },
);

// Model parsing
final booking = Booking.fromJson(response.data);
```

### Error Handling

```dart
try {
  await bookingService.createBooking(...);
} catch (e) {
  // Handle error
  print('Error: $e');
}
```

## 📊 State Management (Provider Pattern)

### Creating a Provider

```dart
class MyProvider extends ChangeNotifier {
  String _data = '';
  
  String get data => _data;
  
  Future<void> fetchData() async {
    // fetch and update
    _data = newData;
    notifyListeners();
  }
}
```

### Using in Widget

```dart
Consumer<MyProvider>(
  builder: (context, provider, child) {
    return Text(provider.data);
  },
)

// Or with Provider.of
final data = Provider.of<MyProvider>(context).data;

// Or read (doesn't listen to changes)
context.read<MyProvider>().fetchData();
```

## 🏗️ Build & Deployment

### Build APK (Android)

```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

### Build App Bundle (Google Play)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build IPA (iOS)

```bash
flutter build ipa --release
# Output: build/ios/ipa/
```

### Build Web

```bash
flutter build web --release
# Output: build/web/
```

## 🔍 Troubleshooting

### Issue: "Flutter SDK not found"

```bash
# Ensure Flutter is in PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### Issue: "Could not resolve dependencies"

```bash
flutter clean
flutter pub get
```

### Issue: "Pod install failed" (iOS)

```bash
cd ios
rm -rf Pods Podfile.lock
cd ..
flutter pub get
flutter run
```

### Issue: "Could not find com.android.tools.build:gradle"

```bash
flutter clean
rm -rf build/
flutter pub get
```

### Issue: "Gradle build failed"

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter run
```

### Issue: API calls failing with 401

The app auto-refreshes expired tokens. If still failing:
- Check token expiry in `ApiConfig`
- Verify backend refresh endpoint is working
- Clear app data and re-login

### Issue: Firebase not initializing

Ensure:
- `google-services.json` is in `android/app/`
- `GoogleService-Info.plist` is in `ios/Runner/`
- Firebase project is properly configured

## 📚 Key Dependencies

- **Dio** - HTTP client
- **Provider** - State management
- **Flutter WebRTC** - Video calling
- **Firebase Core/Messaging** - Notifications
- **Google Maps** - Location services
- **Razorpay** - Payments
- **Flutter Secure Storage** - Secure token storage
- **Socket.IO** - Real-time communication

## 🔐 Security Best Practices

1. **Never hardcode secrets** - Use environment variables or secure storage
2. **Validate inputs** - Always validate user inputs
3. **Use HTTPS** - Only use HTTPS in production
4. **Secure token storage** - Tokens stored in SecureStorage
5. **SSL pinning** - Consider implementing for production

## 📞 Support & Updates

For issues or questions:
1. Check the Troubleshooting section
2. Review backend API logs
3. Check Flutter/Dart documentation
4. Monitor console output for detailed errors

## 📝 License

This project is proprietary and intended for HomeFix Live only.

---

**Version:** 1.0.0  
**Last Updated:** July 2026  
**Flutter Version:** 3.0+  
**Dart Version:** 3.0+
