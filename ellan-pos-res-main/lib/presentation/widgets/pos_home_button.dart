import 'package:flutter/material.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// House icon kept in the top bar on every screen size.
class PosHomeButton extends StatelessWidget {
  const PosHomeButton({super.key});

  static const color = Color(0xFF4A00E0);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.homePosDashboard,
      style: IconButton.styleFrom(foregroundColor: color),
      icon: const Icon(Icons.home_rounded, color: color, size: 28),
      onPressed: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      },
    );
  }
}
