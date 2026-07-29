// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NexPOS Tablet';

  @override
  String get welcomeUnlockBusiness => 'Unlock Your\nBusiness Potential';

  @override
  String get welcomeDescription =>
      'NexPOS provides an intuitive tablet experience designed perfectly for modern workflows.';

  @override
  String get welcomeGetStarted => 'Let\'s Get Started';

  @override
  String get welcomeAuthPrompt =>
      'Log in to your account or create a new one to start processing payments effortlessly.';

  @override
  String get welcomeEnterOrg => 'Enter your organization name';

  @override
  String get welcomeOrgHint => 'e.g. Acme Corp';

  @override
  String get welcomeEnterOrgCode => 'Enter your organization code';

  @override
  String get welcomeOrgCodeHint => 'e.g., 100001';

  @override
  String get welcomeSubmit => 'Submit';

  @override
  String get signInWelcome => 'Welcome';

  @override
  String get signInEmailPhone => 'Email / Mobile Number';

  @override
  String get signInEmailPhoneHint => 'Enter email or mobile';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInPasswordHint => 'Enter password';

  @override
  String get signInShowPassword => 'Show Password';

  @override
  String get signInForgotPasswordPrompt => 'Forgot Password?';

  @override
  String get signInButton => 'Sign In';

  @override
  String get forgotPasswordTitle => 'Forgot Password?';

  @override
  String get forgotPasswordInstruction =>
      'Please enter your registered Email address or Phone Number.';

  @override
  String get forgotPasswordSuccess =>
      'Password reset link sent to your registered address!';

  @override
  String get forgotPasswordSendLink => 'Send Reset Link';

  @override
  String get forgotPasswordBackToSignIn => 'Back to Sign In';

  @override
  String get homeWelcomeBack => 'Welcome Back';

  @override
  String get homeActivityPrompt => 'What would you like to do today?';

  @override
  String get homePosDashboard => 'POS Dashboard';

  @override
  String get homeDashboardDesc => 'View analytics and summary';

  @override
  String get homeOrdersList => 'Orders';

  @override
  String get homeOrdersListDesc => 'View and manage all orders';

  @override
  String get homeCreateOrder => 'New Order';

  @override
  String get dashboardTitle => 'POS Dashboard';

  @override
  String get dashboardFilterYesterday => 'Yesterday';

  @override
  String get dashboardFilterToday => 'Today';

  @override
  String get dashboardFilterWeek => 'This Week';

  @override
  String get dashboardFilterMonth => 'This Month';

  @override
  String get dashboardFilterYear => 'This Year';

  @override
  String get dashboardMetricDineIn => 'Dine-In';

  @override
  String get dashboardMetricDelivered => 'Delivered';

  @override
  String get dashboardMetricPickup => 'Pickup';

  @override
  String get dashboardMetricCancelled => 'Cancelled';

  @override
  String get dashboardMetricOrders => 'Orders';

  @override
  String get dashboardMetricTotalSales => 'Total Sales';

  @override
  String get dashboardTopCategories => 'Top Categories';

  @override
  String get dashboardTopProducts => 'Top Products';

  @override
  String get unsupportedDeviceTitle => 'Device Not Supported';

  @override
  String get unsupportedDeviceDesc =>
      'NexPOS is designed specifically for tablets and large screens.\n\nPlease access the app from an iPad or Android Tablet in landscape orientation.';

  @override
  String get errorRequiredField => 'This field is required';

  @override
  String get errorInvalidEmail => 'Invalid email address';

  @override
  String get orderTypeSelection => 'Select Order Type';

  @override
  String get orderTypePickup => 'Pickup';

  @override
  String get orderTypeDineIn => 'Dine-In';

  @override
  String get pickupName => 'Name';

  @override
  String get pickupNameHint => 'Enter your name';

  @override
  String get pickupPhone => 'Phone Number';

  @override
  String get pickupPhoneHint => 'Enter 10-digit number';

  @override
  String get pickupAddButton => 'Add';

  @override
  String get pickupCancelButton => 'Cancel';

  @override
  String get dineInFloorFirst => 'First Floor';

  @override
  String get dineInFloorSecond => 'Second Floor';

  @override
  String dineInTable(String number) {
    return 'Table $number';
  }

  @override
  String get errorNameMinLength => 'Minimum 3 characters';

  @override
  String get errorInvalidPhone => 'Must be exactly 10 digits';

  @override
  String get orderListFilterAll => 'All';

  @override
  String get orderListFilterDineIn => 'Dine In';

  @override
  String get orderListFilterPickup => 'Pickup';

  @override
  String get orderListFilterDelivery => 'Delivery';

  @override
  String get orderListSearchHint => 'Search by order ID, name, phone, email...';

  @override
  String get orderListColumnSlNo => 'Sl No';

  @override
  String get orderListColumnOrderId => 'Order ID';

  @override
  String get orderListColumnOrderType => 'Type';

  @override
  String get orderListColumnName => 'Name';

  @override
  String get orderListColumnTime => 'Time';

  @override
  String get orderListColumnStatus => 'Status';

  @override
  String get orderListColumnPayment => 'Payment';

  @override
  String get orderListColumnItems => 'Items';

  @override
  String get orderListColumnTotal => 'Total';

  @override
  String get orderListColumnActions => 'Actions';

  @override
  String get orderListPayNow => 'Pay Now';

  @override
  String get orderListFilterButton => 'Filter';

  @override
  String get orderListRefreshButton => 'Refresh';
}
