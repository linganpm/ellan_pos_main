import 'package:pos_orders_offline/pos_orders_offline.dart';

Future<void> main() async {
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';

  final organisation = await Store.resolveOrganisationByCodeFromUrl(
    orgCode,
    lookupUrl: discoveryUrl,
  );
  if (organisation == null) {
    throw StateError('Organisation lookup failed');
  }

  final config = await StoreConfig.loadRemoteForOrganisation(
    orgCode: orgCode,
    lookupUrl: discoveryUrl,
  );
  final bootstrap = await Store.syncOrganisationBootstrap(
    orgCode: orgCode,
    config: config,
  );
  if (bootstrap == null || bootstrap.stores.isEmpty) {
    throw StateError('Bootstrap failed');
  }

  final login = await Store.loginToOrganisation(
    orgCode: bootstrap.organisation.orgCode,
    email: 'charlie@example.com',
    password: 'charliepass',
    config: config,
  );
  if (login == null) {
    throw StateError('Organisation login failed');
  }
  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'example-device-003',
    make: 'Linux',
    model: 'Customer Credit Example',
    lat: 0,
    lan: 0,
  );
  await Store.registerDeviceForOrganisation(
    orgId: bootstrap.organisation.orgId,
    request: deviceRegistration,
    config: config,
  );

  final store = await Store.openAccessibleStore(
    login: login,
    storeId: bootstrap.stores.first.storeId,
    deviceRegistration: deviceRegistration,
    config: config,
  );

  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );

  try {
    final now = DateTime.now().toUtc();
    final todayTimestamp = now.toIso8601String();
    final yesterdayTimestamp = now
        .subtract(const Duration(days: 1))
        .toIso8601String();
    final customDate = DateTime.utc(2026, 4, 10, 9, 30);
    final customTimestamp = customDate.toIso8601String();

    Future<(int, int)> createCreditForCustomer({
      required String customerId,
      required String customerName,
      required String customerPhone,
      required double amount,
      required String createdOn,
    }) async {
      final orderId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: customerName,
          mobile: customerPhone,
          statusName: 'Pending',
          total: amount,
          serviceInstance: store.serviceInstanceId,
          createdBy: 'customer-credit-example',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );
      final creditId = await store.credits.create(
        store.scope,
        StoreCreateCreditRequest(
          orgId: store.orgId,
          customerId: customerId,
          orderId: orderId,
          amount: amount,
          createdOn: createdOn,
        ),
      );
      return (orderId, creditId);
    }

    final customerId = await store.customers.create(
      StoreCreateCustomerRequest(
        name: 'Demo Org Customer',
        email: 'demo-org-customer@example.com',
        phone: '+6500000001',
        country: 'Singapore',
        status: 'active',
        role: 'member',
        password: 'demo123',
      ),
    );
    print('Created organisation-level customer $customerId');

    var organisationCustomers = await store.customers.listOrganisationDetails(
      orgId: store.orgId,
    );
    print('Organisation customer count: ${organisationCustomers.length}');

    await store.customers.update(
      customerId,
      const StoreUpdateCustomerRequest(
        name: 'Updated Demo Customer',
        phone: '+6500000002',
      ),
    );

    final updatedCustomer = await store.customers.getById(customerId);
    print(
      'Updated customer: ${updatedCustomer?.name} phone=${updatedCustomer?.phone}',
    );

    final yesterdayCustomerId = await store.customers.create(
      StoreCreateCustomerRequest(
        name: 'Yesterday Credit Customer',
        email: 'yesterday-credit-customer@example.com',
        phone: '+6500000010',
        country: 'Singapore',
        status: 'active',
        role: 'member',
        password: 'demo123',
      ),
    );
    final customDateCustomerId = await store.customers.create(
      StoreCreateCustomerRequest(
        name: 'Custom Date Customer',
        email: 'custom-date-customer@example.com',
        phone: '+6500000011',
        country: 'Singapore',
        status: 'active',
        role: 'member',
        password: 'demo123',
      ),
    );

    final (firstOrderId, firstCreditId) = await createCreditForCustomer(
      customerId: customerId,
      customerName: updatedCustomer?.name ?? 'Unknown',
      customerPhone: updatedCustomer?.phone ?? '',
      amount: 75,
      createdOn: todayTimestamp,
    );
    final (secondOrderId, secondCreditId) = await createCreditForCustomer(
      customerId: customerId,
      customerName: updatedCustomer?.name ?? 'Unknown',
      customerPhone: updatedCustomer?.phone ?? '',
      amount: 25,
      createdOn: todayTimestamp,
    );
    final (yesterdayOrderId, yesterdayCreditId) = await createCreditForCustomer(
      customerId: yesterdayCustomerId,
      customerName: 'Yesterday Credit Customer',
      customerPhone: '+6500000010',
      amount: 40,
      createdOn: yesterdayTimestamp,
    );
    final (customOrderId, customCreditId) = await createCreditForCustomer(
      customerId: customDateCustomerId,
      customerName: 'Custom Date Customer',
      customerPhone: '+6500000011',
      amount: 30,
      createdOn: customTimestamp,
    );
    print(
      'Created orders $firstOrderId, $secondOrderId, $yesterdayOrderId, $customOrderId',
    );

    var credits = await store.credits.listRecords(store.scope);
    print('Credits created:');
    for (final credit in credits.where(
      (credit) =>
          credit.id == firstCreditId ||
          credit.id == secondCreditId ||
          credit.id == yesterdayCreditId ||
          credit.id == customCreditId,
    )) {
      print(
        'Credit ${credit.id}: customer=${credit.customerName} localId=${credit.localId} remoteId=${credit.remoteId} order=${credit.orderId} amount=${credit.amount} outstanding=${credit.outstandingAmount} datetime=${credit.createdOn}',
      );
    }

    final cashRepaymentId = await store.credits.recordRepayment(
      store.scope,
      StoreCreateCreditRepaymentRequest(
        customerId: customerId,
        paymentMode: StoreCreditRepaymentMode.cash,
        totalAmount: 60,
        paidOn: todayTimestamp,
        referenceId: 'cash-repay-001',
        allocations: [
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: firstCreditId,
            allocatedAmount: 50,
          ),
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: secondCreditId,
            allocatedAmount: 10,
          ),
        ],
      ),
    );
    final cardRepaymentId = await store.credits.recordRepayment(
      store.scope,
      StoreCreateCreditRepaymentRequest(
        customerId: customerId,
        paymentMode: StoreCreditRepaymentMode.card,
        totalAmount: 20,
        paidOn: todayTimestamp,
        referenceId: 'card-repay-001',
        allocations: [
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: firstCreditId,
            allocatedAmount: 20,
          ),
        ],
      ),
    );
    final voucherRepaymentId = await store.credits.recordRepayment(
      store.scope,
      StoreCreateCreditRepaymentRequest(
        customerId: customerId,
        paymentMode: StoreCreditRepaymentMode.voucher,
        totalAmount: 20,
        paidOn: todayTimestamp,
        referenceId: 'voucher-repay-001',
        allocations: [
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: firstCreditId,
            allocatedAmount: 5,
          ),
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: secondCreditId,
            allocatedAmount: 15,
          ),
        ],
      ),
    );

    final deletedByCustomerId = await store.customers.create(
      StoreCreateCustomerRequest(
        name: 'Demo Ledger Admin',
        email: 'demo-ledger-admin@example.com',
        phone: '+6500000003',
        country: 'Singapore',
        status: 'active',
        role: 'admin',
        password: 'demo123',
      ),
    );

    await store.credits.deleteRepayment(
      store.scope,
      cashRepaymentId,
      StoreDeleteCreditRepaymentRequest(
        deletedByCustomerId: deletedByCustomerId,
        reason: 'Cash reconciliation mismatch',
      ),
    );

    credits = await store.credits.listRecords(store.scope);
    print('Credits after deleting the cash repayment:');
    for (final credit in credits.where(
      (credit) => credit.customerId == customerId,
    )) {
      print(
        'Credit ${credit.id}: amount=${credit.amount} paid=${credit.paidAmount} outstanding=${credit.outstandingAmount} settled=${credit.settled}',
      );
    }

    final creditorsByAmount = await store.credits.listCreditorsByCustomer(
      store.scope,
    );
    print('Creditors by customer sorted by outstanding amount:');
    for (final creditor in creditorsByAmount) {
      print(
        'Customer ${creditor.customerName}: credits=${creditor.creditCount} total=${creditor.totalCreditAmount} paid=${creditor.totalPaidAmount} outstanding=${creditor.totalOutstandingAmount}',
      );
    }

    final creditorsByName = await store.credits.listCreditorsByCustomer(
      store.scope,
      sortBy: StoreCreditCustomerSortBy.name,
      descending: false,
    );
    print('Creditors by customer sorted by name:');
    for (final creditor in creditorsByName) {
      print(
        'Customer ${creditor.customerName}: outstanding=${creditor.totalOutstandingAmount} latest=${creditor.latestCreditOn}',
      );
    }

    Future<void> printCreditsForFilter(
      String label,
      StoreCreditDateFilter filter,
    ) async {
      final filteredCredits = await store.credits.listRecordsByDate(
        store.scope,
        filter: filter,
      );
      print('Credits for $label:');
      for (final credit in filteredCredits) {
        print(
          'Credit ${credit.id}: customer=${credit.customerName} order=${credit.orderId} amount=${credit.amount} createdOn=${credit.createdOn}',
        );
      }
    }

    await printCreditsForFilter('today', StoreCreditDateFilter.today());
    await printCreditsForFilter('yesterday', StoreCreditDateFilter.yesterday());
    await printCreditsForFilter(
      'custom date ${customDate.toIso8601String().split('T').first}',
      StoreCreditDateFilter.custom(customDate),
    );

    final repayments = await store.credits.listRepayments(
      store.scope,
      customerId: customerId,
    );
    print('Active repayments:');
    for (final repayment in repayments) {
      print(
        'Repayment ${repayment.id}: localId=${repayment.localId} remoteId=${repayment.remoteId} mode=${repayment.paymentMode} total=${repayment.totalAmount} paidOn=${repayment.paidOn} ref=${repayment.referenceId}',
      );
    }

    final repaymentsWithDeleted = await store.credits.listRepaymentAudit(
      store.scope,
      customerId: customerId,
    );
    print('Repayments including deleted entries:');
    for (final repayment in repaymentsWithDeleted) {
      print(
        'Repayment ${repayment.id}: mode=${repayment.paymentMode} total=${repayment.totalAmount} deleted=${repayment.deleted} deletedBy=${repayment.deletedByCustomerId} reason=${repayment.deletedReason}',
      );
    }

    for (final repaymentId in [
      cashRepaymentId,
      cardRepaymentId,
      voucherRepaymentId,
    ]) {
      final allocations = await store.credits.listRepaymentAllocations(
        store.scope,
        repaymentId,
      );
      for (final allocation in allocations) {
        print(
          'Allocation: repayment=${allocation.repaymentId} credit=${allocation.creditId} amount=${allocation.allocatedAmount}',
        );
      }
    }

    final ledger = await store.credits.customerLedger(
      store.scope,
      customerId: customerId,
    );
    print('Customer ledger timeline (active only):');
    for (final entry in ledger) {
      if (entry.entryType == StoreCustomerLedgerEntryType.credit) {
        print(
          'Ledger credit ${entry.entryId}: order=${entry.orderId} amount=${entry.amount} outstanding=${entry.outstandingAmount} settled=${entry.settled}',
        );
      } else {
        print(
          'Ledger repayment ${entry.entryId}: mode=${entry.paymentMode} amount=${entry.amount} ref=${entry.referenceId}',
        );
        for (final allocation in entry.allocations) {
          print(
            '  allocated credit=${allocation.creditId} amount=${allocation.allocatedAmount}',
          );
        }
      }
    }

    final auditLedger = await store.credits.customerLedgerAudit(
      store.scope,
      customerId: customerId,
    );
    print('Customer ledger timeline (including deleted repayments):');
    for (final entry in auditLedger.where(
      (entry) => entry.entryType == StoreCustomerLedgerEntryType.repayment,
    )) {
      print(
        'Audit repayment ${entry.entryId}: amount=${entry.amount} deleted=${entry.deleted} deletedBy=${entry.deletedByCustomerId} reason=${entry.deletedReason}',
      );
    }

    await store.customers.delete(customerId);
    await store.customers.delete(yesterdayCustomerId);
    await store.customers.delete(customDateCustomerId);
    await store.customers.delete(deletedByCustomerId);
    organisationCustomers = await store.customers.listOrganisationDetails(
      orgId: store.orgId,
    );
    print(
      'Deleted customer. Remaining org customer count: ${organisationCustomers.length}',
    );
  } finally {
    await store.auth.logout();
    await store.close();
  }
}
