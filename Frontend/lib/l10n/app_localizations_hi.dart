// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'होमफिक्स';

  @override
  String get navHome => 'होम';

  @override
  String get navBooking => 'बुकिंग';

  @override
  String get navAI => 'एआई';

  @override
  String get navChat => 'चैट';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get commonSave => 'सेव करें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonYes => 'हाँ';

  @override
  String get commonNo => 'नहीं';

  @override
  String get commonDone => 'हो गया';

  @override
  String get commonRetry => 'पुनः प्रयास करें';

  @override
  String get commonLoading => 'लोड हो रहा है...';

  @override
  String homeGreeting(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get homeDetectingLocation => 'स्थान का पता लगाया जा रहा है...';

  @override
  String get homeSetLocation => 'अपना स्थान सेट करें';

  @override
  String get homeSearchHint => 'सेवा खोजें...';

  @override
  String get homeMostBooked => 'सबसे ज़्यादा बुक की गई सेवाएँ';

  @override
  String get homeViewAll => 'सभी देखें';

  @override
  String get homeMyTechnicians => 'मेरे टेक्नीशियन';

  @override
  String get homeTopPicks => 'आपके लिए खास चुनाव';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get profileSectionAccount => 'खाता';

  @override
  String get profileSectionAppSettings => 'ऐप सेटिंग्स';

  @override
  String get profileSectionSupport => 'सहायता';

  @override
  String get profilePersonalInfo => 'व्यक्तिगत जानकारी';

  @override
  String get profileSavedAddresses => 'सहेजे गए पते';

  @override
  String get profileServiceHistory => 'सेवा इतिहास';

  @override
  String get profileBookings => 'बुकिंग्स';

  @override
  String get profilePaymentMethods => 'भुगतान के तरीके';

  @override
  String get profileTransactionHistory => 'लेन-देन का इतिहास';

  @override
  String get profileNotifications => 'सूचनाएं';

  @override
  String get profileReplayTour => 'गाइडेड टूर फिर से देखें';

  @override
  String get profileHelpCenter => 'सहायता केंद्र';

  @override
  String get profileContactSupport => 'सपोर्ट से संपर्क करें';

  @override
  String get profileTerms => 'नियम एवं शर्तें';

  @override
  String get profilePrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get profileLanguage => 'भाषा';

  @override
  String get profileLogout => 'लॉगआउट';

  @override
  String get profileDeleteAccount => 'खाता हटाएं';

  @override
  String get profileTechnicianRole => 'टेक्नीशियन';

  @override
  String get profileCustomerRole => 'ग्राहक';

  @override
  String get languageSheetTitle => 'अपनी भाषा चुनें';

  @override
  String get languageSheetSubtitle => 'पूरी ऐप इसी भाषा में दिखेगी';

  @override
  String get languageEnglish => 'English (अंग्रेज़ी)';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get languageMarathi => 'मराठी (Marathi)';

  @override
  String get languageChangedMessage => 'भाषा बदल दी गई है';
}
