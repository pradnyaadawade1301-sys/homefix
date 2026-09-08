import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around the google_sign_in package for the login screen's
/// "Continue with Google" button. Kept separate from AuthProvider/AuthService
/// (which only talk to our own backend) since this is the one place the app
/// talks to Google directly.
class GoogleAuthHelper {
  // `serverClientId` MUST be the Google OAuth **Web** client ID (from the
  // same Firebase/GCP project — Firebase console → Authentication →
  // Sign-in method → Google → Web SDK configuration, or GCP Console →
  // APIs & Services → Credentials → "Web client (auto created by Google
  // Service)"). Without this, google_sign_in on Android frequently returns
  // a null idToken even after a successful sign-in — the account picker
  // works, but [signIn] below then throws, because there's nothing to send
  // to the backend. This must be the WEB client ID, not the Android one —
  // Android's own OAuth client (matched by package name + SHA-1) is used
  // implicitly by the plugin and isn't set here directly.
  //
  // TODO(Pradnya): replace with your actual Web client ID before shipping —
  // this placeholder will fail the same way an unset backend
  // GOOGLE_CLIENT_ID does.
  static const String _webClientId = '299649646704-rqarj9s3f0661jbodn77ef1o5q70780c.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: _webClientId,
  );

  /// Runs the native Google account picker and returns the ID token to send
  /// to POST /auth/google for server-side verification. Returns null if the
  /// user cancels the picker (not an error — callers should just no-op).
  /// Throws on any other failure (e.g. no Google Play Services, network).
  static Future<String?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled the picker
    final auth = await account.authentication;
    if (auth.idToken == null) {
      throw Exception('Google did not return an ID token — check the OAuth client configuration.');
    }
    return auth.idToken;
  }

  /// Signs out of the Google account too (not just our own app session) so
  /// the account picker shows up again next time instead of silently
  /// reusing the last account.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort — our own app logout should never fail because of this.
    }
  }
}