import 'package:flutter/material.dart';
import 'package:pos_tablet/core/pos_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/cart/cart_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/screens/invoice_screen.dart';
import 'package:pos_tablet/presentation/screens/order_payments_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoreOrderDetails creditOrder(double cash) {
  final payments = [
    if (cash > 0)
      StoreOrderPaymentRecord.fromRow({
        'id': 1,
        'payment_mode': 'cash',
        'amount': cash,
      }),
    StoreOrderPaymentRecord.fromRow({
      'id': 2,
      'payment_mode': 'credit',
      'amount': 100 - cash,
    }),
  ];
  return StoreOrderDetails(
    orgId: 'org',
    storeId: 'store',
    id: 1,
    uniqueId: null,
    localId: 'order',
    remoteId: null,
    orderId: 42,
    restaurantName: 'Store',
    customerName: 'Buyer',
    mobile: '',
    customerUniqueId: 'buyer',
    statusName: 'Closed',
    totalValue: 100,
    offerAppliedValue: 0,
    finalValue: 100,
    total: 100,
    serviceInstance: 1,
    createdBy: '',
    createdOn: '2026-10-20T09:00:00Z',
    paymentStatus: cash > 0 ? 'Partial' : 'Unpaid',
    orderType: 'PICKUP',
    pricingMode: 'selling',
    subtotal: 100,
    totalDiscount: 0,
    tables: [],
    items: [],
    appliedOffers: [],
    payments: payments,
    exported: false,
    lastImportedAt: null,
    lastExportedAt: null,
  );
}

class CreditController extends UiStoreController {
  late StoreOrderDetails order;

  @override
  Future<StoreOrderDetails?> loadOrder(int orderId) async => order;

  @override
  Future<List<StoreOrderPaymentRecord>> loadOrderPayments(int orderId) async =>
      order.payments;
}

void main() {
  late CreditController controller;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    controller = CreditController();
    getIt.registerSingleton<UiStoreController>(controller);
  });
  tearDown(() async => getIt.reset());

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final cash in [0.0, 30.0]) {
    testWidgets('payments summary excludes credit with $cash received', (
      tester,
    ) async {
      controller.order = creditOrder(cash);
      await mount(tester, const OrderPaymentsScreen(orderId: 42));
      final context = tester.element(find.byType(OrderPaymentsScreen));
      final l10n = AppLocalizations.of(context)!;
      expect(
        find.text(
          l10n.orderPaymentsOrderSummary(
            PosCurrency.format(100),
            PosCurrency.format(100 - cash),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(PosCurrency.format(cash)), findsWidgets);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
      'invoice shows only $cash received and the outstanding credit',
      (tester) async {
        final bloc = CartBloc();
        addTearDown(bloc.close);
        await mount(
          tester,
          BlocProvider.value(
            value: bloc,
            child: InvoiceScreen(
              checkoutResult: CheckoutCompletionResult(
                orderId: 42,
                totalPaid: cash,
                paymentMode: 'credit',
                statusName: 'Closed',
                restaurantName: 'Store',
                paymentStatus: cash == 0 ? 'Unpaid' : 'Partial',
                balanceDue: 100 - cash,
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(InvoiceScreen));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(l10n.invoiceAmountPaid), findsOneWidget);
        expect(find.text(l10n.commonRemaining), findsOneWidget);
        expect(find.text(PosCurrency.format(cash)), findsWidgets);
        expect(find.text(PosCurrency.format(100 - cash)), findsWidgets);
      },
    );
  }
}
