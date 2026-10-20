import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  late Store store;
  late String customerId;
  const now = '2026-10-20T09:00:00Z';

  setUp(() async {
    store = await openAdminLoggedInTestStore();
    customerId = (await store.auth.currentCustomer())!.customerId;
  });
  tearDown(() => store.close());

  Future<int> order({
    required double cash,
    required double credit,
    String pricingMode = StoreOrderPricingMode.selling,
  }) async {
    final id = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Credit test',
        customerName: 'Customer',
        mobile: '1234567890',
        customerUniqueId: customerId,
        statusName: 'Pending',
        total: 100,
        serviceInstance: 1,
        createdBy: 'test',
        createdOn: now,
        paymentStatus: 'Paid',
        orderType: StoreOrderType.pickUp,
        pricingMode: pricingMode,
      ),
    );
    await store.orders.setAmounts(
      store.scope,
      id,
      totalValue: 100,
      offerAppliedValue: 0,
      finalValue: 100,
    );
    for (final tender in [
      (StoreOrderPaymentMode.cash, cash),
      (StoreOrderPaymentMode.credit, credit),
    ]) {
      if (tender.$2 == 0) continue;
      await store.orders.addPayment(
        store.scope,
        id,
        StoreCreateOrderPaymentRequest(
          paymentMode: tender.$1,
          amount: tender.$2,
          customerId: tender.$1 == StoreOrderPaymentMode.credit
              ? customerId
              : null,
        ),
      );
    }
    if (credit > 0) {
      await store.credits.create(
        store.scope,
        StoreCreateCreditRequest(
          orgId: store.orgId,
          customerId: customerId,
          orderId: id,
          amount: credit,
          createdOn: now,
        ),
      );
    }
    await store.orders.close(store.scope, id);
    return id;
  }

  Future<void> verify(int id, double paid, double due, String status) async {
    final summary = (await store.orders.listSummaries(
      store.scope,
    )).singleWhere((row) => row.orderId == id);
    final details = (await store.orders.getById(store.scope, id))!;
    expect(summary.paidTotal, paid);
    expect(summary.balanceDue, due);
    expect(summary.paymentStatus, status);
    expect(details.paidTotal, paid);
    expect(details.balanceDue, due);
    expect(details.paymentStatus, status);
    expect(details.statusName, 'Closed');
  }

  test(
    'legacy Paid credit sale stays closed but is unpaid in summaries',
    () async {
      final id = await order(cash: 0, credit: 100);
      await verify(id, 0, 100, 'Unpaid');
    },
  );

  test('split cash and credit only reports money received as paid', () async {
    final id = await order(cash: 30, credit: 70);
    await verify(id, 30, 70, 'Partial');
  });

  test('cash-only order remains fully paid', () async {
    final id = await order(cash: 100, credit: 0);
    await verify(id, 100, 0, 'Paid');
  });

  test(
    'credit-funded purchase stays closed without reporting payment',
    () async {
      final id = await order(
        cash: 0,
        credit: 100,
        pricingMode: StoreOrderPricingMode.buying,
      );
      await verify(id, 0, 100, 'Unpaid');
    },
  );

  test(
    'cash refunds reduce receipts without counting credit as money',
    () async {
      final id = await order(cash: 30, credit: 70);
      final payment = (await store.orders.listPayments(
        store.scope,
        id,
      )).singleWhere((row) => !row.isCredit);
      await store.orders.addRefund(
        store.scope,
        id,
        StoreCreateOrderRefundRequest(
          paymentId: payment.id,
          amount: 10,
          reason: 'Partial refund',
        ),
      );
      await verify(id, 20, 80, 'Partial');
    },
  );

  test(
    'repayment allocations increase received totals; deletion restores debt',
    () async {
      final id = await order(cash: 30, credit: 70);
      final credits = await store.credits.listRecords(
        store.scope,
        customerId: customerId,
      );
      final credit = credits.singleWhere((row) => row.orderId == id);
      final repaymentId = await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: 'cash',
          totalAmount: 20,
          paidOn: now,
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: credit.id,
              allocatedAmount: 20,
            ),
          ],
        ),
      );
      await verify(id, 50, 50, 'Partial');
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: 'card',
          totalAmount: 50,
          paidOn: now,
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: credit.id,
              allocatedAmount: 50,
            ),
          ],
        ),
      );
      await verify(id, 100, 0, 'Paid');
      await store.credits.deleteRepayment(
        store.scope,
        repaymentId,
        StoreDeleteCreditRepaymentRequest(
          deletedByCustomerId: customerId,
          reason: 'Reversed duplicate receipt',
        ),
      );
      await verify(id, 80, 20, 'Partial');
    },
  );
}
