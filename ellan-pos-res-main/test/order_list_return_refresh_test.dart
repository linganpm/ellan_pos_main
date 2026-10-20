import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/core/order_list_route_observer.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/presentation/screens/order_details_screen.dart';
import 'package:pos_tablet/presentation/screens/order_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RefreshTrackingController extends UiStoreController {
  int loadCount = 0;

  @override
  Future<List<StoreOrderSummary>> loadOrders({String? pricingMode}) async {
    loadCount++;
    return [
      StoreOrderSummary(
        orgId: 'org',
        storeId: 'store',
        uniqueId: 'order-1',
        localId: 'local-1',
        remoteId: null,
        orderId: 55001,
        restaurantName: 'Store',
        statusName: 'Completed',
        pricingMode: 'selling',
        totalValue: 100,
        offerAppliedValue: 0,
        finalValue: 100,
        total: 100,
        createdOn: '2026-10-18T13:45:00Z',
        exported: true,
        lastImportedAt: null,
        lastExportedAt: null,
      ),
    ];
  }

  @override
  Future<List<PosOrderType>> loadOrderTypes() async =>
      OrderTypesRepository.defaults;
}

void main() {
  late RefreshTrackingController controller;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    controller = RefreshTrackingController();
    getIt.registerSingleton<UiStoreController>(controller);
    getIt.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
  });

  tearDown(() async => getIt.reset());

  testWidgets('sales history reloads after returning from a detail route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [orderListRouteObserver],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-sales'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const OrderListScreen(
                    pricingMode: 'selling',
                    title: 'Sales',
                  ),
                ),
              ),
              child: const Text('Open sales'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-sales')));
    await tester.pumpAndSettle();
    expect(controller.loadCount, 1);

    await tester.tap(find.text('#55001'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(controller.loadCount, 2);
    expect(tester.takeException(), isNull);
  });
}
