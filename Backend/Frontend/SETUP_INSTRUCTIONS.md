# Quick Setup Guide - HomeFix Live Flutter App

## ⚡ 5-Minute Quick Start

### Step 1: Extract & Enter Directory
```bash
unzip homefix_flutter_app.zip
cd homefix_flutter_app
```

### Step 2: Generate Platform Folders (CRITICAL!)
This is the most important step - it generates Android and iOS platform code:

```bash
flutter create --org com.homefixlive .
```

Say **`y`** when asked to overwrite files.

### Step 3: Get Dependencies
```bash
flutter pub get
```

### Step 4: Configure Backend URL
Edit `lib/config/api_config.dart` and update the base URL to match your backend:

**For local development (Android emulator):**
```dart
static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
```

**For local development (iOS simulator):**
```dart
static const String baseUrl = 'http://localhost:8080/api/v1';
```

**For production:**
```dart
static const String baseUrl = 'https://api.yourdomain.com/api/v1';
```

### Step 5: Run on Emulator/Device
```bash
# List available devices
flutter devices

# Run on default device
flutter run

# Or run on specific device
flutter run -d <device_id>
```

## 🎯 What's Included

✅ Complete Flutter project structure  
✅ All models (User, Booking, Category, Technician)  
✅ Authentication service with JWT + auto-refresh  
✅ Booking management service  
✅ State management with Provider  
✅ Material 3 theme  
✅ API integration with error handling  
✅ Screens: Splash, Login, Home, Bookings  
✅ Comprehensive documentation  

## 🔧 Next Steps

1. **Configure Firebase** (for notifications):
   - Create project at firebase.google.com
   - Add Android & iOS apps
   - Download credentials
   - Place in: `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
   - Update `lib/firebase_options.dart` with your keys

2. **Configure Razorpay** (for payments):
   - Get your Razorpay key from dashboard.razorpay.com
   - Update `lib/config/api_config.dart` with your key

3. **Configure Google Maps** (for location):
   - Get API key from Google Cloud Console
   - Update Android manifest and iOS AppDelegate

## 📖 Full Documentation

See `README.md` for complete setup guide, architecture details, troubleshooting, and deployment instructions.

## 🚨 Common Issues & Solutions

### "flutter create . not working"
Make sure you're in the `homefix_flutter_app` directory, not a subdirectory.

### "Module/package not found after flutter pub get"
```bash
flutter clean
flutter pub get
```

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter run
```

### "API calls failing"
1. Check backend is running on the URL in `api_config.dart`
2. Check firewall is not blocking the port
3. For Android emulator, use `10.0.2.2:8080` not `localhost:8080`

### "App crashes on startup"
1. Check Firebase configuration is correct
2. Check API base URL is correct and backend is running
3. Check logs: `flutter logs`

## 📞 Need Help?

1. Read the full `README.md`
2. Check Flutter documentation: flutter.dev/docs
3. Check backend logs
4. Run with verbose logging: `flutter run -v`

---

**You're ready to go!** 🚀  
Run `flutter run` and start developing!
