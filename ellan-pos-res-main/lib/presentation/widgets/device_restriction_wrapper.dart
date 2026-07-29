import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import '../screens/unsupported_device_screen.dart';

class DeviceRestrictionWrapper extends StatelessWidget {
  final Widget child;

  const DeviceRestrictionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Browser / desktop web is used as a tablet emulator in local dev.
    if (kIsWeb || ResponsiveUtils.isTablet(context)) {
      return child;
    }
    return const UnsupportedDeviceScreen();
  }
}
