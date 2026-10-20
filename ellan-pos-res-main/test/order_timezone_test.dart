import 'package:flutter_test/flutter_test.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/order_list/order_list_bloc.dart';
import 'package:pos_tablet/bloc/order_list/order_list_event.dart';
import 'package:pos_tablet/bloc/order_list/order_list_state.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimezoneController extends UiStoreController {
  TimezoneController(this.tz, this.createdOn);

  final String tz;
  final String createdOn;

  @override
  String? get orgTimezoneName => tz;

  @override
  Future<List<PosOrderType>> loadOrderTypes() async =>
      OrderTypesRepository.defaults;

  @override
  Future<List<StoreOrderSummary>> loadOrders({String? pricingMode}) async => [
    StoreOrderSummary(
      orgId: 'org',
      storeId: 'store',
      uniqueId: 'u1',
      localId: 'L1',
      remoteId: null,
      orderId: 55001,
      restaurantName: '',
      statusName: 'Completed',
      pricingMode: 'dine_in',
      totalValue: 10,
      offerAppliedValue: 0,
      finalValue: 10,
      total: 10,
      createdOn: createdOn,
      exported: true,
      lastImportedAt: null,
      lastExportedAt: null,
    ),
  ];
}

Future<DateTime> _listedTime(String tz, String createdOn) async {
  final bloc = OrderListBloc(controller: TimezoneController(tz, createdOn));
  bloc.add(FetchInitialOrders());
  final state = await bloc.stream.firstWhere((s) => s is OrderListLoaded);
  await bloc.close();
  return (state as OrderListLoaded).orders.single.timestamp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('order list shows UTC order time in the org timezone', () async {
    final kolkata = await _listedTime('Asia/Kolkata', '2026-10-18T13:45:00Z');
    expect(kolkata, DateTime(2026, 10, 18, 19, 15));

    final newYork = await _listedTime(
      'America/New_York',
      '2026-10-18T13:45:00Z',
    );
    expect(newYork, DateTime(2026, 10, 18, 9, 45));
  });

  test('naive device-local order time is converted to the org timezone', () {
    final deviceLocal = DateTime(2026, 10, 18, 12, 0);
    final expected = OrgTimezone.toWallClock(deviceLocal, 'Asia/Tokyo');
    expect(
      OrgTimezone.tryParseWallClock(
        deviceLocal.toIso8601String(),
        'Asia/Tokyo',
      ),
      expected,
    );
  });
}
