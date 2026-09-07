// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appName => 'होमफिक्स';

  @override
  String get navHome => 'होम';

  @override
  String get navBooking => 'बुकिंग';

  @override
  String get navAI => 'एआय';

  @override
  String get navChat => 'चॅट';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get commonSave => 'जतन करा';

  @override
  String get commonCancel => 'रद्द करा';

  @override
  String get commonConfirm => 'पुष्टी करा';

  @override
  String get commonYes => 'होय';

  @override
  String get commonNo => 'नाही';

  @override
  String get commonDone => 'पूर्ण झाले';

  @override
  String get commonRetry => 'पुन्हा प्रयत्न करा';

  @override
  String get commonLoading => 'लोड होत आहे...';

  @override
  String homeGreeting(String name) {
    return 'नमस्कार, $name';
  }

  @override
  String get homeDetectingLocation => 'स्थान शोधले जात आहे...';

  @override
  String get homeSetLocation => 'तुमचे स्थान सेट करा';

  @override
  String get homeSearchHint => 'सेवा शोधा...';

  @override
  String get homeMostBooked => 'सर्वाधिक बुक केलेल्या सेवा';

  @override
  String get homeViewAll => 'सर्व पहा';

  @override
  String get homeMyTechnicians => 'माझे तंत्रज्ञ';

  @override
  String get homeTopPicks => 'तुमच्यासाठी खास निवड';

  @override
  String get profileTitle => 'प्रोफाइल';

  @override
  String get profileSectionAccount => 'खाते';

  @override
  String get profileSectionAppSettings => 'अ‍ॅप सेटिंग्ज';

  @override
  String get profileSectionSupport => 'सहाय्य';

  @override
  String get profilePersonalInfo => 'वैयक्तिक माहिती';

  @override
  String get profileSavedAddresses => 'जतन केलेले पत्ते';

  @override
  String get profileServiceHistory => 'सेवा इतिहास';

  @override
  String get profileBookings => 'बुकिंग्ज';

  @override
  String get profilePaymentMethods => 'पेमेंट पद्धती';

  @override
  String get profileTransactionHistory => 'व्यवहार इतिहास';

  @override
  String get profileNotifications => 'सूचना';

  @override
  String get profileReplayTour => 'गाईडेड टूर पुन्हा पहा';

  @override
  String get profileHelpCenter => 'मदत केंद्र';

  @override
  String get profileContactSupport => 'सपोर्टशी संपर्क साधा';

  @override
  String get profileTerms => 'अटी व शर्ती';

  @override
  String get profilePrivacyPolicy => 'गोपनीयता धोरण';

  @override
  String get profileLanguage => 'भाषा';

  @override
  String get profileLogout => 'लॉगआउट';

  @override
  String get profileDeleteAccount => 'खाते हटवा';

  @override
  String get profileTechnicianRole => 'तंत्रज्ञ';

  @override
  String get profileCustomerRole => 'ग्राहक';

  @override
  String get languageSheetTitle => 'तुमची भाषा निवडा';

  @override
  String get languageSheetSubtitle => 'संपूर्ण अ‍ॅप याच भाषेत दिसेल';

  @override
  String get languageEnglish => 'English (इंग्रजी)';

  @override
  String get languageHindi => 'हिंदी (Hindi)';

  @override
  String get languageMarathi => 'मराठी';

  @override
  String get languageChangedMessage => 'भाषा बदलली आहे';
}
