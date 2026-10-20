import 'package:flutter/material.dart';

class AdaptiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double minChildWidth;

  const AdaptiveFormRow({
    super.key,
    required this.children,
    this.minChildWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final fits = constraints.maxWidth >=
            children.length * minChildWidth + (children.length - 1) * gap;
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
