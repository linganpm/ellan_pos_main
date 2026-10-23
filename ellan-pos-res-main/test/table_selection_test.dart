import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_tablet/core/pos_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/order_creation/order_creation_bloc.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/screens/order_create_screen.dart';
import 'package:pos_tablet/presentation/widgets/order_creation_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoreTableRecord table(
  String id, {
  bool booked = false,
  String floor = 'ground',
}) {
  return StoreTableRecord(
    id: 1,
    orgId: 'org',
    storeId: 'store',
    tableId: id,
    floorId: floor,
    floorName: floor == 'ground' ? 'Ground' : 'Terrace',
    name: 'Table 1',
    capacity: 4,
    sortingOrder: 0,
    active: true,
    occupied: booked,
    occupiedOrderId: booked ? 12 : null,
    occupiedOrderStatus: booked ? 'Pending' : null,
  );
}

class TableController extends UiStoreController {
  List<StoreTableRecord> tables = [];
  Object? failure;
  Completer<List<StoreTableRecord>>? pending;
  int loads = 0;

  @override
  Future<PosCatalogue> loadCatalogue() async =>
      const PosCatalogue(categories: [], products: []);

  @override
  Future<Map<String, String>> loadProductOfferTags() async => {};

  @override
  Future<List<PosOrderType>> loadOrderTypes() async => const [
    PosOrderType(key: 'DINEIN', label: 'Dine-In'),
  ];

  @override
  Future<List<StoreTableRecord>> loadDineInTables() async {
    loads++;
    if (failure != null) throw StateError('$failure');
    if (pending != null) return pending!.future;
    return tables;
  }
}

