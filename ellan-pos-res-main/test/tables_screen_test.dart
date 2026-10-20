import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/screens/tables_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoreTableRecord table(
  String id, {
  bool occupied = false,
  String floor = 'Ground',
}) => StoreTableRecord.fromRow({
  'table_id': id,
  'name': 'Table 1',
  'floor_name': floor,
  'occupied': occupied ? 1 : 0,
  'occupied_order_id': occupied ? 12 : null,
});

StoreOrderSummary order(int id, String tableId, double total, String status) =>
    StoreOrderSummary.fromRow({
      'order_id': id,
      'table_id': tableId,
      'final_value': total,
      'status_name': status,
    });

class OverviewController extends UiStoreController {
  List<StoreTableRecord> tables = [];
  List<StoreOrderSummary> orders = [];
  bool fail = false;

  @override
  Future<List<StoreTableRecord>> loadDineInTables() async {
    if (fail) throw StateError('Database unavailable');
    return tables;
  }

  @override
  Future<List<StoreOrderSummary>> loadOrders({String? pricingMode}) async =>
      orders;
}

void main() {
  late OverviewController controller;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    getIt.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    controller = OverviewController();
    getIt.registerSingleton<UiStoreController>(controller);
  });
  tearDown(() async => getIt.reset());

  Future<void> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TablesScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'grid shows open KOT totals, excludes closed orders and separates floors',
    (tester) async {
      controller.tables = [
        table('ground-1', occupied: true),
        table('terrace-1', floor: 'Terrace'),
      ];
      controller.orders = [
        order(12, 'ground-1', 125.50, 'KOT'),
        order(13, 'ground-1', 25, 'Pending'),
        order(14, 'ground-1', 1000, 'Completed'),
        order(15, 'ground-1', 1000, 'Cancelled'),
        order(16, 'ground-1', 1000, 'Closed'),
      ];
      await mount(tester, const Size(768, 1024));
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('150.50'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('#12 · KOT / #13 · Pending'), findsOneWidget);
      expect(find.text('Ground'), findsOneWidget);
      expect(find.text('Terrace'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grid fits phone and tablet orientations and refreshes totals', (
    tester,
  ) async {
    controller.tables = [table('ground-1', occupied: true)];
    controller.orders = [order(12, 'ground-1', 50, 'Pending')];
    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      await mount(tester, size);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
    }
    await mount(tester, const Size(360, 800));
    controller.orders = [order(12, 'ground-1', 90, 'KOT')];
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('90.00'), findsOneWidget);
    expect(find.text('50.00'), findsNothing);
    controller.tables = [table('ground-1')];
    controller.orders = [order(12, 'ground-1', 90, 'Completed')];
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
  });

  testWidgets(
    'load errors and missing occupied totals are explicit with retry',
    (tester) async {
      controller.fail = true;
      await mount(tester, const Size(360, 800));
      expect(find.text('Could not load tables.'), findsOneWidget);
      expect(find.textContaining('Database unavailable'), findsOneWidget);
      controller.fail = false;
      controller.tables = [table('ground-1', occupied: true)];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Open order details unavailable'),
        findsOneWidget,
      );
      expect(find.text('0.00'), findsNothing);
      controller.orders = [order(12, '', 45, 'Pending')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('45.00'), findsOneWidget);
    },
  );

  testWidgets('empty state explains table setup', (tester) async {
    await mount(tester, const Size(360, 800));
    expect(find.textContaining('No tables configured.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
