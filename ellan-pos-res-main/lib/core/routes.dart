import 'package:flutter/material.dart';
import 'package:pos_tablet/presentation/screens/auth_entry_screen.dart';
import 'package:pos_tablet/presentation/screens/welcome_screen.dart';
import 'package:pos_tablet/presentation/screens/sign_in_screen.dart';
import 'package:pos_tablet/presentation/screens/staff_lock_screen.dart';
import 'package:pos_tablet/presentation/screens/store_list_screen.dart';
import 'package:pos_tablet/presentation/screens/home_screen.dart';
import 'package:pos_tablet/presentation/screens/sync_screen.dart';
import 'package:pos_tablet/presentation/screens/profile_screen.dart';
import 'package:pos_tablet/presentation/screens/order_details_screen.dart';
import 'package:pos_tablet/presentation/screens/order_payments_screen.dart';
import 'package:pos_tablet/presentation/screens/device_settings_screen.dart';
import 'package:pos_tablet/features/company_signup/presentation/company_signup_shell.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_hub_screen.dart';
import 'package:pos_tablet/features/company/presentation/company_hub_screen.dart';

/// Centralised route names and route generation for the application.
class AppRoutes {
  static const String authEntry = 'authEntry';
  static const String onboarding = 'onboarding';
  static const String joinExisting = 'joinExisting';
  static const String login = 'login';
  static const String staffLock = 'staffLock';
  static const String storeList = 'storeList';
  static const String home = 'home';
  static const String sync = 'sync';
  static const String profile = 'profile';
  static const String deviceSettings = 'deviceSettings';
  static const String storeSetup = 'storeSetup';
  static const String company = 'company';
  static const String orderDetails = 'orderDetails';
  static const String orderPayments = 'orderPayments';

  static Map<String, WidgetBuilder> get routes => {
    authEntry: (context) => const AuthEntryScreen(),
    onboarding: (context) => const CompanySignupShell(),
    joinExisting: (context) => const WelcomeScreen(),
    login: (context) => const SignInScreen(),
    // storeList / staffLock only via [generate] so route arguments apply.
    home: (context) => const HomeScreen(),
    sync: (context) => const SyncScreen(),
    profile: (context) => const ProfileScreen(),
    deviceSettings: (context) => const DeviceSettingsScreen(),
    storeSetup: (context) => const StoreSetupHubScreen(),
    company: (context) => const CompanyHubScreen(),
  };

  static Route<dynamic>? generate(RouteSettings settings) {
    switch (settings.name) {
      case authEntry:
        return MaterialPageRoute(builder: (_) => const AuthEntryScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const CompanySignupShell());
      case joinExisting:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case login:
        {
          final args = settings.arguments;
          String? email;
          String? phone;
          String? companyIdentifier;
          if (args is Map) {
            email = args['email']?.toString();
            phone = args['phone']?.toString();
            companyIdentifier = args['companyIdentifier']?.toString();
          }
          return MaterialPageRoute(
            builder: (_) => SignInScreen(
              initialIdentifier: (email != null && email.trim().isNotEmpty)
                  ? email.trim()
                  : (phone != null && phone.trim().isNotEmpty
                        ? phone.trim()
                        : null),
              companyIdentifierHint: companyIdentifier,
            ),
          );
        }
      case staffLock:
        {
          final args = settings.arguments;
          String? storeId;
          String? storeName;
          if (args is String) {
            storeId = args;
          } else if (args is Map) {
            storeId = args['storeId']?.toString();
            storeName = args['storeName']?.toString();
          }
          return MaterialPageRoute(
            builder: (_) =>
                StaffLockScreen(storeId: storeId, storeNameHint: storeName),
          );
        }
      case storeList:
        {
          final args = settings.arguments;
          var returnToStaffLock = false;
          if (args is Map) {
            returnToStaffLock = args['returnToStaffLock'] == true;
          } else if (args is bool) {
            returnToStaffLock = args;
          }
          return MaterialPageRoute(
            builder: (_) =>
                StoreListScreen(returnToStaffLock: returnToStaffLock),
          );
        }
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case sync:
        return MaterialPageRoute(builder: (_) => const SyncScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case deviceSettings:
        return MaterialPageRoute(builder: (_) => const DeviceSettingsScreen());
      case storeSetup:
        return MaterialPageRoute(builder: (_) => const StoreSetupHubScreen());
      case company:
        return MaterialPageRoute(builder: (_) => const CompanyHubScreen());
      case orderDetails:
        {
          final args = settings.arguments;
          final orderId = args is int
              ? args
              : int.tryParse('${args ?? ''}') ?? 0;
          return MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(orderId: orderId),
          );
        }
      case orderPayments:
        {
          final args = settings.arguments;
          int orderId = 0;
          String? orderLabel;
          if (args is int) {
            orderId = args;
          } else if (args is Map) {
            orderId = int.tryParse('${args['orderId'] ?? ''}') ?? 0;
            orderLabel = args['orderLabel']?.toString();
          }
          return MaterialPageRoute(
            builder: (_) =>
                OrderPaymentsScreen(orderId: orderId, orderLabel: orderLabel),
          );
        }
      default:
        return null;
    }
  }
}
