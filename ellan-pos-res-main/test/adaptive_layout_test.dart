import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/presentation/widgets/adaptive_checkout_panels.dart';
import 'package:pos_tablet/presentation/widgets/adaptive_form_row.dart';

void main() {
  testWidgets('checkout adapts to phone and tablet orientations', (tester) async {
    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AdaptiveCheckoutPanels(
            primaryLabel: 'Products',
            secondaryLabel: 'Cart',
            primary: Center(child: Text('Catalogue')),
            secondary: Center(child: Text('Order')),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width < 900) {
        expect(find.byType(TabBar), findsOneWidget);
        await tester.tap(find.widgetWithText(Tab, 'Cart'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Order'));
        expect(find.text('Order').hitTestable(), findsOneWidget);
      } else {
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('Catalogue').hitTestable(), findsOneWidget);
        expect(find.text('Order').hitTestable(), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.reset();
  });

  testWidgets('form controls stack when their actual container is narrow', (tester) async {
    for (final width in [320.0, 700.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const AdaptiveFormRow(
                children: [
                  TextField(key: ValueKey('first')),
                  TextField(key: ValueKey('second')),
                ],
              ),
            ),
          ),
        ),
      ));
      final first = tester.getTopLeft(find.byKey(const ValueKey('first')));
      final second = tester.getTopLeft(find.byKey(const ValueKey('second')));
      if (width < 532) {
        expect(second.dy, greaterThan(first.dy));
        expect(second.dx, first.dx);
      } else {
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
