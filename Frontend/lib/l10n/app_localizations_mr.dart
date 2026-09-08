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
}
