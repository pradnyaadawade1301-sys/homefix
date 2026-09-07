import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's active language and makes the whole app switch to it
/// instantly. Wired into MaterialApp's `locale:` in app.dart, so any screen
/// that calls [setLocale] causes every widget using AppLocalizations.of()
/// (and every built-in Material/Cupertino widget — dialogs, date pickers,
/// "OK"/"Cancel" text, etc.) to rebuild in the new language immediately.
///
/// The choice is persisted in SharedPreferences so it's remembered the next
/// time the app is opened, without requiring the user to be logged in (the
/// same pattern most consumer apps use for a language preference — it's a
/// device-level choice, not an account setting tied to login state).
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale_code';

  /// Supported languages — add a new Locale here (and a matching
  /// lib/l10n/app_<code>.arb file) to support another language later.
  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  /// Loads the previously-saved language (if any) at app startup. Called
  /// once from app.dart before the first frame; if nothing was saved yet,
  /// stays on the English default until the user picks one in Profile.
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && supportedLocales.any((l) => l.languageCode == saved)) {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}