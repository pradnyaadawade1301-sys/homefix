// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'HomeFix';

  @override
  String get navHome => 'Home';

  @override
  String get navBooking => 'Booking';

  @override
  String get navAI => 'AI';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonDone => 'Done';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeDetectingLocation => 'Detecting location...';

  @override
  String get homeSetLocation => 'Set your location';

  @override
  String get homeSearchHint => 'Search service...';

  @override
  String get homeMostBooked => 'Most Booked Services';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeMyTechnicians => 'My Technicians';

  @override
  String get homeTopPicks => 'Top Picks for you';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get profileSectionAppSettings => 'App Settings';

  @override
  String get profileSectionSupport => 'Support';

  @override
  String get profilePersonalInfo => 'Personal Information';

  @override
  String get profileSavedAddresses => 'Saved Addresses';

  @override
  String get profileServiceHistory => 'Service History';

  @override
  String get profileBookings => 'Bookings';

  @override
  String get profilePaymentMethods => 'Payment Methods';

  @override
  String get profileTransactionHistory => 'Transaction History';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileReplayTour => 'Replay Guided Tour';

  @override
  String get profileHelpCenter => 'Help Center';

  @override
  String get profileContactSupport => 'Contact Support';

  @override
  String get profileTerms => 'Terms & Conditions';

  @override
  String get profilePrivacyPolicy => 'Privacy Policy';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLogout => 'Logout';

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileTechnicianRole => 'Technician';

  @override
  String get profileCustomerRole => 'Customer';

  @override
  String get languageSheetTitle => 'Choose your language';

  @override
  String get languageSheetSubtitle =>
      'The app will switch to this language everywhere';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी (Hindi)';

  @override
  String get languageMarathi => 'मराठी (Marathi)';

  @override
  String get languageChangedMessage => 'Language updated';
}
