import 'package:flutter/material.dart';

/// Keeps checkout panels side by side only when both have room to operate.
class AdaptiveCheckoutPanels extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final String primaryLabel;
  final String secondaryLabel;
  final int primaryFlex;
  final int secondaryFlex;

  const AdaptiveCheckoutPanels({
    super.key,
    required this.primary,
    required this.secondary,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              const VerticalDivider(width: 1),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: primaryLabel),
                  Tab(text: secondaryLabel),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _scrollablePanel(primary),
                    _scrollablePanel(secondary),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scrollablePanel(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight < 640 ? 640 : constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
