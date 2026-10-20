import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/core/pos_theme.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
import 'package:pos_tablet/data/models/product_model.dart';
import 'package:pos_tablet/presentation/widgets/billing/billing_items_table.dart';
import 'package:pos_tablet/presentation/widgets/billing/order_add_payment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_collect_payment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_schedule_repayment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/customer_advance_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget app(Widget child) => MaterialApp(
    theme: PosTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('forms and tables use one Material 3 component theme', (
    tester,
  ) async {
    final theme = PosTheme.light();
    final fields = theme.inputDecorationTheme;
    expect(theme.useMaterial3, isTrue);
    expect(fields.filled, isTrue);
    final idle = fields.enabledBorder! as OutlineInputBorder;
    final focused = fields.focusedBorder! as OutlineInputBorder;
    final error = fields.errorBorder! as OutlineInputBorder;
    expect(idle.borderRadius, focused.borderRadius);
    expect(idle.borderRadius, error.borderRadius);
    expect(focused.borderSide.width, greaterThan(idle.borderSide.width));
    expect(error.borderSide.color, theme.colorScheme.error);
    expect(theme.dataTableTheme.dataRowMinHeight, greaterThanOrEqualTo(48));
    expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('credit dialogs fit with the keyboard open', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);

    for (final dialog in <Widget>[
      const CreditCollectPaymentDialog(
        customerName: 'Customer',
        outstanding: 100,
      ),
      const CreditScheduleRepaymentDialog(customerName: 'Customer'),
      const CustomerAdvanceDialog(
        customerName: 'Customer',
        accountBalance: 100,
      ),
      const OrderAddPaymentDialog(
        remainingAmount: 100,
        paymentMode: 'Cash',
        paymentLabel: 'Cash',
      ),
    ]) {
      await tester.pumpWidget(app(dialog));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${dialog.runtimeType}');
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration?.border, isNot(isA<UnderlineInputBorder>()));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'collect payment still returns the entered amount and reference',
    (tester) async {
      CreditCollectPaymentResult? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<CreditCollectPaymentResult>(
                  context: context,
                  builder: (_) => const CreditCollectPaymentDialog(
                    customerName: 'Customer',
                    outstanding: 100,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '45.50');
      await tester.enterText(find.byType(TextField).last, 'receipt-1');
      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();
      expect(result?.amount, 45.5);
      expect(result?.referenceId, 'receipt-1');
    },
  );

  testWidgets('billing table preserves long item names', (tester) async {
    const product = Product(
      id: '1',
      name: 'Family meal with a long descriptive variant name',
      description: '',
      price: 120,
      imageUrl: '',
      categoryId: '1',
    );
    final items = [
      const CartItem(product: product),
      const CartItem(product: product, quantity: 2),
    ];
    for (final width in [380.0, 900.0]) {
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: BillingItemsTable(items: items),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(product.name), findsNWidgets(2));
    }
  });
}
