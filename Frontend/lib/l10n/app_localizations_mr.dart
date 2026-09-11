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

  @override
  String get loginWelcomeBack => 'परत स्वागत आहे';

  @override
  String get loginSubtitle =>
      'विश्वासार्ह होम सर्व्हिसेस बुक करण्यासाठी साइन इन करा';

  @override
  String get loginIdentifierHint => 'ईमेल किंवा फोन नंबर';

  @override
  String get loginIdentifierRequired => 'ईमेल किंवा फोन नंबर आवश्यक आहे';

  @override
  String get loginPasswordHint => 'पासवर्ड';

  @override
  String get loginPasswordRequired => 'पासवर्ड आवश्यक आहे';

  @override
  String get loginForgotPassword => 'पासवर्ड विसरलात?';

  @override
  String get loginForgotPasswordComingSoon =>
      'पासवर्ड रीसेट सुविधा लवकरच येत आहे';

  @override
  String get loginSignIn => 'साइन इन करा';

  @override
  String get loginOr => 'किंवा';

  @override
  String get loginContinueWithGoogle => 'Google सह सुरू ठेवा';

  @override
  String loginGoogleSignInFailed(String error) {
    return 'Google साइन-इन अयशस्वी: $error';
  }

  @override
  String get loginTrustedBanner => 'हजारो वापरकर्त्यांचा विश्वास';

  @override
  String get loginTrustedSubtitle =>
      'सत्यापित तंत्रज्ञ • सुरक्षित बुकिंग • 24/7 सहाय्य';

  @override
  String get loginNoAccount => 'खाते नाही? ';

  @override
  String get loginSignUp => 'साइन अप करा';

  @override
  String get signupPasswordRequiredValidator => 'पासवर्ड आवश्यक आहे';

  @override
  String get signupPasswordTooShort => 'पासवर्ड किमान 8 अक्षरांचा असावा';

  @override
  String get signupPasswordNeedsLetterSpecial =>
      'एक अक्षर आणि एक विशेष चिन्ह जोडा (फक्त क्रमांक नाही)';

  @override
  String get signupCreateYourAccount => 'तुमचे खाते तयार करा';

  @override
  String get signupJoinSubtitle =>
      'ग्राहक किंवा तंत्रज्ञ म्हणून HomeFix Live मध्ये सामील व्हा';

  @override
  String get signupIAmA => 'मी आहे एक';

  @override
  String get signupRoleCustomer => 'ग्राहक';

  @override
  String get signupRoleTechnician => 'तंत्रज्ञ';

  @override
  String get signupNameHint => 'पूर्ण नाव';

  @override
  String get signupNameRequired => 'नाव आवश्यक आहे';

  @override
  String get signupEmailHint => 'ईमेल पत्ता';

  @override
  String get signupEmailRequired => 'ईमेल आवश्यक आहे';

  @override
  String get signupEmailInvalid => 'वैध ईमेल टाका';

  @override
  String get signupPhoneHint => 'फोन नंबर';

  @override
  String get signupPhoneRequired => 'फोन नंबर आवश्यक आहे';

  @override
  String get signupPhoneInvalid => 'वैध फोन नंबर टाका';

  @override
  String get signupPasswordHint => 'पासवर्ड';

  @override
  String get signupPasswordHelper =>
      'किमान 8 अक्षरे, एक अक्षर आणि एक विशेष चिन्हासह';

  @override
  String get signupDataSafeBanner => 'तुमचा डेटा आमच्याकडे सुरक्षित आहे';

  @override
  String get signupDataSafeSubtitle => 'आम्ही तुमची माहिती कधीही शेअर करत नाही';

  @override
  String get signupCreateAccount => 'खाते तयार करा';

  @override
  String get signupHaveAccount => 'आधीच खाते आहे? ';

  @override
  String get signupSignIn => 'साइन इन करा';

  @override
  String get bookingsTitle => 'माझ्या बुकिंग';

  @override
  String get bookingsCancelDialogTitle => 'ही बुकिंग रद्द करायची?';

  @override
  String get bookingsCancelDialogBody =>
      'यामुळे तुमची बुकिंग रद्द होईल आणि तंत्रज्ञ नियुक्त असल्यास त्याला सूचित केले जाईल.';

  @override
  String get bookingsCancelReasonLabel => 'कारण (ऐच्छिक)';

  @override
  String get bookingsKeepBooking => 'बुकिंग ठेवा';

  @override
  String get bookingsYesCancel => 'होय, रद्द करा';

  @override
  String get bookingsCancelledMsg => 'बुकिंग रद्द केली';

  @override
  String get bookingsCouldNotCancel => 'बुकिंग रद्द करता आली नाही';

  @override
  String get bookingsStatusFinding => 'तंत्रज्ञ शोधत आहोत';

  @override
  String get bookingsStatusWaiting => 'तंत्रज्ञाची वाट पाहत आहोत';

  @override
  String get bookingsStatusAssigned => 'तंत्रज्ञ नियुक्त';

  @override
  String get bookingsStatusInProgress => 'प्रगतीपथावर';

  @override
  String get bookingsStatusCompleted => 'पूर्ण';

  @override
  String get bookingsStatusCancelled => 'रद्द';

  @override
  String get bookingsEmptyTitle => 'अद्याप कोणतीही बुकिंग नाही';

  @override
  String get bookingsEmptySubtitle =>
      'येथे पाहण्यासाठी होम टॅबवरून सेवा बुक करा';

  @override
  String get bookingsServiceBookingFallback => 'सेवा बुकिंग';

  @override
  String bookingsBookedOn(String date) {
    return '$date रोजी बुक केले';
  }

  @override
  String get bookingsTechnicianFallback => 'तंत्रज्ञ';

  @override
  String get bookingsChatTooltip => 'चॅट';

  @override
  String get homePressBackExit => 'बाहेर पडण्यासाठी पुन्हा बॅक दाबा';

  @override
  String homeGreetingShort(String name) {
    return 'नमस्कार, $name';
  }

  @override
  String get homeSetLocationShort => 'तुमचे स्थान सेट करा';

  @override
  String get homeSearchServiceHint => 'सेवा शोधा...';

  @override
  String get homeMostBookedServices => 'सर्वाधिक बुक केलेल्या सेवा';

  @override
  String get homeMyTechniciansShort => 'माझे तंत्रज्ञ';

  @override
  String homeCouldNotLoadRepeatTechnicians(String error) {
    return 'पुनरावृत्ती तंत्रज्ञ लोड करता आले नाहीत: $error';
  }

  @override
  String get homeTopPicksForYou => 'तुमच्यासाठी टॉप पिक्स';

  @override
  String get homeViewAllShort => 'सर्व पहा';

  @override
  String get homeCouldNotLoadServices => 'सेवा लोड करता आल्या नाहीत';

  @override
  String get homeNoServicesYet => 'अद्याप कोणतीही सेवा उपलब्ध नाही';

  @override
  String get homeCouldNotLoadTechnicians => 'तंत्रज्ञ लोड करता आले नाहीत';

  @override
  String get homeNoVerifiedTechnicians =>
      'अद्याप कोणताही सत्यापित तंत्रज्ञ नाही — नंतर पुन्हा तपासा';

  @override
  String get homeTechnicianFallback => 'तंत्रज्ञ';

  @override
  String homeYearsExp(String years) {
    return '$years वर्षांचा अनुभव';
  }

  @override
  String get homeBannerHeading1 => 'तुमच्या घरासाठी\nव्यावसायिक\n';

  @override
  String get homeBannerHeading2 => 'मदत';

  @override
  String get homeTrustedExperts => 'विश्वासार्ह\nतज्ञ';

  @override
  String get homeOnTimeService => 'वेळेवर\nसेवा';

  @override
  String get homeQualityGuaranteed => 'गुणवत्तेची\nहमी';

  @override
  String get guidedTourWelcomeTitle => 'HomeFix मध्ये आपले स्वागत आहे!';

  @override
  String get guidedTourWelcomeDesc =>
      'इथूनच तुमची होम सर्व्हिस सुरू करा — इलेक्ट्रिशियन, प्लंबर, एसी दुरुस्ती आणि बरेच काही.';

  @override
  String get guidedTourBookingsTitle => 'बुकिंग';

  @override
  String get guidedTourBookingsDesc =>
      'तुमच्या आगामी आणि मागील बुकिंग येथे ट्रॅक करा.';

  @override
  String get guidedTourAiTitle => 'एआय मूल्यांकन';

  @override
  String get guidedTourAiDesc =>
      'तुमची समस्या सांगा आणि तंत्रज्ञ पोहोचण्यापूर्वीच तात्काळ एआय-चलित मूल्यांकन मिळवा.';

  @override
  String get guidedTourConsultTitle => 'सल्ला';

  @override
  String get guidedTourConsultDesc =>
      'तंत्रज्ञाशी चॅट करा किंवा लाइव्ह व्हिडिओ कॉलवर तुमची समस्या लगेच दाखवा.';

  @override
  String get guidedTourProfileTitle => 'प्रोफाइल';

  @override
  String get guidedTourProfileDesc =>
      'तुमचे खाते, पत्ते, पेमेंट आणि सेटिंग्ज येथे व्यवस्थापित करा.';

  @override
  String get aiDiagnosisTitle => 'एआय निदान';

  @override
  String get aiDiagnosisFoundTitle => 'आम्हाला हे आढळले';

  @override
  String get aiDiagnosisWhatIssueIs => 'समस्या काय आहे';

  @override
  String get aiDiagnosisQuickQuestions => 'काही जलद प्रश्न';

  @override
  String get aiDiagnosisFixableRemotely => 'हे दुरूनही दुरुस्त होऊ शकते';

  @override
  String get aiDiagnosisRecommendOnsite => 'शिफारस: तंत्रज्ञाची प्रत्यक्ष भेट';

  @override
  String get aiDiagnosisPossibleOptions => 'संभाव्य पर्याय';

  @override
  String get aiDiagnosisInstantGuidanceTitle => 'त्वरित एआय मार्गदर्शन मिळवा';

  @override
  String get aiDiagnosisInstantGuidanceSubtitle =>
      'स्वतः दुरुस्त करण्याचा प्रयत्न करण्यासाठी एआयशी चॅट सुरू ठेवा';

  @override
  String get aiDiagnosisBookDirectTitle => 'थेट तंत्रज्ञ बुक करा';

  @override
  String get aiDiagnosisBookDirectSubtitle =>
      'तुम्हाला सोयीच्या वेळी भेट शेड्यूल करा';

  @override
  String get aiDiagnosisFlexibilityNote =>
      'यामुळे तुम्हाला सर्वोत्तम पर्याय निवडण्याची लवचिकता मिळते.';

  @override
  String get aiDiagnosisSuggestedTechnicians => 'सुचवलेले तंत्रज्ञ';

  @override
  String get aiDiagnosisViewAll => 'सर्व पहा';

  @override
  String get aiDiagnosisBookDirectlyBtn => 'थेट बुक करा';

  @override
  String get aiDiagnosisAskFollowUp => 'फॉलो-अप प्रश्न विचारा...';

  @override
  String aiDiagnosisUnavailable(String error) {
    return 'एआय निदान सध्या उपलब्ध नाही.\n$error';
  }

  @override
  String get aiDiagnosisStillBookDirectly =>
      'तुम्ही तरीही थेट तंत्रज्ञ बुक करू शकता.';

  @override
  String get aiDiagnosisBookTechnicianVisit => 'तंत्रज्ञ भेट बुक करा';

  @override
  String get aiDiagnosisTechnicianFallback => 'तंत्रज्ञ';

  @override
  String aiDiagnosisYearsExp(String years) {
    return '$years वर्षांचा अनुभव';
  }

  @override
  String get chatTitle => 'चॅट';

  @override
  String get chatRetry => 'पुन्हा प्रयत्न करा';

  @override
  String get chatEmptyState => 'अद्याप कोणतेही संदेश नाहीत. नमस्कार म्हणा!';

  @override
  String chatMessageHint(String peerName) {
    return '$peerName ला संदेश पाठवा';
  }

  @override
  String get techJobsLogoutTitle => 'लॉग आउट करायचे?';

  @override
  String get techJobsLogoutContent =>
      'तुमच्या जॉब्स पाहण्यासाठी तुम्हाला पुन्हा साइन इन करावे लागेल.';

  @override
  String get techJobsCancel => 'रद्द करा';

  @override
  String get techJobsLogout => 'लॉग आउट';

  @override
  String get techJobsNavTitleJobs => 'माझ्या जॉब्स';

  @override
  String get techJobsNavTitleConsultations => 'सल्लामसलत';

  @override
  String get techJobsNavTitleSettlement => 'सेटलमेंट';

  @override
  String get techJobsNavTitleHistory => 'इतिहास';

  @override
  String get techJobsMyCustomersTooltip => 'माझे ग्राहक';

  @override
  String get techJobsLogoutTooltip => 'लॉग आउट';

  @override
  String get techJobsBottomNavJobs => 'जॉब्स';

  @override
  String get techJobsBottomNavUpcoming => 'आगामी';

  @override
  String get techJobsBottomNavSettlement => 'सेटलमेंट';

  @override
  String get techJobsBottomNavHistory => 'चॅट';

  @override
  String get techJobsWelcomeBack => 'परत स्वागत आहे 👋';

  @override
  String get techJobsWorkOverview => 'हा आहे तुमच्या कामाचा आढावा';

  @override
  String get techJobsActive => 'सक्रिय';

  @override
  String get techJobsCompleted => 'पूर्ण';

  @override
  String get techJobsFilterAll => 'सर्व';

  @override
  String techJobsCouldNotLoad(String error) {
    return 'तुमच्या जॉब्स लोड होऊ शकल्या नाहीत: $error';
  }

  @override
  String get techJobsRetry => 'पुन्हा प्रयत्न करा';

  @override
  String get techJobsNoActiveJobs => 'सध्या कोणतीही सक्रिय जॉब नाही';

  @override
  String get techJobsNoJobsYet => 'अद्याप कोणतीही जॉब नाही';

  @override
  String get techJobsNewRequestsHint => 'नवीन ग्राहक विनंत्या इथे दिसतील';

  @override
  String get techJobsLiveConsultationRequest => '1 लाइव्ह सल्लामसलत विनंती';

  @override
  String techJobsLiveConsultationRequests(String count) {
    return '$count लाइव्ह सल्लामसलत विनंत्या';
  }

  @override
  String get techJobsTapAcceptReject =>
      'स्वीकारण्यासाठी किंवा नाकारण्यासाठी टॅप करा';

  @override
  String get techJobsScheduledConsultation => '1 नियोजित सल्लामसलत';

  @override
  String techJobsScheduledConsultations(String count) {
    return '$count नियोजित सल्लामसलती';
  }

  @override
  String get techJobsTapConfirmDecline =>
      'स्लॉट पुष्टी किंवा नाकारण्यासाठी टॅप करा';

  @override
  String get techJobsServiceRequestFallback => 'सेवा विनंती';

  @override
  String get techJobsCustomerFallback => 'ग्राहक';

  @override
  String get techJobsChatTooltip => 'ग्राहकाशी चॅट करा';

  @override
  String get techJobsDecline => 'नाकारा';

  @override
  String get techJobsAcceptJob => 'जॉब स्वीकारा';

  @override
  String get techJobsOnMyWay => 'मी येत आहे';

  @override
  String get techJobsArrived => 'मी पोहोचलो/पोहोचले आहे';

  @override
  String get techJobsGenerateInvoiceComplete =>
      'इनव्हॉइस तयार करा आणि पूर्ण करा';

  @override
  String get techJobsDeclineTitle => 'ही जॉब नाकारायची?';

  @override
  String get techJobsDeclineContent =>
      'आम्ही या बुकिंगसाठी दुसरा टेक्निशियन शोधू. हे पूर्ववत करता येणार नाही.';

  @override
  String get techJobsGenerateInvoiceTitle => 'इनव्हॉइस तयार करा';

  @override
  String get techJobsInvoiceHint =>
      'ग्राहकाने द्यायची अंतिम रक्कम टाका. ही रक्कम त्यांना लगेच देय म्हणून पाठवली जाईल.';

  @override
  String get techJobsFinalAmount => 'अंतिम रक्कम';

  @override
  String get techJobsOfferWarranty => 'वॉरंटी द्या';

  @override
  String get techJobsWarrantySubtitle =>
      'या कालावधीत ग्राहक मोफत पुन्हा-भेटीची विनंती करू शकतो';

  @override
  String get techJobsDuration => 'कालावधी';

  @override
  String get techJobsDurationHint => 'उदा. 6';

  @override
  String get techJobsWarrantyCoverageLabel => 'ही वॉरंटी कशासाठी आहे?';

  @override
  String get techJobsWarrantyCoverageHint => 'उदा: फक्त कंप्रेसर आणि गॅस रिफिल';

  @override
  String get techJobsDays => 'दिवस';

  @override
  String get techJobsMonths => 'महिने';

  @override
  String get techJobsYears => 'वर्षे';

  @override
  String get techJobsEnterValidAmount => 'वैध रक्कम टाका';

  @override
  String get techJobsEnterValidWarranty => 'वैध वॉरंटी कालावधी टाका';

  @override
  String get techJobsSendInvoice => 'इनव्हॉइस पाठवा';

  @override
  String get techJobsAskOtp => 'सेवा सुरू करण्यासाठी ग्राहकाला OTP विचारा';

  @override
  String get techJobsEnterOtp => '4 अंकी OTP टाका';

  @override
  String get techJobsIncorrectOtp => 'चुकीचा OTP, पुन्हा प्रयत्न करा';

  @override
  String get techJobsVerify => 'पडताळणी करा';

  @override
  String get techSettlementVisitHistory => 'भेट इतिहास';

  @override
  String get techSettlementPaymentHistory => 'पेमेंट इतिहास';

  @override
  String get techSettlementNoCompletedVisits => 'अद्याप कोणतीही पूर्ण भेट नाही';

  @override
  String get techSettlementNoPayments => 'अद्याप कोणतेही पेमेंट नाही';

  @override
  String get techSettlementTotalEarned => 'एकूण कमाई';

  @override
  String get techSettlementJobsCompleted => 'पूर्ण जॉब्स';

  @override
  String techSettlementYourShare(String amount) {
    return 'तुमचा वाटा: ₹$amount';
  }

  @override
  String get techSettlementCustomerFallback => 'ग्राहक';

  @override
  String get consultUpcomingSlotConfirmed => 'स्लॉट निश्चित झाला';

  @override
  String consultUpcomingCouldNotConfirm(String error) {
    return 'निश्चित करता आले नाही: $error';
  }

  @override
  String get consultUpcomingDeclineTitle => 'हा स्लॉट नाकारायचा?';

  @override
  String consultUpcomingDeclineContent(String slot) {
    return 'तुम्ही $slot वेळी उपलब्ध नाही याची ग्राहकाला सूचना दिली जाईल आणि दुसरी वेळ निवडण्यास सांगितले जाईल.';
  }

  @override
  String get consultUpcomingReasonOptional => 'कारण (ऐच्छिक)';

  @override
  String get consultUpcomingReasonHint => 'उदा. त्या वेळी उपलब्ध नाही';

  @override
  String get consultUpcomingCancel => 'रद्द करा';

  @override
  String get consultUpcomingDecline => 'नाकारा';

  @override
  String get consultUpcomingSlotDeclined => 'स्लॉट नाकारला';

  @override
  String consultUpcomingCouldNotDecline(String error) {
    return 'नाकारता आले नाही: $error';
  }

  @override
  String get consultUpcomingThisSlot => 'हा स्लॉट';

  @override
  String get consultUpcomingNoUpcoming => 'कोणतीही आगामी सल्लामसलत नाही';

  @override
  String get consultUpcomingScheduledHint =>
      'ग्राहकांच्या नियोजित विनंत्या इथे दिसतील';

  @override
  String get consultUpcomingTitle => 'आगामी सल्लामसलत';

  @override
  String get consultUpcomingFallback => 'सल्लामसलत';

  @override
  String get consultUpcomingNeedsConfirmation => 'पुष्टी आवश्यक';

  @override
  String get consultUpcomingConfirmedLabel => 'निश्चित झाले';

  @override
  String get consultUpcomingCustomerFallback => 'ग्राहक';

  @override
  String get consultUpcomingConfirm => 'पुष्टी करा';

  @override
  String get consultUpcomingWaitingSlot =>
      'स्लॉट वेळेची प्रतीक्षा आहे — सुरू झाल्यावर तुम्हाला सूचित केले जाईल';

  @override
  String get consultMyTitle => 'माझी सल्लामसलत';

  @override
  String get consultMyNoneYet => 'अद्याप कोणतीही सल्लामसलत नाही';

  @override
  String get consultMyFallback => 'सल्लामसलत';

  @override
  String consultMyWith(String name) {
    return '$name सोबत';
  }

  @override
  String get consultMyRequestAgain => 'पुन्हा विनंती करा';

  @override
  String get consultMyAwaitingConfirmation => 'पुष्टीची प्रतीक्षा आहे';

  @override
  String get consultMyAwaitingConfirmationMsg =>
      'टेक्निशियनने तुमच्या विनंती केलेल्या स्लॉटची पुष्टी करण्याची प्रतीक्षा आहे.';

  @override
  String get consultMyConfirmed => 'निश्चित झाले';

  @override
  String get consultMyConfirmedMsg =>
      'तुमच्या टेक्निशियनने पुष्टी केली आहे. तुमच्या नियोजित वेळी कॉल आपोआप सुरू होईल.';

  @override
  String get consultMySearching => 'शोधत आहे';

  @override
  String get consultMySearchingMsg => 'उपलब्ध टेक्निशियन शोधला जात आहे...';

  @override
  String get consultMyRinging => 'रिंग होत आहे';

  @override
  String get consultMyRingingMsg => 'टेक्निशियनला आत्ता कॉल केला जात आहे...';

  @override
  String get consultMyAccepted => 'स्वीकारले';

  @override
  String get consultMyAcceptedMsg =>
      'टेक्निशियनने स्वीकारले — तुमचा कॉल जोडला जात आहे.';

  @override
  String get consultMyTechUnavailable => 'टेक्निशियन उपलब्ध नाही';

  @override
  String get consultMyNotAnswered => 'उत्तर मिळाले नाही';

  @override
  String get consultMyRejectedScheduledMsg =>
      'टेक्निशियन व्यस्त होता आणि या स्लॉटसाठी उपलब्ध होऊ शकला नाही. कृपया नवीन वेळ निवडा.';

  @override
  String get consultMyRejectedInstantMsg =>
      'टेक्निशियन तुमचा कॉल घेऊ शकला नाही. तुम्ही पुन्हा प्रयत्न करू शकता.';

  @override
  String consultMyReasonPrefix(String reason) {
    return 'कारण: $reason';
  }

  @override
  String get consultMyNoTechAvailable => 'कोणताही टेक्निशियन उपलब्ध नाही';

  @override
  String get consultMyNoTechAvailableMsg =>
      'या विनंतीसाठी कोणताही टेक्निशियन उपलब्ध नव्हता. कृपया नंतर पुन्हा प्रयत्न करा.';

  @override
  String get consultMyInCall => 'कॉलमध्ये';

  @override
  String get consultMyInCallMsg => 'कॉल सुरू आहे.';

  @override
  String get consultMyCompleted => 'पूर्ण';

  @override
  String get consultMyCompletedMsg => 'ही सल्लामसलत संपली आहे.';

  @override
  String get consultMyCancelled => 'रद्द केले';

  @override
  String get consultMyCancelledMsg => 'तुम्ही ही विनंती रद्द केली.';

  @override
  String get consultTitle => 'सल्ला';

  @override
  String get consultTabChat => 'चॅट';

  @override
  String get consultTabVideo => 'व्हिडिओ';

  @override
  String get consultTabCall => 'कॉल';

  @override
  String get consultNoCallsTitle => 'अद्याप कोणतेही कॉल नाहीत';

  @override
  String get consultNoCallsSubtitle =>
      'तुमच्या बुकिंगसाठी तंत्रज्ञ नियुक्त झाल्यावर, तुम्ही त्यांना इथून कॉल करू शकाल.';

  @override
  String get consultNoChatsTitle => 'अद्याप कोणतीही चॅट नाही';

  @override
  String get consultNoChatsSubtitle =>
      'जेव्हा तुमच्या बुकिंगसाठी तंत्रज्ञ नियुक्त होईल, तेव्हा तुम्ही येथे चॅट करू शकाल.';

  @override
  String get consultServiceBookingFallback => 'सेवा बुकिंग';

  @override
  String get consultNoVideoCallsTitle => 'अद्याप कोणताही व्हिडिओ सल्ला नाही';

  @override
  String get consultNoVideoCallsSubtitle =>
      'तंत्रज्ञांसोबतचे तुमचे लाइव्ह व्हिडिओ सल्ला येथे दिसतील.';

  @override
  String get consultStatusCompleted => 'पूर्ण';

  @override
  String get consultStatusCancelled => 'रद्द';

  @override
  String get consultStatusTechnicianUnavailable => 'तंत्रज्ञ उपलब्ध नाही';

  @override
  String get consultStatusDeclined => 'नाकारले';

  @override
  String get consultStatusNoExpertFound => 'कोणताही तज्ञ सापडला नाही';

  @override
  String get consultStatusInCall => 'कॉलमध्ये';

  @override
  String get consultStatusConfirmed => 'पुष्टी झाली';

  @override
  String get consultStatusAwaitingConfirmation => 'पुष्टीच्या प्रतीक्षेत';

  @override
  String get consultStatusUpcoming => 'आगामी';

  @override
  String get consultHelperRejectedScheduled =>
      'तंत्रज्ञ ही वेळ राखू शकला नाही. कृपया नवीन वेळ निवडा.';

  @override
  String get consultHelperRejectedInstant =>
      'तंत्रज्ञ या कॉलसाठी उपलब्ध नव्हता.';

  @override
  String get consultHelperScheduled => 'तंत्रज्ञाच्या पुष्टीची प्रतीक्षा आहे.';

  @override
  String get consultHelperConfirmed => 'तंत्रज्ञाने या वेळेची पुष्टी केली आहे.';

  @override
  String get consultHelperNoTechnician =>
      'या सल्ल्यासाठी कोणताही तंत्रज्ञ उपलब्ध नव्हता.';

  @override
  String get consultTechnicianFallback => 'तंत्रज्ञ';

  @override
  String get consultVideoConsultationFallback => 'व्हिडिओ सल्ला';

  @override
  String get consultNewRecommendation => 'तुमच्या तंत्रज्ञाकडून नवीन शिफारस';

  @override
  String get consultNewBadge => 'नवीन';

  @override
  String consultMinutesShort(String minutes) {
    return '$minutes मिनिटे';
  }

  @override
  String get profileLogoutDialogTitle => 'लॉग आउट करायचे?';

  @override
  String get profileLogoutDialogContent =>
      'तुम्हाला खरोखर तुमच्या खात्यातून लॉग आउट करायचे आहे का?';

  @override
  String get profileLogoutConfirm => 'लॉग आउट';

  @override
  String get profileDeleteDialogTitle => 'खाते हटवायचे?';

  @override
  String get profileDeleteDialogContent =>
      'यामुळे तुमचे खाते आणि संबंधित सर्व डेटा कायमचा हटवला जाईल. ही क्रिया पूर्ववत केली जाऊ शकत नाही.';

  @override
  String get profileDeleteConfirm => 'हटवा';

  @override
  String get profileLogInButton => 'लॉग इन करा';

  @override
  String get profileTechnicianDefaultName => 'तंत्रज्ञ';

  @override
  String get profileRegistrationIncompleteMsg =>
      'तुमची तंत्रज्ञ नोंदणी अपूर्ण आहे. काम मिळवण्यासाठी ती पूर्ण करा.';

  @override
  String get profileCompleteRegistration => 'नोंदणी पूर्ण करा';

  @override
  String get profileLogOutButton => 'लॉग आउट';

  @override
  String get profileNoRatingsYet => 'अद्याप कोणतेही रेटिंग नाही';

  @override
  String get profileOnlineStatus => 'ऑनलाइन';

  @override
  String get profileOfflineStatus => 'ऑफलाइन';

  @override
  String get profileCanBookNow => 'ग्राहक आता तुम्हाला बुक करू शकतात';

  @override
  String get profileNoNewRequests => 'तुम्हाला नवीन विनंत्या मिळणार नाहीत';

  @override
  String get profileNeedKycApproval => 'ऑनलाइन जाण्यासाठी KYC मंजुरी पूर्ण करा';

  @override
  String get profileSectionProfessionalDetails => 'व्यावसायिक तपशील';

  @override
  String get profilePrimaryService => 'प्राथमिक सेवा';

  @override
  String get profileYearsExperienceLabel => 'अनुभवाची वर्षे';

  @override
  String get profileAddressLabel => 'पत्ता';

  @override
  String get profileServiceRadius => 'सेवा त्रिज्या';

  @override
  String get profileSectionTrustVerification => 'विश्वास आणि पडताळणी';

  @override
  String get profilePhoneVerified => 'फोन पडताळला';

  @override
  String get profileProfileVerified => 'प्रोफाइल पडताळले';

  @override
  String get profileGovIdUploaded => 'सरकारी ओळखपत्र अपलोड केले';

  @override
  String get profileSectionDocuments => 'कागदपत्रे';

  @override
  String get profileGovId => 'सरकारी ओळखपत्र';

  @override
  String get profileBankUpiDetails => 'बँक / UPI तपशील';

  @override
  String get profileSectionWork => 'काम';

  @override
  String get profileLiveConsultationRequestsLabel => 'थेट सल्ला विनंत्या';

  @override
  String get profileNotificationSettings => 'सूचना सेटिंग्ज';

  @override
  String get profilePaymentSettings => 'पेमेंट सेटिंग्ज';

  @override
  String get profilePrivacySecurity => 'गोपनीयता आणि सुरक्षा';

  @override
  String get profileChangePasswordPin => 'पासवर्ड / पिन बदला';

  @override
  String get profileVerifiedStatus => 'पडताळले';

  @override
  String get profilePendingStatus => 'प्रलंबित';

  @override
  String get profileApprovalApproved => 'मंजूर';

  @override
  String get profileApprovalRejected => 'नाकारले';

  @override
  String get profileApprovalPending => 'मंजुरी प्रलंबित';

  @override
  String get profileComingSoonMessage =>
      'हे वैशिष्ट्य लवकरच येत आहे. आम्ही ते तुमच्यापर्यंत आणण्यासाठी काम करत आहोत.';

  @override
  String get profileGoBackButton => 'मागे जा';

  @override
  String profileYearsValue(String years) {
    return '$years वर्षे';
  }

  @override
  String profileRejectionReason(String reason) {
    return 'कारण: $reason';
  }
}
