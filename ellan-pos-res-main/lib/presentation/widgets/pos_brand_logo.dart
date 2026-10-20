import 'package:flutter/material.dart';

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
