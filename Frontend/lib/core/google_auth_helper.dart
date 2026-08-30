import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around the google_sign_in package for the login screen's
/// "Continue with Google" button. Kept separate from AuthProvider/AuthService
/// (which only talk to our own backend) since this is the one place the app
/// talks to Google directly.
class GoogleAuthHelper {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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