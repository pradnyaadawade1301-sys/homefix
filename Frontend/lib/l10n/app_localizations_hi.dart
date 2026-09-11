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
  String get techJobsLogoutTitle => 'लॉग आउट करें?';

  @override
  String get techJobsLogoutContent =>
      'अपनी जॉब्स देखने के लिए आपको फिर से साइन इन करना होगा।';

  @override
  String get techJobsCancel => 'रद्द करें';

  @override
  String get techJobsLogout => 'लॉग आउट';

  @override
  String get techJobsNavTitleJobs => 'मेरी जॉब्स';

  @override
  String get techJobsNavTitleConsultations => 'परामर्श';

  @override
  String get techJobsNavTitleSettlement => 'भुगतान विवरण';

  @override
  String get techJobsNavTitleHistory => 'इतिहास';

  @override
  String get techJobsMyCustomersTooltip => 'मेरे ग्राहक';

  @override
  String get techJobsLogoutTooltip => 'लॉग आउट';

  @override
  String get techJobsBottomNavJobs => 'जॉब्स';

  @override
  String get techJobsBottomNavUpcoming => 'आगामी';

  @override
  String get techJobsBottomNavSettlement => 'भुगतान';

  @override
  String get techJobsBottomNavHistory => 'चैट';

  @override
  String get techJobsWelcomeBack => 'वापसी पर स्वागत है 👋';

  @override
  String get techJobsWorkOverview => 'यह रहा आपके काम का सारांश';

  @override
  String get techJobsActive => 'सक्रिय';

  @override
  String get techJobsCompleted => 'पूर्ण';

  @override
  String get techJobsFilterAll => 'सभी';

  @override
  String techJobsCouldNotLoad(String error) {
    return 'आपकी जॉब्स लोड नहीं हो सकीं: $error';
  }

  @override
  String get techJobsRetry => 'पुनः प्रयास करें';

  @override
  String get techJobsNoActiveJobs => 'अभी कोई सक्रिय जॉब नहीं है';

  @override
  String get techJobsNoJobsYet => 'अभी तक कोई जॉब नहीं है';

  @override
  String get techJobsNewRequestsHint => 'नए ग्राहक अनुरोध यहाँ दिखाई देंगे';

  @override
  String get techJobsLiveConsultationRequest => '1 लाइव परामर्श अनुरोध';

  @override
  String techJobsLiveConsultationRequests(String count) {
    return '$count लाइव परामर्श अनुरोध';
  }

  @override
  String get techJobsTapAcceptReject =>
      'स्वीकार या अस्वीकार करने के लिए टैप करें';

  @override
  String get techJobsScheduledConsultation => '1 निर्धारित परामर्श';

  @override
  String techJobsScheduledConsultations(String count) {
    return '$count निर्धारित परामर्श';
  }

  @override
  String get techJobsTapConfirmDecline =>
      'स्लॉट पुष्टि या अस्वीकार करने के लिए टैप करें';

  @override
  String get techJobsServiceRequestFallback => 'सेवा अनुरोध';

  @override
  String get techJobsCustomerFallback => 'ग्राहक';

  @override
  String get techJobsChatTooltip => 'ग्राहक से चैट करें';

  @override
  String get techJobsDecline => 'अस्वीकार करें';

  @override
  String get techJobsAcceptJob => 'जॉब स्वीकार करें';

  @override
  String get techJobsOnMyWay => 'मैं रास्ते में हूँ';

  @override
  String get techJobsArrived => 'मैं पहुँच गया हूँ';

  @override
  String get techJobsGenerateInvoiceComplete => 'इनवॉइस बनाएं और पूरा करें';

  @override
  String get techJobsDeclineTitle => 'यह जॉब अस्वीकार करें?';

  @override
  String get techJobsDeclineContent =>
      'हम इस बुकिंग के लिए दूसरा तकनीशियन ढूंढ लेंगे। इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get techJobsGenerateInvoiceTitle => 'इनवॉइस बनाएं';

  @override
  String get techJobsInvoiceHint =>
      'ग्राहक को देय अंतिम राशि दर्ज करें। यह तुरंत उन्हें देय राशि के रूप में भेज दी जाएगी।';

  @override
  String get techJobsFinalAmount => 'अंतिम राशि';

  @override
  String get techJobsOfferWarranty => 'वारंटी प्रदान करें';

  @override
  String get techJobsWarrantySubtitle =>
      'ग्राहक इस अवधि में मुफ्त पुनः विज़िट का अनुरोध कर सकता है';

  @override
  String get techJobsDuration => 'अवधि';

  @override
  String get techJobsDurationHint => 'जैसे 6';

  @override
  String get techJobsWarrantyCoverageLabel => 'यह वारंटी किसके लिए है?';

  @override
  String get techJobsWarrantyCoverageHint =>
      'जैसे: सिर्फ कंप्रेसर और गैस रिफिल';

  @override
  String get techJobsDays => 'दिन';

  @override
  String get techJobsMonths => 'महीने';

  @override
  String get techJobsYears => 'साल';

  @override
  String get techJobsEnterValidAmount => 'मान्य राशि दर्ज करें';

  @override
  String get techJobsEnterValidWarranty => 'मान्य वारंटी अवधि दर्ज करें';

  @override
  String get techJobsSendInvoice => 'इनवॉइस भेजें';

  @override
  String get techJobsAskOtp => 'सेवा शुरू करने के लिए ग्राहक से OTP माँगें';

  @override
  String get techJobsEnterOtp => '4 अंकों का OTP दर्ज करें';

  @override
  String get techJobsIncorrectOtp => 'गलत OTP, फिर से कोशिश करें';

  @override
  String get techJobsVerify => 'सत्यापित करें';

  @override
  String get techSettlementVisitHistory => 'विज़िट इतिहास';

  @override
  String get techSettlementPaymentHistory => 'भुगतान इतिहास';

  @override
  String get techSettlementNoCompletedVisits => 'अभी तक कोई पूर्ण विज़िट नहीं';

  @override
  String get techSettlementNoPayments => 'अभी तक कोई भुगतान नहीं';

  @override
  String get techSettlementTotalEarned => 'कुल कमाई';

  @override
  String get techSettlementJobsCompleted => 'पूर्ण जॉब्स';

  @override
  String techSettlementYourShare(String amount) {
    return 'आपका हिस्सा: ₹$amount';
  }

  @override
  String get techSettlementCustomerFallback => 'ग्राहक';

  @override
  String get consultUpcomingSlotConfirmed => 'स्लॉट की पुष्टि हो गई';

  @override
  String consultUpcomingCouldNotConfirm(String error) {
    return 'पुष्टि नहीं हो सकी: $error';
  }

  @override
  String get consultUpcomingDeclineTitle => 'यह स्लॉट अस्वीकार करें?';

  @override
  String consultUpcomingDeclineContent(String slot) {
    return 'ग्राहक को सूचित किया जाएगा कि आप $slot पर उपलब्ध नहीं हैं और उन्हें दूसरा समय चुनने को कहा जाएगा।';
  }

  @override
  String get consultUpcomingReasonOptional => 'कारण (वैकल्पिक)';

  @override
  String get consultUpcomingReasonHint => 'जैसे उस समय उपलब्ध नहीं';

  @override
  String get consultUpcomingCancel => 'रद्द करें';

  @override
  String get consultUpcomingDecline => 'अस्वीकार करें';

  @override
  String get consultUpcomingSlotDeclined => 'स्लॉट अस्वीकार कर दिया गया';

  @override
  String consultUpcomingCouldNotDecline(String error) {
    return 'अस्वीकार नहीं हो सका: $error';
  }

  @override
  String get consultUpcomingThisSlot => 'यह स्लॉट';

  @override
  String get consultUpcomingNoUpcoming => 'कोई आगामी परामर्श नहीं';

  @override
  String get consultUpcomingScheduledHint =>
      'ग्राहकों के निर्धारित अनुरोध यहाँ दिखाई देंगे';

  @override
  String get consultUpcomingTitle => 'आगामी परामर्श';

  @override
  String get consultUpcomingFallback => 'परामर्श';

  @override
  String get consultUpcomingNeedsConfirmation => 'पुष्टि आवश्यक';

  @override
  String get consultUpcomingConfirmedLabel => 'पुष्टि हो गई';

  @override
  String get consultUpcomingCustomerFallback => 'ग्राहक';

  @override
  String get consultUpcomingConfirm => 'पुष्टि करें';

  @override
  String get consultUpcomingWaitingSlot =>
      'स्लॉट समय की प्रतीक्षा है — शुरू होने पर आपको सूचित किया जाएगा';

  @override
  String get consultMyTitle => 'मेरे परामर्श';

  @override
  String get consultMyNoneYet => 'अभी तक कोई परामर्श नहीं';

  @override
  String get consultMyFallback => 'परामर्श';

  @override
  String consultMyWith(String name) {
    return '$name के साथ';
  }

  @override
  String get consultMyRequestAgain => 'फिर से अनुरोध करें';

  @override
  String get consultMyAwaitingConfirmation => 'पुष्टि की प्रतीक्षा है';

  @override
  String get consultMyAwaitingConfirmationMsg =>
      'तकनीशियन द्वारा आपके अनुरोधित स्लॉट की पुष्टि की प्रतीक्षा है।';

  @override
  String get consultMyConfirmed => 'पुष्टि हो गई';

  @override
  String get consultMyConfirmedMsg =>
      'आपके तकनीशियन ने पुष्टि कर दी है। कॉल आपके निर्धारित समय पर अपने आप शुरू होगी।';

  @override
  String get consultMySearching => 'खोज रहे हैं';

  @override
  String get consultMySearchingMsg => 'उपलब्ध तकनीशियन खोजा जा रहा है...';

  @override
  String get consultMyRinging => 'रिंग हो रही है';

  @override
  String get consultMyRingingMsg => 'तकनीशियन को अभी कॉल किया जा रहा है...';

  @override
  String get consultMyAccepted => 'स्वीकार किया गया';

  @override
  String get consultMyAcceptedMsg =>
      'तकनीशियन ने स्वीकार किया — आपकी कॉल जोड़ी जा रही है।';

  @override
  String get consultMyTechUnavailable => 'तकनीशियन उपलब्ध नहीं';

  @override
  String get consultMyNotAnswered => 'कोई उत्तर नहीं';

  @override
  String get consultMyRejectedScheduledMsg =>
      'तकनीशियन व्यस्त था और इस स्लॉट पर उपलब्ध नहीं हो सका। कृपया नया समय चुनें।';

  @override
  String get consultMyRejectedInstantMsg =>
      'तकनीशियन आपकी कॉल नहीं ले सका। आप फिर से कोशिश कर सकते हैं।';

  @override
  String consultMyReasonPrefix(String reason) {
    return 'कारण: $reason';
  }

  @override
  String get consultMyNoTechAvailable => 'कोई तकनीशियन उपलब्ध नहीं';

  @override
  String get consultMyNoTechAvailableMsg =>
      'इस अनुरोध के लिए कोई तकनीशियन उपलब्ध नहीं था। कृपया बाद में फिर से कोशिश करें।';

  @override
  String get consultMyInCall => 'कॉल में';

  @override
  String get consultMyInCallMsg => 'कॉल जारी है।';

  @override
  String get consultMyCompleted => 'पूर्ण';

  @override
  String get consultMyCompletedMsg => 'यह परामर्श समाप्त हो गया है।';

  @override
  String get consultMyCancelled => 'रद्द किया गया';

  @override
  String get consultMyCancelledMsg => 'आपने यह अनुरोध रद्द कर दिया।';

  @override
  String get consultTitle => 'परामर्श';

  @override
  String get consultTabChat => 'चैट';

  @override
  String get consultTabVideo => 'वीडियो';

  @override
  String get consultTabCall => 'कॉल';

  @override
  String get consultNoCallsTitle => 'अभी तक कोई कॉल नहीं';

  @override
  String get consultNoCallsSubtitle =>
      'जब आपकी बुकिंग के लिए टेक्नीशियन तय हो जाएगा, तो आप उन्हें यहाँ कॉल कर सकेंगे।';

  @override
  String get consultNoChatsTitle => 'अभी तक कोई चैट नहीं';

  @override
  String get consultNoChatsSubtitle =>
      'जब आपकी बुकिंग के लिए कोई तकनीशियन नियुक्त होगा, तो आप उससे यहाँ चैट कर सकेंगे।';

  @override
  String get consultServiceBookingFallback => 'सेवा बुकिंग';

  @override
  String get consultNoVideoCallsTitle => 'अभी तक कोई वीडियो परामर्श नहीं';

  @override
  String get consultNoVideoCallsSubtitle =>
      'तकनीशियनों के साथ आपके लाइव वीडियो परामर्श यहाँ दिखाई देंगे।';

  @override
  String get consultStatusCompleted => 'पूर्ण';

  @override
  String get consultStatusCancelled => 'रद्द';

  @override
  String get consultStatusTechnicianUnavailable => 'तकनीशियन उपलब्ध नहीं';

  @override
  String get consultStatusDeclined => 'अस्वीकृत';

  @override
  String get consultStatusNoExpertFound => 'कोई विशेषज्ञ नहीं मिला';

  @override
  String get consultStatusInCall => 'कॉल में';

  @override
  String get consultStatusConfirmed => 'पुष्टि हुई';

  @override
  String get consultStatusAwaitingConfirmation => 'पुष्टि की प्रतीक्षा में';

  @override
  String get consultStatusUpcoming => 'आगामी';

  @override
  String get consultHelperRejectedScheduled =>
      'तकनीशियन इस स्लॉट को बनाए नहीं रख सका। कृपया नया समय निर्धारित करें।';

  @override
  String get consultHelperRejectedInstant =>
      'तकनीशियन इस कॉल के लिए उपलब्ध नहीं था।';

  @override
  String get consultHelperScheduled => 'तकनीशियन की पुष्टि की प्रतीक्षा है।';

  @override
  String get consultHelperConfirmed =>
      'तकनीशियन ने इस स्लॉट की पुष्टि कर दी है।';

  @override
  String get consultHelperNoTechnician =>
      'इस परामर्श के लिए कोई तकनीशियन उपलब्ध नहीं था।';

  @override
  String get consultTechnicianFallback => 'तकनीशियन';

  @override
  String get consultVideoConsultationFallback => 'वीडियो परामर्श';

  @override
  String get consultNewRecommendation => 'आपके तकनीशियन की नई सिफारिश';

  @override
  String get consultNewBadge => 'नया';

  @override
  String consultMinutesShort(String minutes) {
    return '$minutes मिनट';
  }

  @override
  String get profileLogoutDialogTitle => 'लॉग आउट करें?';

  @override
  String get profileLogoutDialogContent =>
      'क्या आप वाकई अपने खाते से लॉग आउट करना चाहते हैं?';

  @override
  String get profileLogoutConfirm => 'लॉग आउट';

  @override
  String get profileDeleteDialogTitle => 'खाता हटाएं?';

  @override
  String get profileDeleteDialogContent =>
      'इससे आपका खाता और सभी संबंधित डेटा स्थायी रूप से हट जाएगा। यह क्रिया पूर्ववत नहीं की जा सकती।';

  @override
  String get profileDeleteConfirm => 'हटाएं';

  @override
  String get profileLogInButton => 'लॉग इन करें';

  @override
  String get profileTechnicianDefaultName => 'तकनीशियन';

  @override
  String get profileRegistrationIncompleteMsg =>
      'आपका तकनीशियन पंजीकरण अधूरा है। काम पाना शुरू करने के लिए इसे पूरा करें।';

  @override
  String get profileCompleteRegistration => 'पंजीकरण पूरा करें';

  @override
  String get profileLogOutButton => 'लॉग आउट';

  @override
  String get profileNoRatingsYet => 'अभी तक कोई रेटिंग नहीं';

  @override
  String get profileOnlineStatus => 'ऑनलाइन';

  @override
  String get profileOfflineStatus => 'ऑफ़लाइन';

  @override
  String get profileCanBookNow => 'ग्राहक अभी आपको बुक कर सकते हैं';

  @override
  String get profileNoNewRequests => 'आपको नए अनुरोध नहीं मिलेंगे';

  @override
  String get profileNeedKycApproval =>
      'ऑनलाइन जाने के लिए KYC अनुमोदन पूरा करें';

  @override
  String get profileSectionProfessionalDetails => 'व्यावसायिक विवरण';

  @override
  String get profilePrimaryService => 'प्राथमिक सेवा';

  @override
  String get profileYearsExperienceLabel => 'अनुभव के वर्ष';

  @override
  String get profileAddressLabel => 'पता';

  @override
  String get profileServiceRadius => 'सेवा त्रिज्या';

  @override
  String get profileSectionTrustVerification => 'विश्वास और सत्यापन';

  @override
  String get profilePhoneVerified => 'फोन सत्यापित';

  @override
  String get profileProfileVerified => 'प्रोफ़ाइल सत्यापित';

  @override
  String get profileGovIdUploaded => 'सरकारी आईडी अपलोड की गई';

  @override
  String get profileSectionDocuments => 'दस्तावेज़';

  @override
  String get profileGovId => 'सरकारी आईडी';

  @override
  String get profileBankUpiDetails => 'बैंक / UPI विवरण';

  @override
  String get profileSectionWork => 'काम';

  @override
  String get profileLiveConsultationRequestsLabel => 'लाइव परामर्श अनुरोध';

  @override
  String get profileNotificationSettings => 'सूचना सेटिंग्स';

  @override
  String get profilePaymentSettings => 'भुगतान सेटिंग्स';

  @override
  String get profilePrivacySecurity => 'गोपनीयता और सुरक्षा';

  @override
  String get profileChangePasswordPin => 'पासवर्ड / पिन बदलें';

  @override
  String get profileVerifiedStatus => 'सत्यापित';

  @override
  String get profilePendingStatus => 'लंबित';

  @override
  String get profileApprovalApproved => 'स्वीकृत';

  @override
  String get profileApprovalRejected => 'अस्वीकृत';

  @override
  String get profileApprovalPending => 'अनुमोदन लंबित';

  @override
  String get profileComingSoonMessage =>
      'यह सुविधा जल्द आ रही है। हम इसे आप तक लाने के लिए काम कर रहे हैं।';

  @override
  String get profileGoBackButton => 'वापस जाएं';

  @override
  String profileYearsValue(String years) {
    return '$years वर्ष';
  }

  @override
  String profileRejectionReason(String reason) {
    return 'कारण: $reason';
  }
}
