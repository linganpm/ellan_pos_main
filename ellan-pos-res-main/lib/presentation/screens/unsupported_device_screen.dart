import 'package:flutter/material.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/font_utility.dart';

class UnsupportedDeviceScreen extends StatelessWidget {
  const UnsupportedDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Deep dark minimal color
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 15,
                  offset: Offset(0, 10),
                )
              ],
            ),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tablet_android,
                  size: 80,
                  color: Color(0xFFE94560), // Accent vibrant red/pink
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.unsupportedDeviceTitle,
                  style: FontUtility.heading.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.unsupportedDeviceDesc,
                  style: FontUtility.body.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
