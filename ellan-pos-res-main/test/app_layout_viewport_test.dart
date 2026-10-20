import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/presentation/widgets/app_layout_viewport.dart';

void main() {
  test('layout define selects the expected app profile', () {
    expect(appLayoutMode, anyOf('tablet', 'mobile'));
    expect(isMobileLayout, appLayoutMode == 'mobile');
    if (appLayoutMode == 'tablet') {
      expect(isMobileLayout, isFalse);
    }
  });

  testWidgets('mobile profile uses a phone-width viewport on a wide display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppLayoutViewport(forceMobile: true, child: child!),
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => Text(
              '${MediaQuery.sizeOf(context).width}:${constraints.maxWidth}',
            ),
          ),
        ),
      ),
    );

    expect(find.text('480.0:480.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet profile keeps the full available width', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppLayoutViewport(forceMobile: false, child: child!),
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => Text(
              '${MediaQuery.sizeOf(context).width}:${constraints.maxWidth}',
            ),
          ),
        ),
      ),
    );

    expect(find.text('1280.0:1280.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
