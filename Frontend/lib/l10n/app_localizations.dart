import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr')
  ];

  /// App name shown on splash/login.
  ///
  /// In en, this message translates to:
  /// **'HomeFix'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get navBooking;

  /// No description provided for @navAI.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAI;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// Greeting on the home screen header.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeDetectingLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting location...'**
  String get homeDetectingLocation;

  /// No description provided for @homeSetLocation.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get homeSetLocation;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search service...'**
  String get homeSearchHint;

  /// No description provided for @homeMostBooked.
  ///
  /// In en, this message translates to:
  /// **'Most Booked Services'**
  String get homeMostBooked;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeMyTechnicians.
  ///
  /// In en, this message translates to:
  /// **'My Technicians'**
  String get homeMyTechnicians;

  /// No description provided for @homeTopPicks.
  ///
  /// In en, this message translates to:
  /// **'Top Picks for you'**
  String get homeTopPicks;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get profileSectionAppSettings;

  /// No description provided for @profileSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSectionSupport;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInfo;

  /// No description provided for @profileSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get profileSavedAddresses;

  /// No description provided for @profileServiceHistory.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get profileServiceHistory;

  /// No description provided for @profileBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get profileBookings;

  /// No description provided for @profilePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get profilePaymentMethods;

  /// No description provided for @profileTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get profileTransactionHistory;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileReplayTour.
  ///
  /// In en, this message translates to:
  /// **'Replay Guided Tour'**
  String get profileReplayTour;

  /// No description provided for @profileHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profileHelpCenter;

  /// No description provided for @profileContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get profileContactSupport;

  /// No description provided for @profileTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get profileTerms;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogout;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileTechnicianRole.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get profileTechnicianRole;

  /// No description provided for @profileCustomerRole.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get profileCustomerRole;

  /// No description provided for @languageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageSheetTitle;

  /// No description provided for @languageSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app will switch to this language everywhere'**
  String get languageSheetSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी (Hindi)'**
  String get languageHindi;

  /// No description provided for @languageMarathi.
  ///
  /// In en, this message translates to:
  /// **'मराठी (Marathi)'**
  String get languageMarathi;

  /// No description provided for @languageChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get languageChangedMessage;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book trusted home services'**
  String get loginSubtitle;

  /// No description provided for @loginIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number'**
  String get loginIdentifierHint;

  /// No description provided for @loginIdentifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number required'**
  String get loginIdentifierRequired;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get loginPasswordRequired;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Forgot password flow coming soon'**
  String get loginForgotPasswordComingSoon;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get loginOr;

  /// No description provided for @loginContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginContinueWithGoogle;

  /// Error shown when Google sign-in fails.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String loginGoogleSignInFailed(String error);

  /// No description provided for @loginTrustedBanner.
  ///
  /// In en, this message translates to:
  /// **'Trusted by thousands of users'**
  String get loginTrustedBanner;

  /// No description provided for @loginTrustedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified professionals • Secure bookings • 24/7 Support'**
  String get loginTrustedSubtitle;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginNoAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get loginSignUp;

  /// No description provided for @signupPasswordRequiredValidator.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get signupPasswordRequiredValidator;

  /// No description provided for @signupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get signupPasswordTooShort;

  /// No description provided for @signupPasswordNeedsLetterSpecial.
  ///
  /// In en, this message translates to:
  /// **'Add a letter and a special character (not just numbers)'**
  String get signupPasswordNeedsLetterSpecial;

  /// No description provided for @signupCreateYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signupCreateYourAccount;

  /// No description provided for @signupJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join HomeFix Live as a customer or technician'**
  String get signupJoinSubtitle;

  /// No description provided for @signupIAmA.
  ///
  /// In en, this message translates to:
  /// **'I am a'**
  String get signupIAmA;

  /// No description provided for @signupRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get signupRoleCustomer;

  /// No description provided for @signupRoleTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get signupRoleTechnician;

  /// No description provided for @signupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get signupNameHint;

  /// No description provided for @signupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get signupNameRequired;

  /// No description provided for @signupEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signupEmailHint;

  /// No description provided for @signupEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get signupEmailRequired;

  /// No description provided for @signupEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get signupEmailInvalid;

  /// No description provided for @signupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get signupPhoneHint;

  /// No description provided for @signupPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get signupPhoneRequired;

  /// No description provided for @signupPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get signupPhoneInvalid;

  /// No description provided for @signupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signupPasswordHint;

  /// No description provided for @signupPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Min 8 chars, with a letter and a special character'**
  String get signupPasswordHelper;

  /// No description provided for @signupDataSafeBanner.
  ///
  /// In en, this message translates to:
  /// **'Your data is safe with us'**
  String get signupDataSafeBanner;

  /// No description provided for @signupDataSafeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We never share your information'**
  String get signupDataSafeSubtitle;

  /// No description provided for @signupCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupCreateAccount;

  /// No description provided for @signupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get signupHaveAccount;

  /// No description provided for @signupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signupSignIn;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get bookingsTitle;

  /// No description provided for @bookingsCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get bookingsCancelDialogTitle;

  /// No description provided for @bookingsCancelDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will cancel your booking and notify the technician, if one has been assigned.'**
  String get bookingsCancelDialogBody;

  /// No description provided for @bookingsCancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get bookingsCancelReasonLabel;

  /// No description provided for @bookingsKeepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep Booking'**
  String get bookingsKeepBooking;

  /// No description provided for @bookingsYesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get bookingsYesCancel;

  /// No description provided for @bookingsCancelledMsg.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get bookingsCancelledMsg;

  /// No description provided for @bookingsCouldNotCancel.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel booking'**
  String get bookingsCouldNotCancel;

  /// No description provided for @bookingsStatusFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding technician'**
  String get bookingsStatusFinding;

  /// No description provided for @bookingsStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for technician'**
  String get bookingsStatusWaiting;

  /// No description provided for @bookingsStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Technician assigned'**
  String get bookingsStatusAssigned;

  /// No description provided for @bookingsStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get bookingsStatusInProgress;

  /// No description provided for @bookingsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingsStatusCompleted;

  /// No description provided for @bookingsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingsStatusCancelled;

  /// No description provided for @bookingsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get bookingsEmptyTitle;

  /// No description provided for @bookingsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book a service from the Home tab to see it here'**
  String get bookingsEmptySubtitle;

  /// No description provided for @bookingsServiceBookingFallback.
  ///
  /// In en, this message translates to:
  /// **'Service booking'**
  String get bookingsServiceBookingFallback;

  /// Fallback date label when no scheduled date is set.
  ///
  /// In en, this message translates to:
  /// **'Booked {date}'**
  String bookingsBookedOn(String date);

  /// No description provided for @bookingsTechnicianFallback.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get bookingsTechnicianFallback;

  /// No description provided for @bookingsChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get bookingsChatTooltip;

  /// No description provided for @homePressBackExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get homePressBackExit;

  /// Header greeting on home screen.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreetingShort(String name);

  /// No description provided for @homeSetLocationShort.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get homeSetLocationShort;

  /// No description provided for @homeSearchServiceHint.
  ///
  /// In en, this message translates to:
  /// **'Search service...'**
  String get homeSearchServiceHint;

  /// No description provided for @homeMostBookedServices.
  ///
  /// In en, this message translates to:
  /// **'Most Booked Services'**
  String get homeMostBookedServices;

  /// No description provided for @homeMyTechniciansShort.
  ///
  /// In en, this message translates to:
  /// **'My Technicians'**
  String get homeMyTechniciansShort;

  /// Error loading repeat technicians.
  ///
  /// In en, this message translates to:
  /// **'Could not load repeat technicians: {error}'**
  String homeCouldNotLoadRepeatTechnicians(String error);

  /// No description provided for @homeTopPicksForYou.
  ///
  /// In en, this message translates to:
  /// **'Top Picks for you'**
  String get homeTopPicksForYou;

  /// No description provided for @homeViewAllShort.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAllShort;

  /// No description provided for @homeCouldNotLoadServices.
  ///
  /// In en, this message translates to:
  /// **'Could not load services'**
  String get homeCouldNotLoadServices;

  /// No description provided for @homeNoServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services available yet'**
  String get homeNoServicesYet;

  /// No description provided for @homeCouldNotLoadTechnicians.
  ///
  /// In en, this message translates to:
  /// **'Could not load technicians'**
  String get homeCouldNotLoadTechnicians;

  /// No description provided for @homeNoVerifiedTechnicians.
  ///
  /// In en, this message translates to:
  /// **'No verified technicians yet — check back soon'**
  String get homeNoVerifiedTechnicians;

  /// No description provided for @homeTechnicianFallback.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get homeTechnicianFallback;

  /// Years of experience label.
  ///
  /// In en, this message translates to:
  /// **'{years} yrs exp'**
  String homeYearsExp(String years);

  /// No description provided for @homeBannerHeading1.
  ///
  /// In en, this message translates to:
  /// **'Professional\nHelp for\n'**
  String get homeBannerHeading1;

  /// No description provided for @homeBannerHeading2.
  ///
  /// In en, this message translates to:
  /// **'Your Home'**
  String get homeBannerHeading2;

  /// No description provided for @homeTrustedExperts.
  ///
  /// In en, this message translates to:
  /// **'Trusted\nExperts'**
  String get homeTrustedExperts;

  /// No description provided for @homeOnTimeService.
  ///
  /// In en, this message translates to:
  /// **'On-Time\nService'**
  String get homeOnTimeService;

  /// No description provided for @homeQualityGuaranteed.
  ///
  /// In en, this message translates to:
  /// **'Quality\nGuaranteed'**
  String get homeQualityGuaranteed;

  /// No description provided for @guidedTourWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to HomeFix!'**
  String get guidedTourWelcomeTitle;

  /// No description provided for @guidedTourWelcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Start your home service right here — electrician, plumber, AC repair, and much more.'**
  String get guidedTourWelcomeDesc;

  /// No description provided for @guidedTourBookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get guidedTourBookingsTitle;

  /// No description provided for @guidedTourBookingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your upcoming and past bookings here.'**
  String get guidedTourBookingsDesc;

  /// No description provided for @guidedTourAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assessment'**
  String get guidedTourAiTitle;

  /// No description provided for @guidedTourAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe your problem and get an instant AI-powered quick assessment — before the technician even arrives.'**
  String get guidedTourAiDesc;

  /// No description provided for @guidedTourConsultTitle.
  ///
  /// In en, this message translates to:
  /// **'Consult'**
  String get guidedTourConsultTitle;

  /// No description provided for @guidedTourConsultDesc.
  ///
  /// In en, this message translates to:
  /// **'Chat with a technician or hop on a live video call to show them your problem instantly.'**
  String get guidedTourConsultDesc;

  /// No description provided for @guidedTourProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get guidedTourProfileTitle;

  /// No description provided for @guidedTourProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, addresses, payments, and settings here.'**
  String get guidedTourProfileDesc;

  /// No description provided for @aiDiagnosisTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Diagnosis'**
  String get aiDiagnosisTitle;

  /// No description provided for @aiDiagnosisFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what we found'**
  String get aiDiagnosisFoundTitle;

  /// No description provided for @aiDiagnosisWhatIssueIs.
  ///
  /// In en, this message translates to:
  /// **'What the issue is'**
  String get aiDiagnosisWhatIssueIs;

  /// No description provided for @aiDiagnosisQuickQuestions.
  ///
  /// In en, this message translates to:
  /// **'A couple of quick questions'**
  String get aiDiagnosisQuickQuestions;

  /// No description provided for @aiDiagnosisFixableRemotely.
  ///
  /// In en, this message translates to:
  /// **'This may be fixable remotely'**
  String get aiDiagnosisFixableRemotely;

  /// No description provided for @aiDiagnosisRecommendOnsite.
  ///
  /// In en, this message translates to:
  /// **'Recommended: onsite technician visit'**
  String get aiDiagnosisRecommendOnsite;

  /// No description provided for @aiDiagnosisPossibleOptions.
  ///
  /// In en, this message translates to:
  /// **'Possible Options'**
  String get aiDiagnosisPossibleOptions;

  /// No description provided for @aiDiagnosisInstantGuidanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Instant AI Guidance'**
  String get aiDiagnosisInstantGuidanceTitle;

  /// No description provided for @aiDiagnosisInstantGuidanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep chatting with AI to try fixing it yourself'**
  String get aiDiagnosisInstantGuidanceSubtitle;

  /// No description provided for @aiDiagnosisBookDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Technician Directly'**
  String get aiDiagnosisBookDirectTitle;

  /// No description provided for @aiDiagnosisBookDirectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a visit at a time that works for you'**
  String get aiDiagnosisBookDirectSubtitle;

  /// No description provided for @aiDiagnosisFlexibilityNote.
  ///
  /// In en, this message translates to:
  /// **'This gives you the flexibility to choose what works best.'**
  String get aiDiagnosisFlexibilityNote;

  /// No description provided for @aiDiagnosisSuggestedTechnicians.
  ///
  /// In en, this message translates to:
  /// **'Suggested technicians'**
  String get aiDiagnosisSuggestedTechnicians;

  /// No description provided for @aiDiagnosisViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get aiDiagnosisViewAll;

  /// No description provided for @aiDiagnosisBookDirectlyBtn.
  ///
  /// In en, this message translates to:
  /// **'Book Directly'**
  String get aiDiagnosisBookDirectlyBtn;

  /// No description provided for @aiDiagnosisAskFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Ask a follow-up question...'**
  String get aiDiagnosisAskFollowUp;

  /// Error shown when AI diagnosis service is unreachable.
  ///
  /// In en, this message translates to:
  /// **'AI diagnosis is unavailable right now.\n{error}'**
  String aiDiagnosisUnavailable(String error);

  /// No description provided for @aiDiagnosisStillBookDirectly.
  ///
  /// In en, this message translates to:
  /// **'You can still book a technician directly.'**
  String get aiDiagnosisStillBookDirectly;

  /// No description provided for @aiDiagnosisBookTechnicianVisit.
  ///
  /// In en, this message translates to:
  /// **'Book Technician Visit'**
  String get aiDiagnosisBookTechnicianVisit;

  /// No description provided for @aiDiagnosisTechnicianFallback.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get aiDiagnosisTechnicianFallback;

  /// Years of experience label for suggested technician cards.
  ///
  /// In en, this message translates to:
  /// **'{years} yrs exp'**
  String aiDiagnosisYearsExp(String years);

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

  /// No description provided for @chatEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get chatEmptyState;

  /// Composer hint text with the chat partner's name.
  ///
  /// In en, this message translates to:
  /// **'Message {peerName}'**
  String chatMessageHint(String peerName);

  /// No description provided for @techJobsLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get techJobsLogoutTitle;

  /// No description provided for @techJobsLogoutContent.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to see your jobs.'**
  String get techJobsLogoutContent;

  /// No description provided for @techJobsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get techJobsCancel;

  /// No description provided for @techJobsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get techJobsLogout;

  /// No description provided for @techJobsNavTitleJobs.
  ///
  /// In en, this message translates to:
  /// **'My Jobs'**
  String get techJobsNavTitleJobs;

  /// No description provided for @techJobsNavTitleConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consultations'**
  String get techJobsNavTitleConsultations;

  /// No description provided for @techJobsNavTitleSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get techJobsNavTitleSettlement;

  /// No description provided for @techJobsNavTitleHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get techJobsNavTitleHistory;

  /// No description provided for @techJobsMyCustomersTooltip.
  ///
  /// In en, this message translates to:
  /// **'My Customers'**
  String get techJobsMyCustomersTooltip;

  /// No description provided for @techJobsLogoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get techJobsLogoutTooltip;

  /// No description provided for @techJobsBottomNavJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get techJobsBottomNavJobs;

  /// No description provided for @techJobsBottomNavUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get techJobsBottomNavUpcoming;

  /// No description provided for @techJobsBottomNavSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get techJobsBottomNavSettlement;

  /// No description provided for @techJobsBottomNavHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get techJobsBottomNavHistory;

  /// No description provided for @techJobsWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back 👋'**
  String get techJobsWelcomeBack;

  /// No description provided for @techJobsWorkOverview.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your work overview'**
  String get techJobsWorkOverview;

  /// No description provided for @techJobsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get techJobsActive;

  /// No description provided for @techJobsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get techJobsCompleted;

  /// No description provided for @techJobsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get techJobsFilterAll;

  /// No description provided for @techJobsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your jobs: {error}'**
  String techJobsCouldNotLoad(String error);

  /// No description provided for @techJobsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get techJobsRetry;

  /// No description provided for @techJobsNoActiveJobs.
  ///
  /// In en, this message translates to:
  /// **'No active jobs right now'**
  String get techJobsNoActiveJobs;

  /// No description provided for @techJobsNoJobsYet.
  ///
  /// In en, this message translates to:
  /// **'No jobs yet'**
  String get techJobsNoJobsYet;

  /// No description provided for @techJobsNewRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'New customer requests will show up here'**
  String get techJobsNewRequestsHint;

  /// No description provided for @techJobsLiveConsultationRequest.
  ///
  /// In en, this message translates to:
  /// **'1 live consultation request'**
  String get techJobsLiveConsultationRequest;

  /// No description provided for @techJobsLiveConsultationRequests.
  ///
  /// In en, this message translates to:
  /// **'{count} live consultation requests'**
  String techJobsLiveConsultationRequests(String count);

  /// No description provided for @techJobsTapAcceptReject.
  ///
  /// In en, this message translates to:
  /// **'Tap to accept or reject'**
  String get techJobsTapAcceptReject;

  /// No description provided for @techJobsScheduledConsultation.
  ///
  /// In en, this message translates to:
  /// **'1 scheduled consultation'**
  String get techJobsScheduledConsultation;

  /// No description provided for @techJobsScheduledConsultations.
  ///
  /// In en, this message translates to:
  /// **'{count} scheduled consultations'**
  String techJobsScheduledConsultations(String count);

  /// No description provided for @techJobsTapConfirmDecline.
  ///
  /// In en, this message translates to:
  /// **'Tap to confirm or decline slots'**
  String get techJobsTapConfirmDecline;

  /// No description provided for @techJobsServiceRequestFallback.
  ///
  /// In en, this message translates to:
  /// **'Service request'**
  String get techJobsServiceRequestFallback;

  /// No description provided for @techJobsCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get techJobsCustomerFallback;

  /// No description provided for @techJobsChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat with customer'**
  String get techJobsChatTooltip;

  /// No description provided for @techJobsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get techJobsDecline;

  /// No description provided for @techJobsAcceptJob.
  ///
  /// In en, this message translates to:
  /// **'Accept job'**
  String get techJobsAcceptJob;

  /// No description provided for @techJobsOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'I\'m on my way'**
  String get techJobsOnMyWay;

  /// No description provided for @techJobsArrived.
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived'**
  String get techJobsArrived;

  /// No description provided for @techJobsGenerateInvoiceComplete.
  ///
  /// In en, this message translates to:
  /// **'Generate invoice & complete'**
  String get techJobsGenerateInvoiceComplete;

  /// No description provided for @techJobsDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this job?'**
  String get techJobsDeclineTitle;

  /// No description provided for @techJobsDeclineContent.
  ///
  /// In en, this message translates to:
  /// **'We\'ll find another technician for this booking. This can\'t be undone.'**
  String get techJobsDeclineContent;

  /// No description provided for @techJobsGenerateInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate invoice'**
  String get techJobsGenerateInvoiceTitle;

  /// No description provided for @techJobsInvoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the final amount the customer should pay. This is sent to them immediately as the amount due.'**
  String get techJobsInvoiceHint;

  /// No description provided for @techJobsFinalAmount.
  ///
  /// In en, this message translates to:
  /// **'Final amount'**
  String get techJobsFinalAmount;

  /// No description provided for @techJobsOfferWarranty.
  ///
  /// In en, this message translates to:
  /// **'Offer a warranty'**
  String get techJobsOfferWarranty;

  /// No description provided for @techJobsWarrantySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer can raise a free revisit within this window'**
  String get techJobsWarrantySubtitle;

  /// No description provided for @techJobsDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get techJobsDuration;

  /// No description provided for @techJobsDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 6'**
  String get techJobsDurationHint;

  /// No description provided for @techJobsWarrantyCoverageLabel.
  ///
  /// In en, this message translates to:
  /// **'What does this warranty cover?'**
  String get techJobsWarrantyCoverageLabel;

  /// No description provided for @techJobsWarrantyCoverageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Compressor and gas refill only'**
  String get techJobsWarrantyCoverageHint;

  /// No description provided for @techJobsDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get techJobsDays;

  /// No description provided for @techJobsMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get techJobsMonths;

  /// No description provided for @techJobsYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get techJobsYears;

  /// No description provided for @techJobsEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get techJobsEnterValidAmount;

  /// No description provided for @techJobsEnterValidWarranty.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid warranty duration'**
  String get techJobsEnterValidWarranty;

  /// No description provided for @techJobsSendInvoice.
  ///
  /// In en, this message translates to:
  /// **'Send invoice'**
  String get techJobsSendInvoice;

  /// No description provided for @techJobsAskOtp.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for their OTP to start the service'**
  String get techJobsAskOtp;

  /// No description provided for @techJobsEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit OTP'**
  String get techJobsEnterOtp;

  /// No description provided for @techJobsIncorrectOtp.
  ///
  /// In en, this message translates to:
  /// **'Incorrect OTP, try again'**
  String get techJobsIncorrectOtp;

  /// No description provided for @techJobsVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get techJobsVerify;

  /// No description provided for @techSettlementVisitHistory.
  ///
  /// In en, this message translates to:
  /// **'Visit History'**
  String get techSettlementVisitHistory;

  /// No description provided for @techSettlementPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get techSettlementPaymentHistory;

  /// No description provided for @techSettlementNoCompletedVisits.
  ///
  /// In en, this message translates to:
  /// **'No completed visits yet'**
  String get techSettlementNoCompletedVisits;

  /// No description provided for @techSettlementNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get techSettlementNoPayments;

  /// No description provided for @techSettlementTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get techSettlementTotalEarned;

  /// No description provided for @techSettlementJobsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Jobs Completed'**
  String get techSettlementJobsCompleted;

  /// No description provided for @techSettlementYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share: ₹{amount}'**
  String techSettlementYourShare(String amount);

  /// No description provided for @techSettlementCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get techSettlementCustomerFallback;

  /// No description provided for @consultUpcomingSlotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Slot confirmed'**
  String get consultUpcomingSlotConfirmed;

  /// No description provided for @consultUpcomingCouldNotConfirm.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm: {error}'**
  String consultUpcomingCouldNotConfirm(String error);

  /// No description provided for @consultUpcomingDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this slot?'**
  String get consultUpcomingDeclineTitle;

  /// No description provided for @consultUpcomingDeclineContent.
  ///
  /// In en, this message translates to:
  /// **'The customer will be notified that you can\'t make {slot} and asked to pick another time.'**
  String consultUpcomingDeclineContent(String slot);

  /// No description provided for @consultUpcomingReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get consultUpcomingReasonOptional;

  /// No description provided for @consultUpcomingReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Not available at that time'**
  String get consultUpcomingReasonHint;

  /// No description provided for @consultUpcomingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get consultUpcomingCancel;

  /// No description provided for @consultUpcomingDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get consultUpcomingDecline;

  /// No description provided for @consultUpcomingSlotDeclined.
  ///
  /// In en, this message translates to:
  /// **'Slot declined'**
  String get consultUpcomingSlotDeclined;

  /// No description provided for @consultUpcomingCouldNotDecline.
  ///
  /// In en, this message translates to:
  /// **'Could not decline: {error}'**
  String consultUpcomingCouldNotDecline(String error);

  /// No description provided for @consultUpcomingThisSlot.
  ///
  /// In en, this message translates to:
  /// **'this slot'**
  String get consultUpcomingThisSlot;

  /// No description provided for @consultUpcomingNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming consultations'**
  String get consultUpcomingNoUpcoming;

  /// No description provided for @consultUpcomingScheduledHint.
  ///
  /// In en, this message translates to:
  /// **'Scheduled requests from customers will show up here'**
  String get consultUpcomingScheduledHint;

  /// No description provided for @consultUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Consultations'**
  String get consultUpcomingTitle;

  /// No description provided for @consultUpcomingFallback.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultUpcomingFallback;

  /// No description provided for @consultUpcomingNeedsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Needs confirmation'**
  String get consultUpcomingNeedsConfirmation;

  /// No description provided for @consultUpcomingConfirmedLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get consultUpcomingConfirmedLabel;

  /// No description provided for @consultUpcomingCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get consultUpcomingCustomerFallback;

  /// No description provided for @consultUpcomingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get consultUpcomingConfirm;

  /// No description provided for @consultUpcomingWaitingSlot.
  ///
  /// In en, this message translates to:
  /// **'Waiting for slot time — you\'ll be notified when it starts'**
  String get consultUpcomingWaitingSlot;

  /// No description provided for @consultMyTitle.
  ///
  /// In en, this message translates to:
  /// **'My Consultations'**
  String get consultMyTitle;

  /// No description provided for @consultMyNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No consultations yet'**
  String get consultMyNoneYet;

  /// No description provided for @consultMyFallback.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultMyFallback;

  /// No description provided for @consultMyWith.
  ///
  /// In en, this message translates to:
  /// **'with {name}'**
  String consultMyWith(String name);

  /// No description provided for @consultMyRequestAgain.
  ///
  /// In en, this message translates to:
  /// **'Request again'**
  String get consultMyRequestAgain;

  /// No description provided for @consultMyAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get consultMyAwaitingConfirmation;

  /// No description provided for @consultMyAwaitingConfirmationMsg.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the technician to confirm your requested slot.'**
  String get consultMyAwaitingConfirmationMsg;

  /// No description provided for @consultMyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get consultMyConfirmed;

  /// No description provided for @consultMyConfirmedMsg.
  ///
  /// In en, this message translates to:
  /// **'Your technician confirmed. The call will start automatically at your scheduled time.'**
  String get consultMyConfirmedMsg;

  /// No description provided for @consultMySearching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get consultMySearching;

  /// No description provided for @consultMySearchingMsg.
  ///
  /// In en, this message translates to:
  /// **'Looking for an available technician...'**
  String get consultMySearchingMsg;

  /// No description provided for @consultMyRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing'**
  String get consultMyRinging;

  /// No description provided for @consultMyRingingMsg.
  ///
  /// In en, this message translates to:
  /// **'Ringing the technician now...'**
  String get consultMyRingingMsg;

  /// No description provided for @consultMyAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get consultMyAccepted;

  /// No description provided for @consultMyAcceptedMsg.
  ///
  /// In en, this message translates to:
  /// **'Technician accepted — connecting your call.'**
  String get consultMyAcceptedMsg;

  /// No description provided for @consultMyTechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Technician unavailable'**
  String get consultMyTechUnavailable;

  /// No description provided for @consultMyNotAnswered.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get consultMyNotAnswered;

  /// No description provided for @consultMyRejectedScheduledMsg.
  ///
  /// In en, this message translates to:
  /// **'The technician was busy and couldn\'t make this slot. Please request a new time.'**
  String get consultMyRejectedScheduledMsg;

  /// No description provided for @consultMyRejectedInstantMsg.
  ///
  /// In en, this message translates to:
  /// **'The technician couldn\'t take your call. You can try again.'**
  String get consultMyRejectedInstantMsg;

  /// No description provided for @consultMyReasonPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String consultMyReasonPrefix(String reason);

  /// No description provided for @consultMyNoTechAvailable.
  ///
  /// In en, this message translates to:
  /// **'No technician available'**
  String get consultMyNoTechAvailable;

  /// No description provided for @consultMyNoTechAvailableMsg.
  ///
  /// In en, this message translates to:
  /// **'No technician was available for this request. Please try again later.'**
  String get consultMyNoTechAvailableMsg;

  /// No description provided for @consultMyInCall.
  ///
  /// In en, this message translates to:
  /// **'In call'**
  String get consultMyInCall;

  /// No description provided for @consultMyInCallMsg.
  ///
  /// In en, this message translates to:
  /// **'Call in progress.'**
  String get consultMyInCallMsg;

  /// No description provided for @consultMyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get consultMyCompleted;

  /// No description provided for @consultMyCompletedMsg.
  ///
  /// In en, this message translates to:
  /// **'This consultation has ended.'**
  String get consultMyCompletedMsg;

  /// No description provided for @consultMyCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get consultMyCancelled;

  /// No description provided for @consultMyCancelledMsg.
  ///
  /// In en, this message translates to:
  /// **'You cancelled this request.'**
  String get consultMyCancelledMsg;

  /// Text for consultTitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Consult'**
  String get consultTitle;

  /// Text for consultTabChat on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get consultTabChat;

  /// Text for consultTabVideo on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get consultTabVideo;

  /// Text for consultTabCall on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get consultTabCall;

  /// Text for consultNoCallsTitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get consultNoCallsTitle;

  /// Text for consultNoCallsSubtitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Once a technician is assigned to your booking, you\'ll be able to call them here.'**
  String get consultNoCallsSubtitle;

  /// Text for consultNoChatsTitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get consultNoChatsTitle;

  /// Text for consultNoChatsSubtitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Once a technician is assigned to your booking, you\'ll be able to chat with them here.'**
  String get consultNoChatsSubtitle;

  /// Text for consultServiceBookingFallback on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Service booking'**
  String get consultServiceBookingFallback;

  /// Text for consultNoVideoCallsTitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'No video consultations yet'**
  String get consultNoVideoCallsTitle;

  /// Text for consultNoVideoCallsSubtitle on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Your live video consultations with technicians will show up here.'**
  String get consultNoVideoCallsSubtitle;

  /// Text for consultStatusCompleted on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get consultStatusCompleted;

  /// Text for consultStatusCancelled on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get consultStatusCancelled;

  /// Text for consultStatusTechnicianUnavailable on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Technician unavailable'**
  String get consultStatusTechnicianUnavailable;

  /// Text for consultStatusDeclined on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get consultStatusDeclined;

  /// Text for consultStatusNoExpertFound on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'No expert found'**
  String get consultStatusNoExpertFound;

  /// Text for consultStatusInCall on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'In call'**
  String get consultStatusInCall;

  /// Text for consultStatusConfirmed on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get consultStatusConfirmed;

  /// Text for consultStatusAwaitingConfirmation on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get consultStatusAwaitingConfirmation;

  /// Text for consultStatusUpcoming on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get consultStatusUpcoming;

  /// Text for consultHelperRejectedScheduled on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'The technician couldn\'t hold this slot. Please schedule a new time.'**
  String get consultHelperRejectedScheduled;

  /// Text for consultHelperRejectedInstant on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'The technician was unavailable to take this call.'**
  String get consultHelperRejectedInstant;

  /// Text for consultHelperScheduled on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the technician to confirm this slot.'**
  String get consultHelperScheduled;

  /// Text for consultHelperConfirmed on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'The technician has confirmed this slot.'**
  String get consultHelperConfirmed;

  /// Text for consultHelperNoTechnician on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'No technician was available for this consultation.'**
  String get consultHelperNoTechnician;

  /// Text for consultTechnicianFallback on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get consultTechnicianFallback;

  /// Text for consultVideoConsultationFallback on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'Video consultation'**
  String get consultVideoConsultationFallback;

  /// Text for consultNewRecommendation on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'New recommendation from your technician'**
  String get consultNewRecommendation;

  /// Text for consultNewBadge on the Consult screen.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get consultNewBadge;

  /// Short duration label, e.g. '5 min', shown after a completed video consultation.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String consultMinutesShort(String minutes);

  /// Text for profileLogoutDialogTitle on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get profileLogoutDialogTitle;

  /// Text for profileLogoutDialogContent on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get profileLogoutDialogContent;

  /// Text for profileLogoutConfirm on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogoutConfirm;

  /// Text for profileDeleteDialogTitle on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get profileDeleteDialogTitle;

  /// Text for profileDeleteDialogContent on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This action cannot be undone.'**
  String get profileDeleteDialogContent;

  /// Text for profileDeleteConfirm on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDeleteConfirm;

  /// Text for profileLogInButton on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get profileLogInButton;

  /// Text for profileTechnicianDefaultName on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get profileTechnicianDefaultName;

  /// Text for profileRegistrationIncompleteMsg on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Your technician registration is incomplete. Complete it to start receiving jobs.'**
  String get profileRegistrationIncompleteMsg;

  /// Text for profileCompleteRegistration on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get profileCompleteRegistration;

  /// Text for profileLogOutButton on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogOutButton;

  /// Text for profileNoRatingsYet on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get profileNoRatingsYet;

  /// Text for profileOnlineStatus on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get profileOnlineStatus;

  /// Text for profileOfflineStatus on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get profileOfflineStatus;

  /// Text for profileCanBookNow on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Customers can book you now'**
  String get profileCanBookNow;

  /// Text for profileNoNewRequests on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'You won\'t receive new requests'**
  String get profileNoNewRequests;

  /// Text for profileNeedKycApproval on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC approval to go online'**
  String get profileNeedKycApproval;

  /// Text for profileSectionProfessionalDetails on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Professional Details'**
  String get profileSectionProfessionalDetails;

  /// Text for profilePrimaryService on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Primary Service'**
  String get profilePrimaryService;

  /// Text for profileYearsExperienceLabel on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get profileYearsExperienceLabel;

  /// Text for profileAddressLabel on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddressLabel;

  /// Text for profileServiceRadius on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Service Radius'**
  String get profileServiceRadius;

  /// Text for profileSectionTrustVerification on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Trust & Verification'**
  String get profileSectionTrustVerification;

  /// Text for profilePhoneVerified on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Phone Verified'**
  String get profilePhoneVerified;

  /// Text for profileProfileVerified on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile Verified'**
  String get profileProfileVerified;

  /// Text for profileGovIdUploaded on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Government ID Uploaded'**
  String get profileGovIdUploaded;

  /// Text for profileSectionDocuments on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get profileSectionDocuments;

  /// Text for profileGovId on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Government ID'**
  String get profileGovId;

  /// Text for profileBankUpiDetails on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Bank / UPI Details'**
  String get profileBankUpiDetails;

  /// Text for profileSectionWork on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get profileSectionWork;

  /// Text for profileLiveConsultationRequestsLabel on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Live Consultation Requests'**
  String get profileLiveConsultationRequestsLabel;

  /// Text for profileNotificationSettings on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get profileNotificationSettings;

  /// Text for profilePaymentSettings on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Payment Settings'**
  String get profilePaymentSettings;

  /// Text for profilePrivacySecurity on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get profilePrivacySecurity;

  /// Text for profileChangePasswordPin on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Change Password / PIN'**
  String get profileChangePasswordPin;

  /// Text for profileVerifiedStatus on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerifiedStatus;

  /// Text for profilePendingStatus on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get profilePendingStatus;

  /// Text for profileApprovalApproved on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get profileApprovalApproved;

  /// Text for profileApprovalRejected on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get profileApprovalRejected;

  /// Text for profileApprovalPending on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get profileApprovalPending;

  /// Text for profileComingSoonMessage on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon. We\'re working hard to bring it to you.'**
  String get profileComingSoonMessage;

  /// Text for profileGoBackButton on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get profileGoBackButton;

  /// Years of experience value, e.g. '5 years', on the technician profile.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String profileYearsValue(String years);

  /// Reason shown when a technician's KYC was rejected.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String profileRejectionReason(String reason);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