void main() {
  late TableController controller;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    controller = TableController();
    getIt.registerSingleton<UiStoreController>(controller);
  });

  tearDown(() async => getIt.reset());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider(
            create: (_) => OrderCreationBloc(),
            child: const OrderCreationBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  InkWell tile(WidgetTester tester, String id) =>
      tester.widget<InkWell>(find.byKey(ValueKey('dine-in-table-$id')));

  testWidgets('booked tables are visible but cannot be selected', (
    tester,
  ) async {
    controller.tables = [table('booked', booked: true), table('free')];
    await mount(tester);
    expect(find.text('Booked'), findsOneWidget);
    expect(tile(tester, 'booked').onTap, isNull);
    expect(tile(tester, 'free').onTap, isNotNull);
    final before = controller.loads;
    await tester.tap(find.byKey(const ValueKey('dine-in-table-booked')));
    await tester.pumpAndSettle();
    expect(controller.loads, before);
    expect(find.byType(OrderCreationBottomSheet), findsOneWidget);
  });

  testWidgets('same labels on different floors use distinct table IDs', (
    tester,
  ) async {
    controller.tables = [
      table('ground-1', booked: true),
      table('terrace-1', floor: 'terrace'),
    ];
    await mount(tester);
    expect(tile(tester, 'ground-1').onTap, isNull);
    await tester.tap(find.text('Terrace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dine-in-table-ground-1')), findsNothing);
    expect(tile(tester, 'terrace-1').onTap, isNotNull);
  });

  testWidgets(
    'a free table opens checkout using its stable ID, not its label',
    (tester) async {
      controller.tables = [table('terrace-1', floor: 'terrace')];
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOrderCreationBottomSheet(context),
                child: const Text('Open table picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open table picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dine-in-table-terrace-1')));
      await tester.pumpAndSettle();
      final screen = tester.widget<OrderCreateScreen>(
        find.byType(OrderCreateScreen),
      );
      expect(screen.args.resolvedTableId, 'terrace-1');
      expect(screen.args.table, 'Table 1');
      expect(screen.args.floor, 'Terrace');
      expect(find.byType(OrderCreationBottomSheet), findsNothing);
    },
  );

  testWidgets('tap rechecks occupancy and refuses a newly booked table', (
    tester,
  ) async {
    controller.tables = [table('free'), table('other')];
    await mount(tester);
    controller.tables = [table('free', booked: true), table('other')];
    await tester.tap(find.byKey(const ValueKey('dine-in-table-free')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This table is no longer available. Please select another table.',
      ),
      findsOneWidget,
    );
    expect(tile(tester, 'free').onTap, isNull);
    expect(tile(tester, 'other').onTap, isNotNull);
    expect(find.byType(OrderCreationBottomSheet), findsOneWidget);
  });

  testWidgets('refresh enables a table released by a closed order', (
    tester,
  ) async {
    controller.tables = [table('booked', booked: true)];
    await mount(tester);
    controller.tables = [table('booked')];
    await tester.tap(find.byTooltip('Refresh table availability'));
    await tester.pumpAndSettle();
    expect(tile(tester, 'booked').onTap, isNotNull);
    expect(find.text('Booked'), findsNothing);
  });

  testWidgets('load failure is explicit and can be retried', (tester) async {
    controller.failure = 'Table database unavailable';
    await mount(tester);
    expect(find.textContaining('Table database unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('dine-in-table-free')), findsNothing);
    controller.failure = null;
    controller.tables = [table('free')];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tile(tester, 'free').onTap, isNotNull);
  });

  testWidgets('dine-in opens checkout with no table', (tester) async {
    controller.tables = [table('free')];
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOrderCreationBottomSheet(context),
              child: const Text('Open table picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open table picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dine-in-without-table')));
    await tester.pumpAndSettle();
    final screen = tester.widget<OrderCreateScreen>(
      find.byType(OrderCreateScreen),
    );
    expect(screen.args.orderType, 'Dine-In');
    expect(screen.args.resolvedTableId, isNull);
    expect(screen.args.table, isNull);
    expect(screen.args.floor, isNull);
    expect(find.byType(OrderCreationBottomSheet), findsNothing);
  });

  testWidgets('empty floor plan does not invent selectable tables', (
    tester,
  ) async {
    await mount(tester);
    expect(
      find.text(
        "No tables configured. Sync or configure the store's floors and tables.",
      ),
      findsOneWidget,
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byKey(const ValueKey('dine-in-table-1')), findsNothing);
  });

  testWidgets('refresh disables stale tiles until the query completes', (
    tester,
  ) async {
    controller.tables = [table('free')];
    await mount(tester);
    controller.pending = Completer<List<StoreTableRecord>>();
    await tester.tap(find.byTooltip('Refresh table availability'));
    await tester.pump();
    expect(tile(tester, 'free').onTap, isNull);
    controller.pending!.complete([table('free', booked: true)]);
    await tester.pumpAndSettle();
    expect(tile(tester, 'free').onTap, isNull);
    expect(find.text('Booked'), findsOneWidget);
  });

  testWidgets('a failed tap-time check disables stale availability', (
    tester,
  ) async {
    controller.tables = [table('free')];
    await mount(tester);
    controller.failure = 'Table database unavailable';
    await tester.tap(find.byKey(const ValueKey('dine-in-table-free')));
    await tester.pumpAndSettle();
    expect(tile(tester, 'free').onTap, isNull);
    expect(find.textContaining('Table database unavailable'), findsOneWidget);
    expect(find.byType(OrderCreationBottomSheet), findsOneWidget);
  });

  test('stable table ID survives draft roundtrip separately from label', () {
    const args = CartDraftArgs(
      orderType: 'Dine-In',
      table: 'Table 1',
      tableId: 'terrace-1',
      floor: 'Terrace',
      openOrderId: 12,
    );
    final restored = CartDraftArgs.fromJson(args.toJson());
    final order = OrderCreateScreenArgs(
      orderType: restored.orderType,
      table: restored.table,
      tableId: restored.tableId,
    ).withPricingMode('selling');
    expect(order.resolvedTableId, 'terrace-1');
    expect(order.table, 'Table 1');
    expect(restored.openOrderId, 12);
    expect(
      OrderCreateScreenArgs(
        orderType: 'Dine-In',
        table: 'legacy',
      ).resolvedTableId,
      'legacy',
    );
  });
}
