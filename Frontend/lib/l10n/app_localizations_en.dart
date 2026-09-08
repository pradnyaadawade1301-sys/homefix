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

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to book trusted home services';

  @override
  String get loginIdentifierHint => 'Email or phone number';

  @override
  String get loginIdentifierRequired => 'Email or phone number required';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginPasswordRequired => 'Password is required';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginForgotPasswordComingSoon =>
      'Forgot password flow coming soon';

  @override
  String get loginSignIn => 'Sign In';

  @override
  String get loginOr => 'OR';

  @override
  String get loginContinueWithGoogle => 'Continue with Google';

  @override
  String loginGoogleSignInFailed(String error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get loginTrustedBanner => 'Trusted by thousands of users';

  @override
  String get loginTrustedSubtitle =>
      'Verified professionals • Secure bookings • 24/7 Support';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get loginSignUp => 'Sign Up';

  @override
  String get signupPasswordRequiredValidator => 'Password is required';

  @override
  String get signupPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get signupPasswordNeedsLetterSpecial =>
      'Add a letter and a special character (not just numbers)';

  @override
  String get signupCreateYourAccount => 'Create your account';

  @override
  String get signupJoinSubtitle =>
      'Join HomeFix Live as a customer or technician';

  @override
  String get signupIAmA => 'I am a';

  @override
  String get signupRoleCustomer => 'Customer';

  @override
  String get signupRoleTechnician => 'Technician';

  @override
  String get signupNameHint => 'Full name';

  @override
  String get signupNameRequired => 'Name is required';

  @override
  String get signupEmailHint => 'Email address';

  @override
  String get signupEmailRequired => 'Email is required';

  @override
  String get signupEmailInvalid => 'Enter a valid email';

  @override
  String get signupPhoneHint => 'Phone number';

  @override
  String get signupPhoneRequired => 'Phone number is required';

  @override
  String get signupPhoneInvalid => 'Enter a valid phone number';

  @override
  String get signupPasswordHint => 'Password';

  @override
  String get signupPasswordHelper =>
      'Min 8 chars, with a letter and a special character';

  @override
  String get signupDataSafeBanner => 'Your data is safe with us';

  @override
  String get signupDataSafeSubtitle => 'We never share your information';

  @override
  String get signupCreateAccount => 'Create Account';

  @override
  String get signupHaveAccount => 'Already have an account? ';

  @override
  String get signupSignIn => 'Sign In';

  @override
  String get bookingsTitle => 'My Bookings';

  @override
  String get bookingsCancelDialogTitle => 'Cancel this booking?';

  @override
  String get bookingsCancelDialogBody =>
      'This will cancel your booking and notify the technician, if one has been assigned.';

  @override
  String get bookingsCancelReasonLabel => 'Reason (optional)';

  @override
  String get bookingsKeepBooking => 'Keep Booking';

  @override
  String get bookingsYesCancel => 'Yes, Cancel';

  @override
  String get bookingsCancelledMsg => 'Booking cancelled';

  @override
  String get bookingsCouldNotCancel => 'Could not cancel booking';

  @override
  String get bookingsStatusFinding => 'Finding technician';

  @override
  String get bookingsStatusWaiting => 'Waiting for technician';

  @override
  String get bookingsStatusAssigned => 'Technician assigned';

  @override
  String get bookingsStatusInProgress => 'In progress';

  @override
  String get bookingsStatusCompleted => 'Completed';

  @override
  String get bookingsStatusCancelled => 'Cancelled';

  @override
  String get bookingsEmptyTitle => 'No bookings yet';

  @override
  String get bookingsEmptySubtitle =>
      'Book a service from the Home tab to see it here';

  @override
  String get bookingsServiceBookingFallback => 'Service booking';

  @override
  String bookingsBookedOn(String date) {
    return 'Booked $date';
  }

  @override
  String get bookingsTechnicianFallback => 'Technician';

  @override
  String get bookingsChatTooltip => 'Chat';

  @override
  String get homePressBackExit => 'Press back again to exit';

  @override
  String homeGreetingShort(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeSetLocationShort => 'Set your location';

  @override
  String get homeSearchServiceHint => 'Search service...';

  @override
  String get homeMostBookedServices => 'Most Booked Services';

  @override
  String get homeMyTechniciansShort => 'My Technicians';

  @override
  String homeCouldNotLoadRepeatTechnicians(String error) {
    return 'Could not load repeat technicians: $error';
  }

  @override
  String get homeTopPicksForYou => 'Top Picks for you';

  @override
  String get homeViewAllShort => 'View all';

  @override
  String get homeCouldNotLoadServices => 'Could not load services';

  @override
  String get homeNoServicesYet => 'No services available yet';

  @override
  String get homeCouldNotLoadTechnicians => 'Could not load technicians';

  @override
  String get homeNoVerifiedTechnicians =>
      'No verified technicians yet — check back soon';

  @override
  String get homeTechnicianFallback => 'Technician';

  @override
  String homeYearsExp(String years) {
    return '$years yrs exp';
  }

  @override
  String get homeBannerHeading1 => 'Professional\nHelp for\n';

  @override
  String get homeBannerHeading2 => 'Your Home';

  @override
  String get homeTrustedExperts => 'Trusted\nExperts';

  @override
  String get homeOnTimeService => 'On-Time\nService';

  @override
  String get homeQualityGuaranteed => 'Quality\nGuaranteed';

  @override
  String get guidedTourWelcomeTitle => 'Welcome to HomeFix!';

  @override
  String get guidedTourWelcomeDesc =>
      'Start your home service right here — electrician, plumber, AC repair, and much more.';

  @override
  String get guidedTourBookingsTitle => 'Bookings';

  @override
  String get guidedTourBookingsDesc =>
      'Track your upcoming and past bookings here.';

  @override
  String get guidedTourAiTitle => 'AI Assessment';

  @override
  String get guidedTourAiDesc =>
      'Describe your problem and get an instant AI-powered quick assessment — before the technician even arrives.';

  @override
  String get guidedTourConsultTitle => 'Consult';

  @override
  String get guidedTourConsultDesc =>
      'Chat with a technician or hop on a live video call to show them your problem instantly.';

  @override
  String get guidedTourProfileTitle => 'Profile';

  @override
  String get guidedTourProfileDesc =>
      'Manage your account, addresses, payments, and settings here.';

  @override
  String get aiDiagnosisTitle => 'AI Diagnosis';

  @override
  String get aiDiagnosisFoundTitle => 'Here\'s what we found';

  @override
  String get aiDiagnosisWhatIssueIs => 'What the issue is';

  @override
  String get aiDiagnosisQuickQuestions => 'A couple of quick questions';

  @override
  String get aiDiagnosisFixableRemotely => 'This may be fixable remotely';

  @override
  String get aiDiagnosisRecommendOnsite =>
      'Recommended: onsite technician visit';

  @override
  String get aiDiagnosisPossibleOptions => 'Possible Options';

  @override
  String get aiDiagnosisInstantGuidanceTitle => 'Get Instant AI Guidance';

  @override
  String get aiDiagnosisInstantGuidanceSubtitle =>
      'Keep chatting with AI to try fixing it yourself';

  @override
  String get aiDiagnosisBookDirectTitle => 'Book Technician Directly';

  @override
  String get aiDiagnosisBookDirectSubtitle =>
      'Schedule a visit at a time that works for you';

  @override
  String get aiDiagnosisFlexibilityNote =>
      'This gives you the flexibility to choose what works best.';

  @override
  String get aiDiagnosisSuggestedTechnicians => 'Suggested technicians';

  @override
  String get aiDiagnosisViewAll => 'View all';

  @override
  String get aiDiagnosisBookDirectlyBtn => 'Book Directly';

  @override
  String get aiDiagnosisAskFollowUp => 'Ask a follow-up question...';

  @override
  String aiDiagnosisUnavailable(String error) {
    return 'AI diagnosis is unavailable right now.\n$error';
  }

  @override
  String get aiDiagnosisStillBookDirectly =>
      'You can still book a technician directly.';

  @override
  String get aiDiagnosisBookTechnicianVisit => 'Book Technician Visit';

  @override
  String get aiDiagnosisTechnicianFallback => 'Technician';

  @override
  String aiDiagnosisYearsExp(String years) {
    return '$years yrs exp';
  }

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatEmptyState => 'No messages yet. Say hello!';

  @override
  String chatMessageHint(String peerName) {
    return 'Message $peerName';
  }
}
