import 'package:flutter/material.dart';

class ResponsiveUtils {
  /// Defines the minimum logical width considered as a tablet.
  static const double tabletBreakpoint = 600.0;

  /// Returns true if the device's width is greater than or equal to the [tabletBreakpoint].
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Use the shortest side just in case orientation hasn't fully locked yet, 
    // but typically for landscape, width will be the longest.
    // However, a tablet's shortest side is usually 600+.
    final shortestSide = size.shortestSide;
    return shortestSide >= tabletBreakpoint;
  }
}
