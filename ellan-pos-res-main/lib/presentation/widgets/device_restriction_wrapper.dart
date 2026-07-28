import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import '../screens/unsupported_device_screen.dart';

class DeviceRestrictionWrapper extends StatelessWidget {
  final Widget child;

  const DeviceRestrictionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Determine screen size and conditionally render.
    if (!ResponsiveUtils.isTablet(context)) {
      return const UnsupportedDeviceScreen();
    }
    return child;
  }
}
