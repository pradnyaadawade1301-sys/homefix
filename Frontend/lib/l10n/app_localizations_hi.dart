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

  @override
  String get loginWelcomeBack => 'वापसी पर स्वागत है';

  @override
  String get loginSubtitle =>
      'विश्वसनीय होम सर्विसेज़ बुक करने के लिए साइन इन करें';

  @override
  String get loginIdentifierHint => 'ईमेल या फ़ोन नंबर';

  @override
  String get loginIdentifierRequired => 'ईमेल या फ़ोन नंबर आवश्यक है';

  @override
  String get loginPasswordHint => 'पासवर्ड';

  @override
  String get loginPasswordRequired => 'पासवर्ड आवश्यक है';

  @override
  String get loginForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get loginForgotPasswordComingSoon =>
      'पासवर्ड रीसेट सुविधा जल्द आ रही है';

  @override
  String get loginSignIn => 'साइन इन करें';

  @override
  String get loginOr => 'या';

  @override
  String get loginContinueWithGoogle => 'Google से जारी रखें';

  @override
  String loginGoogleSignInFailed(String error) {
    return 'Google साइन-इन विफल: $error';
  }

  @override
  String get loginTrustedBanner => 'हज़ारों उपयोगकर्ताओं का भरोसा';

  @override
  String get loginTrustedSubtitle =>
      'सत्यापित तकनीशियन • सुरक्षित बुकिंग • 24/7 सहायता';

  @override
  String get loginNoAccount => 'खाता नहीं है? ';

  @override
  String get loginSignUp => 'साइन अप करें';

  @override
  String get signupPasswordRequiredValidator => 'पासवर्ड आवश्यक है';

  @override
  String get signupPasswordTooShort =>
      'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए';

  @override
  String get signupPasswordNeedsLetterSpecial =>
      'एक अक्षर और एक विशेष चिह्न जोड़ें (सिर्फ़ नंबर नहीं)';

  @override
  String get signupCreateYourAccount => 'अपना खाता बनाएं';

  @override
  String get signupJoinSubtitle =>
      'ग्राहक या तकनीशियन के रूप में HomeFix Live से जुड़ें';

  @override
  String get signupIAmA => 'मैं हूं एक';

  @override
  String get signupRoleCustomer => 'ग्राहक';

  @override
  String get signupRoleTechnician => 'तकनीशियन';

  @override
  String get signupNameHint => 'पूरा नाम';

  @override
  String get signupNameRequired => 'नाम आवश्यक है';

  @override
  String get signupEmailHint => 'ईमेल पता';

  @override
  String get signupEmailRequired => 'ईमेल आवश्यक है';

  @override
  String get signupEmailInvalid => 'मान्य ईमेल दर्ज करें';

  @override
  String get signupPhoneHint => 'फ़ोन नंबर';

  @override
  String get signupPhoneRequired => 'फ़ोन नंबर आवश्यक है';

  @override
  String get signupPhoneInvalid => 'मान्य फ़ोन नंबर दर्ज करें';

  @override
  String get signupPasswordHint => 'पासवर्ड';

  @override
  String get signupPasswordHelper =>
      'कम से कम 8 अक्षर, एक अक्षर और एक विशेष चिह्न सहित';

  @override
  String get signupDataSafeBanner => 'आपका डेटा हमारे पास सुरक्षित है';

  @override
  String get signupDataSafeSubtitle => 'हम आपकी जानकारी कभी साझा नहीं करते';

  @override
  String get signupCreateAccount => 'खाता बनाएं';

  @override
  String get signupHaveAccount => 'पहले से खाता है? ';

  @override
  String get signupSignIn => 'साइन इन करें';

  @override
  String get bookingsTitle => 'मेरी बुकिंग';

  @override
  String get bookingsCancelDialogTitle => 'यह बुकिंग रद्द करें?';

  @override
  String get bookingsCancelDialogBody =>
      'इससे आपकी बुकिंग रद्द हो जाएगी और तकनीशियन को सूचित किया जाएगा, अगर कोई नियुक्त किया गया हो।';

  @override
  String get bookingsCancelReasonLabel => 'कारण (वैकल्पिक)';

  @override
  String get bookingsKeepBooking => 'बुकिंग रखें';

  @override
  String get bookingsYesCancel => 'हां, रद्द करें';

  @override
  String get bookingsCancelledMsg => 'बुकिंग रद्द कर दी गई';

  @override
  String get bookingsCouldNotCancel => 'बुकिंग रद्द नहीं की जा सकी';

  @override
  String get bookingsStatusFinding => 'तकनीशियन खोजा जा रहा है';

  @override
  String get bookingsStatusWaiting => 'तकनीशियन का इंतज़ार';

  @override
  String get bookingsStatusAssigned => 'तकनीशियन नियुक्त';

  @override
  String get bookingsStatusInProgress => 'प्रगति पर';

  @override
  String get bookingsStatusCompleted => 'पूर्ण';

  @override
  String get bookingsStatusCancelled => 'रद्द';

  @override
  String get bookingsEmptyTitle => 'अभी तक कोई बुकिंग नहीं';

  @override
  String get bookingsEmptySubtitle =>
      'यहां देखने के लिए होम टैब से एक सेवा बुक करें';

  @override
  String get bookingsServiceBookingFallback => 'सेवा बुकिंग';

  @override
  String bookingsBookedOn(String date) {
    return '$date को बुक किया गया';
  }

  @override
  String get bookingsTechnicianFallback => 'तकनीशियन';

  @override
  String get bookingsChatTooltip => 'चैट';

  @override
  String get homePressBackExit => 'बाहर निकलने के लिए फिर से बैक दबाएं';

  @override
  String homeGreetingShort(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get homeSetLocationShort => 'अपना स्थान सेट करें';

  @override
  String get homeSearchServiceHint => 'सेवा खोजें...';

  @override
  String get homeMostBookedServices => 'सबसे अधिक बुक की गई सेवाएं';

  @override
  String get homeMyTechniciansShort => 'मेरे तकनीशियन';

  @override
  String homeCouldNotLoadRepeatTechnicians(String error) {
    return 'पुनरावृत्ति तकनीशियन लोड नहीं हो सके: $error';
  }

  @override
  String get homeTopPicksForYou => 'आपके लिए टॉप पिक्स';

  @override
  String get homeViewAllShort => 'सभी देखें';

  @override
  String get homeCouldNotLoadServices => 'सेवाएं लोड नहीं हो सकीं';

  @override
  String get homeNoServicesYet => 'अभी तक कोई सेवा उपलब्ध नहीं';

  @override
  String get homeCouldNotLoadTechnicians => 'तकनीशियन लोड नहीं हो सके';

  @override
  String get homeNoVerifiedTechnicians =>
      'अभी तक कोई सत्यापित तकनीशियन नहीं — बाद में फिर देखें';

  @override
  String get homeTechnicianFallback => 'तकनीशियन';

  @override
  String homeYearsExp(String years) {
    return '$years साल का अनुभव';
  }

  @override
  String get homeBannerHeading1 => 'आपके घर के लिए\nपेशेवर\n';

  @override
  String get homeBannerHeading2 => 'मदद';

  @override
  String get homeTrustedExperts => 'विश्वसनीय\nविशेषज्ञ';

  @override
  String get homeOnTimeService => 'समय पर\nसेवा';

  @override
  String get homeQualityGuaranteed => 'गुणवत्ता की\nगारंटी';

  @override
  String get guidedTourWelcomeTitle => 'HomeFix में आपका स्वागत है!';

  @override
  String get guidedTourWelcomeDesc =>
      'यहीं से अपनी होम सर्विस शुरू करें — इलेक्ट्रीशियन, प्लंबर, एसी रिपेयर, और भी बहुत कुछ।';

  @override
  String get guidedTourBookingsTitle => 'बुकिंग';

  @override
  String get guidedTourBookingsDesc =>
      'अपनी आगामी और पिछली बुकिंग यहां ट्रैक करें।';

  @override
  String get guidedTourAiTitle => 'एआई मूल्यांकन';

  @override
  String get guidedTourAiDesc =>
      'अपनी समस्या बताएं और तकनीशियन के पहुंचने से पहले ही तुरंत एआई-संचालित मूल्यांकन पाएं।';

  @override
  String get guidedTourConsultTitle => 'परामर्श';

  @override
  String get guidedTourConsultDesc =>
      'किसी तकनीशियन से चैट करें या लाइव वीडियो कॉल पर अपनी समस्या तुरंत दिखाएं।';

  @override
  String get guidedTourProfileTitle => 'प्रोफ़ाइल';

  @override
  String get guidedTourProfileDesc =>
      'यहां अपना खाता, पते, भुगतान और सेटिंग्स प्रबंधित करें।';

  @override
  String get aiDiagnosisTitle => 'एआई निदान';

  @override
  String get aiDiagnosisFoundTitle => 'हमें यह मिला';

  @override
  String get aiDiagnosisWhatIssueIs => 'समस्या क्या है';

  @override
  String get aiDiagnosisQuickQuestions => 'कुछ त्वरित प्रश्न';

  @override
  String get aiDiagnosisFixableRemotely => 'यह दूर से भी ठीक हो सकता है';

  @override
  String get aiDiagnosisRecommendOnsite => 'सुझाव: तकनीशियन की मौके पर विजिट';

  @override
  String get aiDiagnosisPossibleOptions => 'संभावित विकल्प';

  @override
  String get aiDiagnosisInstantGuidanceTitle => 'तुरंत एआई मार्गदर्शन पाएं';

  @override
  String get aiDiagnosisInstantGuidanceSubtitle =>
      'खुद ठीक करने की कोशिश के लिए एआई से चैट जारी रखें';

  @override
  String get aiDiagnosisBookDirectTitle => 'सीधे तकनीशियन बुक करें';

  @override
  String get aiDiagnosisBookDirectSubtitle =>
      'अपनी सुविधा अनुसार विजिट शेड्यूल करें';

  @override
  String get aiDiagnosisFlexibilityNote =>
      'इससे आपको सबसे अच्छा विकल्प चुनने की सुविधा मिलती है।';

  @override
  String get aiDiagnosisSuggestedTechnicians => 'सुझाए गए तकनीशियन';

  @override
  String get aiDiagnosisViewAll => 'सभी देखें';

  @override
  String get aiDiagnosisBookDirectlyBtn => 'सीधे बुक करें';

  @override
  String get aiDiagnosisAskFollowUp => 'एक फॉलो-अप सवाल पूछें...';

  @override
  String aiDiagnosisUnavailable(String error) {
    return 'एआई निदान अभी उपलब्ध नहीं है।\n$error';
  }

  @override
  String get aiDiagnosisStillBookDirectly =>
      'आप अभी भी सीधे तकनीशियन बुक कर सकते हैं।';

  @override
  String get aiDiagnosisBookTechnicianVisit => 'तकनीशियन विजिट बुक करें';

  @override
  String get aiDiagnosisTechnicianFallback => 'तकनीशियन';

  @override
  String aiDiagnosisYearsExp(String years) {
    return '$years साल का अनुभव';
  }

  @override
  String get chatTitle => 'चैट';

  @override
  String get chatRetry => 'पुनः प्रयास करें';

  @override
  String get chatEmptyState => 'अभी तक कोई संदेश नहीं। नमस्ते कहें!';

  @override
  String chatMessageHint(String peerName) {
    return '$peerName को संदेश भेजें';
  }

  @override
  String get consultTitle => 'परामर्श';

  @override
  String get consultTabChat => 'चैट';

  @override
  String get consultTabVideo => 'वीडियो';

  @override
  String get consultNoChatsTitle => 'अभी तक कोई चैट नहीं';

  @override
  String get consultNoChatsSubtitle =>
      'जब आपकी बुकिंग के लिए तकनीशियन असाइन हो जाएगा, तो आप यहां उनसे चैट कर सकेंगे।';

  @override
  String get consultServiceBookingFallback => 'सेवा बुकिंग';

  @override
  String get consultNoVideoCallsTitle => 'अभी तक कोई वीडियो कॉल नहीं';

  @override
  String get consultNoVideoCallsSubtitle =>
      'तकनीशियनों के साथ आपकी लाइव वीडियो परामर्श यहां दिखाई देंगी।';

  @override
  String get consultStatusCompleted => 'पूर्ण';

  @override
  String get consultStatusCancelled => 'रद्द';

  @override
  String get consultStatusTechnicianUnavailable => 'तकनीशियन अनुपलब्ध';

  @override
  String get consultStatusDeclined => 'अस्वीकृत';

  @override
  String get consultStatusNoExpertFound => 'कोई विशेषज्ञ नहीं मिला';

  @override
  String get consultStatusInCall => 'कॉल में';

  @override
  String get consultStatusConfirmed => 'पुष्टि की गई';

  @override
  String get consultStatusAwaitingConfirmation => 'पुष्टि की प्रतीक्षा में';

  @override
  String get consultStatusUpcoming => 'आगामी';

  @override
  String get consultHelperRejectedScheduled =>
      'तकनीशियन इस स्लॉट को होल्ड नहीं कर सका। कृपया नया समय चुनें।';

  @override
  String get consultHelperRejectedInstant => 'तकनीशियन यह कॉल नहीं ले सका।';

  @override
  String get consultHelperScheduled =>
      'तकनीशियन द्वारा इस स्लॉट की पुष्टि की प्रतीक्षा है।';

  @override
  String get consultHelperConfirmed =>
      'पुष्टि हो गई — कॉल निर्धारित समय पर स्वतः शुरू होगी।';

  @override
  String get consultHelperNoTechnician =>
      'इस कॉल को लेने के लिए कोई तकनीशियन उपलब्ध नहीं था।';

  @override
  String get consultTechnicianFallback => 'तकनीशियन';

  @override
  String get consultVideoConsultationFallback => 'वीडियो परामर्श';

  @override
  String consultMinutesShort(String minutes) {
    return '$minutes मिनट';
  }

  @override
  String get consultNewRecommendation => 'तकनीशियन की ओर से नई सिफारिश';

  @override
  String get consultNewBadge => 'नया';
}
