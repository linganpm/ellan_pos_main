import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ta'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NexPOS Tablet'**
  String get appName;

  /// No description provided for @welcomeUnlockBusiness.
  ///
  /// In en, this message translates to:
  /// **'Unlock Your\nBusiness Potential'**
  String get welcomeUnlockBusiness;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'NexPOS provides an intuitive tablet experience designed perfectly for modern workflows.'**
  String get welcomeDescription;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeAuthPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account or create a new one to start processing payments effortlessly.'**
  String get welcomeAuthPrompt;

  /// No description provided for @welcomeEnterOrg.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization name'**
  String get welcomeEnterOrg;

  /// No description provided for @welcomeOrgHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Acme Corp'**
  String get welcomeOrgHint;

  /// No description provided for @welcomeEnterOrgCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization code'**
  String get welcomeEnterOrgCode;

  /// No description provided for @welcomeOrgCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 100001'**
  String get welcomeOrgCodeHint;

  /// No description provided for @welcomeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get welcomeSubmit;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get signInWelcome;

  /// No description provided for @signInEmailPhone.
  ///
  /// In en, this message translates to:
  /// **'Email / Mobile Number'**
  String get signInEmailPhone;

  /// No description provided for @signInEmailPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email or mobile'**
  String get signInEmailPhoneHint;

  /// No description provided for @signInPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get signInPasswordHint;

  /// No description provided for @signInShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show Password'**
  String get signInShowPassword;

  /// No description provided for @signInForgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get signInForgotPasswordPrompt;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please enter your registered Email address or Phone Number.'**
  String get forgotPasswordInstruction;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your registered address!'**
  String get forgotPasswordSuccess;

  /// No description provided for @forgotPasswordSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordSendLink;

  /// No description provided for @forgotPasswordBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get forgotPasswordBackToSignIn;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get homeWelcomeBack;

  /// No description provided for @homeActivityPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do today?'**
  String get homeActivityPrompt;

  /// No description provided for @homePosDashboard.
  ///
  /// In en, this message translates to:
  /// **'POS Dashboard'**
  String get homePosDashboard;

  /// No description provided for @homeDashboardDesc.
  ///
  /// In en, this message translates to:
  /// **'View analytics and summary'**
  String get homeDashboardDesc;

  /// No description provided for @homeOrdersList.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get homeOrdersList;

  /// No description provided for @homeOrdersListDesc.
  ///
  /// In en, this message translates to:
  /// **'View and manage all orders'**
  String get homeOrdersListDesc;

  /// No description provided for @homeCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get homeCreateOrder;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'POS Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardFilterYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dashboardFilterYesterday;

  /// No description provided for @dashboardFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardFilterToday;

  /// No description provided for @dashboardFilterWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get dashboardFilterWeek;

  /// No description provided for @dashboardFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get dashboardFilterMonth;

  /// No description provided for @dashboardFilterYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get dashboardFilterYear;

  /// No description provided for @dashboardMetricDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-In'**
  String get dashboardMetricDineIn;

  /// No description provided for @dashboardMetricDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get dashboardMetricDelivered;

  /// No description provided for @dashboardMetricPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get dashboardMetricPickup;

  /// No description provided for @dashboardMetricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get dashboardMetricCancelled;

  /// No description provided for @dashboardMetricOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get dashboardMetricOrders;

  /// No description provided for @dashboardMetricTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get dashboardMetricTotalSales;

  /// No description provided for @dashboardTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top Categories'**
  String get dashboardTopCategories;

  /// No description provided for @unsupportedDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Not Supported'**
  String get unsupportedDeviceTitle;

  /// No description provided for @unsupportedDeviceDesc.
  ///
  /// In en, this message translates to:
  /// **'NexPOS is designed specifically for tablets and large screens.\n\nPlease access the app from an iPad or Android Tablet in landscape orientation.'**
  String get unsupportedDeviceDesc;

  /// No description provided for @errorRequiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorRequiredField;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get errorInvalidEmail;

  /// No description provided for @orderTypeSelection.
  ///
  /// In en, this message translates to:
  /// **'Select Order Type'**
  String get orderTypeSelection;

  /// No description provided for @orderTypePickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get orderTypePickup;

  /// No description provided for @orderTypeDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-In'**
  String get orderTypeDineIn;

  /// No description provided for @pickupName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pickupName;

  /// No description provided for @pickupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get pickupNameHint;

  /// No description provided for @pickupPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get pickupPhone;

  /// No description provided for @pickupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit number'**
  String get pickupPhoneHint;

  /// No description provided for @pickupAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get pickupAddButton;

  /// No description provided for @pickupCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pickupCancelButton;

  /// No description provided for @dineInFloorFirst.
  ///
  /// In en, this message translates to:
  /// **'First Floor'**
  String get dineInFloorFirst;

  /// No description provided for @dineInFloorSecond.
  ///
  /// In en, this message translates to:
  /// **'Second Floor'**
  String get dineInFloorSecond;

  /// No description provided for @dineInTable.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String dineInTable(String number);

  /// No description provided for @errorNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 3 characters'**
  String get errorNameMinLength;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Must be exactly 10 digits'**
  String get errorInvalidPhone;

  /// No description provided for @orderListFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get orderListFilterAll;

  /// No description provided for @orderListFilterDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine In'**
  String get orderListFilterDineIn;

  /// No description provided for @orderListFilterPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get orderListFilterPickup;

  /// No description provided for @orderListFilterDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get orderListFilterDelivery;

  /// No description provided for @orderListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order ID, name, phone, email...'**
  String get orderListSearchHint;

  /// No description provided for @orderListColumnSlNo.
  ///
  /// In en, this message translates to:
  /// **'Sl No'**
  String get orderListColumnSlNo;

  /// No description provided for @orderListColumnOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderListColumnOrderId;

  /// No description provided for @orderListColumnOrderType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get orderListColumnOrderType;

  /// No description provided for @orderListColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get orderListColumnName;

  /// No description provided for @orderListColumnTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get orderListColumnTime;

  /// No description provided for @orderListColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderListColumnStatus;

  /// No description provided for @orderListColumnPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get orderListColumnPayment;

  /// No description provided for @orderListColumnItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderListColumnItems;

  /// No description provided for @orderListColumnTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get orderListColumnTotal;

  /// No description provided for @orderListColumnActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get orderListColumnActions;

  /// No description provided for @orderListPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get orderListPayNow;

  /// No description provided for @orderListFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get orderListFilterButton;

  /// No description provided for @orderListRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get orderListRefreshButton;
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
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
