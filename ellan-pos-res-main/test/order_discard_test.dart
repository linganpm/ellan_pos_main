import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/cart/cart_event.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
import 'package:pos_tablet/data/models/order_list_model.dart';
import 'package:pos_tablet/data/models/product_model.dart';
import 'package:pos_tablet/presentation/screens/order_create_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const product = Product(
  id: 'tea',
  name: 'Tea',
  description: '',
  price: 100,
  imageUrl: '',
  categoryId: 'all',
);

class DiscardController extends UiStoreController {
  final discarded = <int>[];
  bool cancelInsteadOfDelete = false;

  @override
  Future<PosCatalogue> loadCatalogue() async =>
      const PosCatalogue(categories: [], products: []);

  @override
  Future<Map<String, String>> loadProductOfferTags() async => {};

  @override
  Future<({double amount, List<String> labels})> previewCartOffers(
    List<CheckoutLineItem> items,
  ) async => (amount: 0.0, labels: const <String>[]);

  @override
  Future<bool> discardOrder(int orderId) async {
    discarded.add(orderId);
    await CartDraftStore.deleteForOrder(orderId);
    return !cancelInsteadOfDelete;
  }
}

void main() {
  late DiscardController controller;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    controller = DiscardController();
    getIt.registerSingleton<UiStoreController>(controller);
  });
  tearDown(() async => getIt.reset());

  Future<void> mount(WidgetTester tester, OrderCreateScreenArgs args) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepositoryProvider<UiStoreController>.value(
        value: controller,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderCreateScreen(args: args),
                    ),
                  ),
                  child: const Text('open order'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open order'));
    await tester.pumpAndSettle();
  }

  testWidgets('fresh empty order is dismissed without creating anything', (
    tester,
  ) async {
    await mount(
      tester,
      OrderCreateScreenArgs(orderType: 'Dine-In', tableId: 'ground-1'),
    );
    expect(find.byType(OrderCreateScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('order-create-delete')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(OrderCreateScreen), findsNothing);
    expect(controller.discarded, isEmpty);
  });

  testWidgets(
    'emptied KOT order is discarded, its draft removed and table freed',
    (tester) async {
      final draft = await CartDraftStore.save(
        args: const CartDraftArgs(
          orderType: 'Dine-In',
          tableId: 'ground-1',
          openOrderId: 42,
        ),
        items: const [CartItem(product: product, quantity: 1)],
        discounts: const [],
        serviceTaxPercentage: 0,
        tipsAmount: 0,
        deliveryCharge: 0,
        netTotal: 100,
      );
      // Restored with the cart already emptied by the user.
      await mount(
        tester,
        OrderCreateScreenArgs(
          orderType: 'Dine-In',
          tableId: 'ground-1',
          draftId: draft.id,
          openOrderId: 42,
          draftSnapshot: const CartDraftSnapshot(
            items: [],
            discounts: [],
            serviceTaxPercentage: 0,
            tipsAmount: 0,
            deliveryCharge: 0,
          ),
        ),
      );

      final delete = tester.widget<IconButton>(
        find.byKey(const ValueKey('order-create-delete')),
      );
      expect(delete.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('order-create-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete order?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(controller.discarded, [42]);
      expect(await CartDraftStore.list(), isEmpty);
      expect(find.byType(OrderCreateScreen), findsNothing);
      expect(find.text('Order deleted. Table is free.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  test('order list only offers delete for unpaid empty open orders', () {
    OrderListModel row({
      String status = 'Pending',
      int items = 0,
      double paid = 0,
    }) => OrderListModel(
      id: '1',
      orderId: '1',
      orderType: 'Dine-In',
      customerName: 'Walk-in',
      timestamp: DateTime(2026),
      orderStatus: status,
      paymentStatus: 'Unpaid',
      itemCount: items,
      totalAmount: 0,
      paidTotal: paid,
    );

    expect(row().canDiscard, isTrue);
    expect(row(status: 'Draft', items: 3).canDiscard, isTrue);
    expect(row(items: 2).canDiscard, isFalse);
    expect(row(paid: 10).canDiscard, isFalse);
    expect(row(status: 'Closed').canDiscard, isFalse);
    expect(row(status: 'Cancelled').canDiscard, isFalse);
    expect(StoreOrderStatus.canCancel('Pending'), isTrue);
  });
}
