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

  @override
  String get techJobsLogoutTitle => 'Log out?';

  @override
  String get techJobsLogoutContent =>
      'You will need to sign in again to see your jobs.';

  @override
  String get techJobsCancel => 'Cancel';

  @override
  String get techJobsLogout => 'Log out';

  @override
  String get techJobsNavTitleJobs => 'My Jobs';

  @override
  String get techJobsNavTitleConsultations => 'Consultations';

  @override
  String get techJobsNavTitleSettlement => 'Settlement';

  @override
  String get techJobsNavTitleHistory => 'History';

  @override
  String get techJobsMyCustomersTooltip => 'My Customers';

  @override
  String get techJobsLogoutTooltip => 'Log out';

  @override
  String get techJobsBottomNavJobs => 'Jobs';

  @override
  String get techJobsBottomNavUpcoming => 'Upcoming';

  @override
  String get techJobsBottomNavSettlement => 'Settlement';

  @override
  String get techJobsBottomNavHistory => 'History';

  @override
  String get techJobsWelcomeBack => 'Welcome back 👋';

  @override
  String get techJobsWorkOverview => 'Here\'s your work overview';

  @override
  String get techJobsActive => 'Active';

  @override
  String get techJobsCompleted => 'Completed';

  @override
  String get techJobsFilterAll => 'All';

  @override
  String techJobsCouldNotLoad(String error) {
    return 'Couldn\'t load your jobs: $error';
  }

  @override
  String get techJobsRetry => 'Retry';

  @override
  String get techJobsNoActiveJobs => 'No active jobs right now';

  @override
  String get techJobsNoJobsYet => 'No jobs yet';

  @override
  String get techJobsNewRequestsHint =>
      'New customer requests will show up here';

  @override
  String get techJobsLiveConsultationRequest => '1 live consultation request';

  @override
  String techJobsLiveConsultationRequests(String count) {
    return '$count live consultation requests';
  }

  @override
  String get techJobsTapAcceptReject => 'Tap to accept or reject';

  @override
  String get techJobsScheduledConsultation => '1 scheduled consultation';

  @override
  String techJobsScheduledConsultations(String count) {
    return '$count scheduled consultations';
  }

  @override
  String get techJobsTapConfirmDecline => 'Tap to confirm or decline slots';

  @override
  String get techJobsServiceRequestFallback => 'Service request';

  @override
  String get techJobsCustomerFallback => 'Customer';

  @override
  String get techJobsChatTooltip => 'Chat with customer';

  @override
  String get techJobsDecline => 'Decline';

  @override
  String get techJobsAcceptJob => 'Accept job';

  @override
  String get techJobsOnMyWay => 'I\'m on my way';

  @override
  String get techJobsArrived => 'I\'ve arrived';

  @override
  String get techJobsGenerateInvoiceComplete => 'Generate invoice & complete';

  @override
  String get techJobsDeclineTitle => 'Decline this job?';

  @override
  String get techJobsDeclineContent =>
      'We\'ll find another technician for this booking. This can\'t be undone.';

  @override
  String get techJobsGenerateInvoiceTitle => 'Generate invoice';

  @override
  String get techJobsInvoiceHint =>
      'Enter the final amount the customer should pay. This is sent to them immediately as the amount due.';

  @override
  String get techJobsFinalAmount => 'Final amount';

  @override
  String get techJobsOfferWarranty => 'Offer a warranty';

  @override
  String get techJobsWarrantySubtitle =>
      'Customer can raise a free revisit within this window';

  @override
  String get techJobsDuration => 'Duration';

  @override
  String get techJobsDurationHint => 'e.g. 6';

  @override
  String get techJobsWarrantyCoverageLabel => 'What does this warranty cover?';

  @override
  String get techJobsWarrantyCoverageHint =>
      'e.g. Compressor and gas refill only';

  @override
  String get techJobsDays => 'Days';

  @override
  String get techJobsMonths => 'Months';

  @override
  String get techJobsYears => 'Years';

  @override
  String get techJobsEnterValidAmount => 'Enter a valid amount';

  @override
  String get techJobsEnterValidWarranty => 'Enter a valid warranty duration';

  @override
  String get techJobsSendInvoice => 'Send invoice';

  @override
  String get techJobsAskOtp =>
      'Ask the customer for their OTP to start the service';

  @override
  String get techJobsEnterOtp => 'Enter the 4-digit OTP';

  @override
  String get techJobsIncorrectOtp => 'Incorrect OTP, try again';

  @override
  String get techJobsVerify => 'Verify';

  @override
  String get techSettlementVisitHistory => 'Visit History';

  @override
  String get techSettlementPaymentHistory => 'Payment History';

  @override
  String get techSettlementNoCompletedVisits => 'No completed visits yet';

  @override
  String get techSettlementNoPayments => 'No payments yet';

  @override
  String get techSettlementTotalEarned => 'Total Earned';

  @override
  String get techSettlementJobsCompleted => 'Jobs Completed';

  @override
  String techSettlementYourShare(String amount) {
    return 'Your share: ₹$amount';
  }

  @override
  String get techSettlementCustomerFallback => 'Customer';

  @override
  String get consultUpcomingSlotConfirmed => 'Slot confirmed';

  @override
  String consultUpcomingCouldNotConfirm(String error) {
    return 'Could not confirm: $error';
  }

  @override
  String get consultUpcomingDeclineTitle => 'Decline this slot?';

  @override
  String consultUpcomingDeclineContent(String slot) {
    return 'The customer will be notified that you can\'t make $slot and asked to pick another time.';
  }

  @override
  String get consultUpcomingReasonOptional => 'Reason (optional)';

  @override
  String get consultUpcomingReasonHint => 'e.g. Not available at that time';

  @override
  String get consultUpcomingCancel => 'Cancel';

  @override
  String get consultUpcomingDecline => 'Decline';

  @override
  String get consultUpcomingSlotDeclined => 'Slot declined';

  @override
  String consultUpcomingCouldNotDecline(String error) {
    return 'Could not decline: $error';
  }

  @override
  String get consultUpcomingThisSlot => 'this slot';

  @override
  String get consultUpcomingNoUpcoming => 'No upcoming consultations';

  @override
  String get consultUpcomingScheduledHint =>
      'Scheduled requests from customers will show up here';

  @override
  String get consultUpcomingTitle => 'Upcoming Consultations';

  @override
  String get consultUpcomingFallback => 'Consultation';

  @override
  String get consultUpcomingNeedsConfirmation => 'Needs confirmation';

  @override
  String get consultUpcomingConfirmedLabel => 'Confirmed';

  @override
  String get consultUpcomingCustomerFallback => 'Customer';

  @override
  String get consultUpcomingConfirm => 'Confirm';

  @override
  String get consultUpcomingWaitingSlot =>
      'Waiting for slot time — you\'ll be notified when it starts';

  @override
  String get consultMyTitle => 'My Consultations';

  @override
  String get consultMyNoneYet => 'No consultations yet';

  @override
  String get consultMyFallback => 'Consultation';

  @override
  String consultMyWith(String name) {
    return 'with $name';
  }

  @override
  String get consultMyRequestAgain => 'Request again';

  @override
  String get consultMyAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get consultMyAwaitingConfirmationMsg =>
      'Waiting for the technician to confirm your requested slot.';

  @override
  String get consultMyConfirmed => 'Confirmed';

  @override
  String get consultMyConfirmedMsg =>
      'Your technician confirmed. The call will start automatically at your scheduled time.';

  @override
  String get consultMySearching => 'Searching';

  @override
  String get consultMySearchingMsg => 'Looking for an available technician...';

  @override
  String get consultMyRinging => 'Ringing';

  @override
  String get consultMyRingingMsg => 'Ringing the technician now...';

  @override
  String get consultMyAccepted => 'Accepted';

  @override
  String get consultMyAcceptedMsg =>
      'Technician accepted — connecting your call.';

  @override
  String get consultMyTechUnavailable => 'Technician unavailable';

  @override
  String get consultMyNotAnswered => 'Not answered';

  @override
  String get consultMyRejectedScheduledMsg =>
      'The technician was busy and couldn\'t make this slot. Please request a new time.';

  @override
  String get consultMyRejectedInstantMsg =>
      'The technician couldn\'t take your call. You can try again.';

  @override
  String consultMyReasonPrefix(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get consultMyNoTechAvailable => 'No technician available';

  @override
  String get consultMyNoTechAvailableMsg =>
      'No technician was available for this request. Please try again later.';

  @override
  String get consultMyInCall => 'In call';

  @override
  String get consultMyInCallMsg => 'Call in progress.';

  @override
  String get consultMyCompleted => 'Completed';

  @override
  String get consultMyCompletedMsg => 'This consultation has ended.';

  @override
  String get consultMyCancelled => 'Cancelled';

  @override
  String get consultMyCancelledMsg => 'You cancelled this request.';

  @override
  String get consultTitle => 'Consult';

  @override
  String get consultTabChat => 'Chat';

  @override
  String get consultTabVideo => 'Video';

  @override
  String get consultTabCall => 'Call';

  @override
  String get consultNoCallsTitle => 'No calls yet';

  @override
  String get consultNoCallsSubtitle =>
      'Once a technician is assigned to your booking, you\'ll be able to call them here.';

  @override
  String get consultNoChatsTitle => 'No chats yet';

  @override
  String get consultNoChatsSubtitle =>
      'Once a technician is assigned to your booking, you\'ll be able to chat with them here.';

  @override
  String get consultServiceBookingFallback => 'Service booking';

  @override
  String get consultNoVideoCallsTitle => 'No video consultations yet';

  @override
  String get consultNoVideoCallsSubtitle =>
      'Your live video consultations with technicians will show up here.';

  @override
  String get consultStatusCompleted => 'Completed';

  @override
  String get consultStatusCancelled => 'Cancelled';

  @override
  String get consultStatusTechnicianUnavailable => 'Technician unavailable';

  @override
  String get consultStatusDeclined => 'Declined';

  @override
  String get consultStatusNoExpertFound => 'No expert found';

  @override
  String get consultStatusInCall => 'In call';

  @override
  String get consultStatusConfirmed => 'Confirmed';

  @override
  String get consultStatusAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get consultStatusUpcoming => 'Upcoming';

  @override
  String get consultHelperRejectedScheduled =>
      'The technician couldn\'t hold this slot. Please schedule a new time.';

  @override
  String get consultHelperRejectedInstant =>
      'The technician was unavailable to take this call.';

  @override
  String get consultHelperScheduled =>
      'Waiting for the technician to confirm this slot.';

  @override
  String get consultHelperConfirmed =>
      'The technician has confirmed this slot.';

  @override
  String get consultHelperNoTechnician =>
      'No technician was available for this consultation.';

  @override
  String get consultTechnicianFallback => 'Technician';

  @override
  String get consultVideoConsultationFallback => 'Video consultation';

  @override
  String get consultNewRecommendation =>
      'New recommendation from your technician';

  @override
  String get consultNewBadge => 'NEW';

  @override
  String consultMinutesShort(String minutes) {
    return '$minutes min';
  }

  @override
  String get profileLogoutDialogTitle => 'Log out?';

  @override
  String get profileLogoutDialogContent =>
      'Are you sure you want to log out of your account?';

  @override
  String get profileLogoutConfirm => 'Log Out';

  @override
  String get profileDeleteDialogTitle => 'Delete account?';

  @override
  String get profileDeleteDialogContent =>
      'This will permanently delete your account and all associated data. This action cannot be undone.';

  @override
  String get profileDeleteConfirm => 'Delete';

  @override
  String get profileLogInButton => 'Log In';

  @override
  String get profileTechnicianDefaultName => 'Technician';

  @override
  String get profileRegistrationIncompleteMsg =>
      'Your technician registration is incomplete. Complete it to start receiving jobs.';

  @override
  String get profileCompleteRegistration => 'Complete Registration';

  @override
  String get profileLogOutButton => 'Log Out';

  @override
  String get profileNoRatingsYet => 'No ratings yet';

  @override
  String get profileOnlineStatus => 'Online';

  @override
  String get profileOfflineStatus => 'Offline';

  @override
  String get profileCanBookNow => 'Customers can book you now';

  @override
  String get profileNoNewRequests => 'You won\'t receive new requests';

  @override
  String get profileNeedKycApproval => 'Complete KYC approval to go online';

  @override
  String get profileSectionProfessionalDetails => 'Professional Details';

  @override
  String get profilePrimaryService => 'Primary Service';

  @override
  String get profileYearsExperienceLabel => 'Years of Experience';

  @override
  String get profileAddressLabel => 'Address';

  @override
  String get profileServiceRadius => 'Service Radius';

  @override
  String get profileSectionTrustVerification => 'Trust & Verification';

  @override
  String get profilePhoneVerified => 'Phone Verified';

  @override
  String get profileProfileVerified => 'Profile Verified';

  @override
  String get profileGovIdUploaded => 'Government ID Uploaded';

  @override
  String get profileSectionDocuments => 'Documents';

  @override
  String get profileGovId => 'Government ID';

  @override
  String get profileBankUpiDetails => 'Bank / UPI Details';

  @override
  String get profileSectionWork => 'Work';

  @override
  String get profileLiveConsultationRequestsLabel =>
      'Live Consultation Requests';

  @override
  String get profileNotificationSettings => 'Notification Settings';

  @override
  String get profilePaymentSettings => 'Payment Settings';

  @override
  String get profilePrivacySecurity => 'Privacy & Security';

  @override
  String get profileChangePasswordPin => 'Change Password / PIN';

  @override
  String get profileVerifiedStatus => 'Verified';

  @override
  String get profilePendingStatus => 'Pending';

  @override
  String get profileApprovalApproved => 'Approved';

  @override
  String get profileApprovalRejected => 'Rejected';

  @override
  String get profileApprovalPending => 'Pending Approval';

  @override
  String get profileComingSoonMessage =>
      'This feature is coming soon. We\'re working hard to bring it to you.';

  @override
  String get profileGoBackButton => 'Go Back';

  @override
  String profileYearsValue(String years) {
    return '$years years';
  }

  @override
  String profileRejectionReason(String reason) {
    return 'Reason: $reason';
  }
}
