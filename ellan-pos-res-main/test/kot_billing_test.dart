import 'package:flutter/material.dart';
import 'package:pos_tablet/core/pos_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/cart/cart_bloc.dart';
import 'package:pos_tablet/bloc/cart/cart_event.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/data/models/cart_discount_line.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
import 'package:pos_tablet/data/models/product_model.dart';
import 'package:pos_tablet/presentation/screens/billing_summary_screen.dart';
import 'package:pos_tablet/presentation/screens/invoice_screen.dart';
import 'package:pos_tablet/presentation/screens/order_create_screen.dart';
import 'package:pos_tablet/presentation/widgets/checkout_footer_buttons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const product = Product(
  id: 'tea',
  name: 'Tea',
  description: '',
  price: 100,
  imageUrl: '',
  categoryId: 'all',
);
const snapshot = CartDraftSnapshot(
  items: [CartItem(product: product, quantity: 2)],
  discounts: [
    CartDiscountLine(id: 'discount', title: 'Discount', percentage: 10),
  ],
  serviceTaxPercentage: 5,
  tipsAmount: 7,
  deliveryCharge: 8,
);

class BillingController extends UiStoreController {
  int kotCalls = 0;
  bool failKot = false;
  int? checkoutOrderId;
  String? checkoutTableId;
  List<CheckoutLineItem>? billedItems;
  List<CheckoutPaymentLine>? billedPayments;
  double? billedTips;
  double? billedDiscount;

  @override
  Future<PosCatalogue> loadCatalogue() async =>
      const PosCatalogue(categories: [], products: []);

  @override
  Future<Map<String, String>> loadProductOfferTags() async => {};

  @override
  Future<({double amount, List<String> labels})> previewCartOffers(
    List<CheckoutLineItem> items,
  ) async => (amount: 3.0, labels: ['Offer']);

  @override
  Future<List<StoreWalletRecord>> loadWallets({
    bool includeInactive = false,
  }) async => [
    StoreWalletRecord.fromRow({
      'id': 1,
      'local_id': 'cash',
      'label': 'Cash',
      'payment_mode': 'cash',
    }),
  ];

  @override
  Future<KotSendResult> sendKotFromCart({
    int? existingOrderId,
    required List<CheckoutLineItem> items,
    required String orderType,
    String pricingMode = 'selling',
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUniqueId,
    String? tableId,
    double tipsAmount = 0,
    double serviceTaxAmount = 0,
    double discountAmount = 0,
    double deliveryCharge = 0,
  }) async {
    kotCalls++;
    if (failKot) throw StateError('Kitchen printer unavailable');
    return const KotSendResult(orderId: 42, batchNumber: 1, itemsMarked: 1);
  }

  @override
  Future<CheckoutCompletionResult> completeCheckout({
    required List<CheckoutLineItem> items,
    required List<CheckoutPaymentLine> payments,
    required String orderType,
    String pricingMode = 'selling',
    int? existingOrderId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUniqueId,
    String? tableId,
    String? creditCustomerId,
    double tipsAmount = 0,
    double serviceTaxAmount = 0,
    double discountAmount = 0,
    double offerAmount = 0,
    double deliveryCharge = 0,
  }) async {
    checkoutOrderId = existingOrderId;
    checkoutTableId = tableId;
    billedItems = items;
    billedPayments = payments;
    billedTips = tipsAmount;
    billedDiscount = discountAmount;
    return CheckoutCompletionResult(
      orderId: existingOrderId!,
      totalPaid: payments.fold(0, (sum, p) => sum + p.amount),
      paymentMode: 'cash',
      statusName: 'Closed',
      restaurantName: 'Test store',
    );
  }
}

