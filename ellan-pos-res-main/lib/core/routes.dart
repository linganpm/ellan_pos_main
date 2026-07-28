import 'package:flutter/material.dart';
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

/// Centralised route names and route generation for the application.
class AppRoutes {
  static const String onboarding = 'onboarding';
  static const String login = 'login';
  static const String staffLock = 'staffLock';
  static const String storeList = 'storeList';
  static const String home = 'home';
  static const String sync = 'sync';
  static const String profile = 'profile';
  static const String deviceSettings = 'deviceSettings';
  static const String orderDetails = 'orderDetails';
  static const String orderPayments = 'orderPayments';

  static Map<String, WidgetBuilder> get routes => {
        onboarding: (context) => const WelcomeScreen(),
        login: (context) => const SignInScreen(),
        staffLock: (context) => const StaffLockScreen(),
        storeList: (context) => const StoreListScreen(),
        home: (context) => const HomeScreen(),
        sync: (context) => const SyncScreen(),
        profile: (context) => const ProfileScreen(),
        deviceSettings: (context) => const DeviceSettingsScreen(),
      };

  static Route<dynamic>? generate(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const SignInScreen());
      case staffLock: {
        final args = settings.arguments;
        String? storeId;
        if (args is String) {
          storeId = args;
        } else if (args is Map) {
          storeId = args['storeId']?.toString();
        }
        return MaterialPageRoute(
          builder: (_) => StaffLockScreen(storeId: storeId),
        );
      }
      case storeList:
        return MaterialPageRoute(builder: (_) => const StoreListScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case sync:
        return MaterialPageRoute(builder: (_) => const SyncScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case deviceSettings:
        return MaterialPageRoute(builder: (_) => const DeviceSettingsScreen());
      case orderDetails: {
        final args = settings.arguments;
        final orderId = args is int
            ? args
            : int.tryParse('${args ?? ''}') ?? 0;
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: orderId),
        );
      }
      case orderPayments: {
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
          builder: (_) => OrderPaymentsScreen(
            orderId: orderId,
            orderLabel: orderLabel,
          ),
        );
      }
      default:
        return null;
    }
  }
}
