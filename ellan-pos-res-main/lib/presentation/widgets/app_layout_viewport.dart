import 'package:flutter/material.dart';

const appLayoutMode = String.fromEnvironment(
  'APP_LAYOUT',
  defaultValue: 'tablet',
);

const isMobileLayout = appLayoutMode == 'mobile';

class AppLayoutViewport extends StatelessWidget {
  final Widget child;
  final bool forceMobile;

  const AppLayoutViewport({
    super.key,
    required this.child,
    this.forceMobile = isMobileLayout,
  });

  static const mobileWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    if (!forceMobile) return child;

    final screenSize = MediaQuery.sizeOf(context);
    final width = screenSize.width < mobileWidth
        ? screenSize.width
        : mobileWidth;
    final mobileSize = Size(width, screenSize.height);

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: width,
        height: screenSize.height,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: mobileSize),
          child: child,
        ),
      ),
    );
  }
}