void main() {
  late BillingController controller;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    controller = BillingController();
    getIt.registerSingleton<UiStoreController>(controller);
  });
  tearDown(() async => getIt.reset());

  test('KOT retains the billable basket and all adjustments', () async {
    final bloc = CartBloc();
    addTearDown(bloc.close);
    final loaded = bloc.stream.firstWhere(
      (state) => !state.isLoading && state.offerAppliedAmount == 3,
    );
    bloc.add(const LoadInitialData(draft: snapshot));
    await loaded;
    final before = bloc.state;
    final sent = bloc.stream.firstWhere(
      (state) => state.orderHistory.isNotEmpty,
    );
    bloc.add(const MarkCartKotSent(orderId: 42, batchNumber: 1));
    final after = await sent;
    expect(after.cartItems.single.quantity, 2);
    expect(after.cartItems.single.kotSentQuantity, 2);
    expect(after.cartItems.single.pendingKotQuantity, 0);
    expect(after.discounts, before.discounts);
    expect(after.serviceTaxPercentage, before.serviceTaxPercentage);
    expect(after.offerAppliedAmount, before.offerAppliedAmount);
    expect(after.tipsAmount, before.tipsAmount);
    expect(after.deliveryCharge, before.deliveryCharge);
    expect(after.netTotal, before.netTotal);
    expect(after.orderHistory.single.orderId, 42);
    expect(after.isHistoryTabActive, isTrue);

    final extended = bloc.stream.firstWhere(
      (state) => state.cartItems.single.quantity == 3,
    );
    bloc.add(const AddProductToCart(product));
    final more = await extended;
    expect(more.cartItems.single.kotSentQuantity, 2);
    expect(more.cartItems.single.pendingKotQuantity, 1);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1600, 1800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepositoryProvider<UiStoreController>.value(
        value: controller,
        child: MaterialApp(
          theme: PosTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OrderCreateScreen(
            args: OrderCreateScreenArgs(
              orderType: 'Dine-In',
              orderTypeKey: 'DINEIN',
              table: 'Table 1',
              tableId: 'ground-1',
              draftSnapshot: snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone order can switch to its cart and billing payment panel',
    (tester) async {
      await mount(tester, size: const Size(390, 844));
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(Tab, 'Order'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('BILL'));
      await tester.tap(find.text('BILL'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(Tab, 'Payments'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Exact'), findsOneWidget);
    },
  );

  testWidgets(
    'KOT history can bill the same order and reach its paid invoice',
    (tester) async {
      await mount(tester);
      final cart = BlocProvider.of<CartBloc>(
        tester.element(find.byType(CheckoutFooterButtons)),
      );
      final originalTotal = cart.state.netTotal;
      await tester.tap(find.text('KOT'));
      await tester.pumpAndSettle();
      expect(controller.kotCalls, 1);
      expect(cart.state.isHistoryTabActive, isTrue);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'KOT'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'BILL'))
            .onPressed,
        isNotNull,
      );
      final drafts = await CartDraftStore.list();
      expect(drafts.single.args.openOrderId, 42);
      expect(drafts.single.items.single.kotSentQuantity, 2);
      await tester.tap(find.text('BILL'));
      await tester.pumpAndSettle();
      final billing = tester.widget<BillingSummaryScreen>(
        find.byType(BillingSummaryScreen),
      );
      expect(billing.orderArgs.openOrderId, 42);
      expect(cart.state.netTotal, originalTotal);
      await tester.tap(find.text('Exact'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'COMPLETE'));
      await tester.pumpAndSettle();
      expect(controller.checkoutOrderId, 42);
      expect(controller.checkoutTableId, 'ground-1');
      expect(controller.billedItems!.single.quantity, 2);
      expect(controller.billedTips, 7);
      expect(controller.billedDiscount, cart.state.discountValue);
      expect(controller.billedPayments!.single.amount, originalTotal);
      final invoice = tester.widget<InvoiceScreen>(find.byType(InvoiceScreen));
      expect(invoice.checkoutResult!.orderId, 42);
      expect(invoice.checkoutResult!.statusName, 'Closed');
      expect(await CartDraftStore.list(), isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a failed KOT keeps items billable without marking them as sent',
    (tester) async {
      controller.failKot = true;
      await mount(tester);
      await tester.tap(find.text('KOT'));
      await tester.pumpAndSettle();
      final cart = BlocProvider.of<CartBloc>(
        tester.element(find.byType(CheckoutFooterButtons)),
      );
      expect(cart.state.cartItems.single.pendingKotQuantity, 2);
      expect(cart.state.orderHistory, isEmpty);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'BILL'))
            .onPressed,
        isNotNull,
      );
      expect(
        find.textContaining('Kitchen printer unavailable'),
        findsOneWidget,
      );
    },
  );
}
