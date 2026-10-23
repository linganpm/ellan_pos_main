import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/core/pos_theme.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/data/models/order_list_model.dart';
import 'package:pos_tablet/presentation/screens/home_screen.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';
import 'package:pos_tablet/presentation/screens/tables_screen.dart';
import 'package:pos_tablet/presentation/screens/order_list_screen.dart';
import 'package:pos_tablet/presentation/widgets/order_list/order_list_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResponsiveController extends UiStoreController {
  List<PosOrderType> types = OrderTypesRepository.defaults;

  @override
  Future<List<StoreTableRecord>> loadDineInTables() async => [];

  @override
  Future<List<StoreOrderSummary>> loadOrders({String? pricingMode}) async => [];

  @override
  Future<List<PosOrderType>> loadOrderTypes() async => types;

  @override
  Future<String> resolveStaffDisplayName() async => 'Operator';
}

void main() {
  late ResponsiveController controller;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    controller = ResponsiveController();
    getIt.registerSingleton<UiStoreController>(controller);
    getIt.registerSingleton<SharedPreferences>(await SharedPreferences.getInstance());
  });
  tearDown(() async => getIt.reset());

  Future<void> mount(
    WidgetTester tester,
    Size size,
    Widget child, {
    RouteFactory? onGenerateRoute,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<UiStoreController>.value(
      value: controller,
      child: MaterialApp(
        theme: PosTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: onGenerateRoute,
        home: child,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('home and history fit phone and tablet orientations', (tester) async {
    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      await mount(tester, size, const HomeScreen());
      expect(tester.takeException(), isNull, reason: 'Home at $size');
      expect(find.byType(FloatingActionButton), findsOneWidget);
      if (size.width < 900 || size.shortestSide < 600) {
        expect(find.byType(GridView), findsOneWidget, reason: 'Home grid at $size');
      }
      expect(find.byType(ListTile), findsNothing, reason: 'Home grid at $size');
      final appBar = find.byType(AppBar);
      expect(
        find.descendant(of: appBar, matching: find.byIcon(Icons.home_rounded)),
        findsOneWidget,
        reason: 'Home icon at $size',
      );
      expect(
        find.descendant(of: appBar, matching: find.byType(PosBrandMark)),
        findsOneWidget,
        reason: 'EllanPOS icon at $size',
      );
      expect(
        find.descendant(of: appBar, matching: find.text('Lock')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appBar, matching: find.byIcon(Icons.lock_rounded)),
        findsNothing,
      );
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, size, const SalesListScreen());
      expect(tester.takeException(), isNull, reason: 'History at $size');
      expect(find.byType(PosBrandMark), findsOneWidget, reason: 'EllanPOS on sales at $size');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('home Lock opens staff unlock without logout on phone and tablet', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(1024, 768)]) {
      RouteSettings? destination;
      await mount(
        tester,
        size,
        const HomeScreen(),
        onGenerateRoute: (settings) {
          destination = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Staff unlock')),
          );
        },
      );
      if (size.width < 900) {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Logout'), findsNothing);
        expect(find.byType(PopupMenuItem<String>), findsNWidgets(6));
        Navigator.of(
          tester.element(find.byType(PopupMenuItem<String>).first),
        ).pop();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(TextButton, 'Lock'));
      await tester.pumpAndSettle();
      expect(destination?.name, AppRoutes.staffLock);
      expect(destination?.arguments, {'storeId': null, 'storeName': null});
      expect(find.text('Staff unlock'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Tables dashboard option follows dine-in setting and opens grid', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(1024, 768)]) {
      controller.types = const [PosOrderType(key: 'PICKUP', label: 'Pickup')];
      await mount(tester, size, const HomeScreen());
      expect(find.text('Tables'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.types = OrderTypesRepository.defaults;
      await mount(tester, size, const HomeScreen());
      expect(find.text('Tables'), findsOneWidget);
      await tester.ensureVisible(find.text('Tables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      expect(find.byType(TablesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('phone order card keeps all actions and hides ineligible delete', (tester) async {
    final actions = <String>[];
    Widget row({bool canDelete = true}) => Scaffold(
      body: SingleChildScrollView(
        child: OrderListRow(
          order: OrderListModel(
            id: '1',
            orderId: '1',
            orderType: 'Dine In',
            customerName: 'Customer with a long name for narrow layouts',
            timestamp: DateTime(2026, 10, 18),
            orderStatus: 'Order Pending',
            paymentStatus: 'Unpaid',
            itemCount: 0,
            totalAmount: 123456.78,
          ),
          index: 0,
          onInfoTap: () => actions.add('info'),
          onPrintTap: () => actions.add('print'),
          onUpdateTap: () => actions.add('edit'),
          onPayNowTap: () => actions.add('pay'),
          onDeleteTap: canDelete ? () => actions.add('delete') : null,
        ),
      ),
    );
    await mount(tester, const Size(360, 800), row());
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.payment_rounded));
    await tester.tap(find.byIcon(Icons.print_rounded));
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.tap(find.byKey(const ValueKey('order-row-delete-1')));
    await tester.tap(find.text('#1'));
    expect(actions, ['pay', 'print', 'edit', 'delete', 'info']);
    await mount(tester, const Size(360, 800), row(canDelete: false));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });
}
