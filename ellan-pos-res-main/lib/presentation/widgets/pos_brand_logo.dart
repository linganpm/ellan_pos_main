import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/font_utility.dart';

class PosBrandLogo extends StatelessWidget {
  static const assetPath = 'assets/branding/ellan_pos.png';

  final double size;

  const PosBrandLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) => Image.asset(
    assetPath,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'EllanPOS',
  );
}

/// App-bar crop of the EllanPOS artwork. The full lockup is mostly white
/// padding, so the bar zooms into the terminal mark.
class PosBrandMark extends StatelessWidget {
  final double size;

  const PosBrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final art = size * 1.75;
    return Semantics(
      label: 'EllanPOS',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.none,
            alignment: const Alignment(0, -0.42),
            clipBehavior: Clip.hardEdge,
            child: Image.asset(
              PosBrandLogo.assetPath,
              width: art,
              height: art,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marketing link shown on the splash, sign-in, and signup screens.
class EllantecSiteMark extends StatelessWidget {
  final Color color;

  const EllantecSiteMark({super.key, required this.color});

  static final Uri site = Uri.parse('https://ellantec.com');

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        try {
          await launchUrl(site, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'ellantec.com',
        style: FontUtility.body.copyWith(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Puts the EllanPOS icon in front of a screen title.
class PosBrandTitle extends StatelessWidget {
  final Widget child;

  const PosBrandTitle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PosBrandMark(size: 40),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: child,
          ),
        ),
      ],
    );
  }
}
