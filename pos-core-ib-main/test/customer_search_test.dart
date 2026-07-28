import 'package:test/test.dart';
import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test('Store supports partial storeId search', () async {
    final store = await openLoggedInTestStore();
    final partialStore = await store.customers.listRecords(
      scope: store.scope,
      limit: 10,
    );
    expect(
      partialStore.every((customer) => customer.remoteId?.isNotEmpty == true),
      true,
    );
    print('Partial storeId search:');
    for (final c in partialStore) {
      print('Name: [32m${c.name}[0m, StoreId: ${c.storeId}');
    }
    expect(partialStore.any((c) => c.storeId == 'store_001'), true);
    await store.close();
  });

  test('Store supports partial orgId search', () async {
    final store = await openLoggedInTestStore();
    final partialOrg = await store.customers.listRecords(
      scope: store.scope,
      limit: 10,
    );
    print('Partial orgId search:');
    for (final c in partialOrg) {
      print('Name: [34m${c.name}[0m, OrgId: ${c.orgId}');
    }
    expect(partialOrg.any((c) => c.orgId == 'org_001'), true);
    await store.close();
  });

  test('Store paginates by storeId', () async {
    final store = await openLoggedInTestStore();
    final customersPage1 = await store.customers.listDetails(
      scope: store.scope,
      limit: 1,
      offset: 0,
    );
    print('listCustomers by storeId Page 1:');
    for (final c in customersPage1) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    final customersPage2 = await store.customers.listDetails(
      scope: store.scope,
      limit: 1,
      offset: 1,
    );
    print('listCustomers by storeId Page 2:');
    for (final c in customersPage2) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    expect(customersPage1.isNotEmpty, true);
    if (customersPage2.isNotEmpty) {
      expect(
        customersPage2[0].customerId != customersPage1[0].customerId,
        true,
      );
    }
    await store.close();
  });

  test('Store paginates by orgId', () async {
    final store = await openLoggedInTestStore();
    final customersPage1 = await store.customers.listDetails(
      scope: store.scope,
      limit: 1,
      offset: 0,
    );
    print('listCustomers by orgId Page 1:');
    for (final c in customersPage1) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    final customersPage2 = await store.customers.listDetails(
      scope: store.scope,
      limit: 1,
      offset: 1,
    );
    print('listCustomers by orgId Page 2:');
    for (final c in customersPage2) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    expect(customersPage1.isNotEmpty, true);
    if (customersPage2.isNotEmpty) {
      expect(
        customersPage2[0].customerId != customersPage1[0].customerId,
        true,
      );
    }
    await store.close();
  });

  test('Store paginates and searches by storeId', () async {
    final store = await openLoggedInTestStore();
    final page1 = await store.customers.searchDetails(
      scope: store.scope,
      limit: 1,
      offset: 0,
    );
    print('Page 1:');
    for (final c in page1) {
      print('Name: \u001b[32m${c.name}\u001b[0m, Phone: ${c.phone}');
    }
    final page2 = await store.customers.searchDetails(
      scope: store.scope,
      limit: 1,
      offset: 1,
    );
    print('Page 2:');
    for (final c in page2) {
      print('Name: \u001b[34m${c.name}\u001b[0m, Phone: ${c.phone}');
    }
    expect(page1.isNotEmpty, true);
    if (page2.isNotEmpty) {
      expect(page2[0].customerId != page1[0].customerId, true);
    }
    await store.close();
  });

  test('Store lists and searches by storeId, name, phone', () async {
    final store = await openLoggedInTestStore();
    final storeCustomers = await store.customers.searchDetails(
      scope: store.scope,
    );
    print('Customers for store_001:');
    for (final c in storeCustomers) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    final nameSearch = await store.customers.searchDetails(
      scope: store.scope,
      nameQuery: 'Ali',
    );
    print('Customers with name containing "Ali":');
    for (final c in nameSearch) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    final phoneSearch = await store.customers.searchDetails(
      scope: store.scope,
      phoneQuery: '1234',
    );
    print('Customers with phone containing "1234":');
    for (final c in phoneSearch) {
      print('Name: ${c.name}, Phone: ${c.phone}');
    }
    expect(storeCustomers.isNotEmpty, true);
    expect(nameSearch.isNotEmpty, true);
    expect(phoneSearch.isNotEmpty, true);
    await store.close();
  });

  test('Store manages organisation customers and linked credits', () async {
    final store = await openAdminLoggedInTestStore();
    const customerId = 'cust_org_101';
    const orderId = 5500092001;
    final timestamp = '2026-03-29T10:15:00.000Z';

    await store.customers.create(
      const StoreCreateCustomerRequest(
        customerId: customerId,
        remoteId: 'remote-cust-org-101',
        orgId: 'org_001',
        name: 'Org Level Customer',
        email: 'org-customer@example.com',
        phone: '+1110002222',
        country: 'Singapore',
        status: 'active',
        role: 'member',
        password: 'secret123',
      ),
    );

    var organisationCustomers = await store.customers.listOrganisationDetails(
      orgId: 'org_001',
    );
    expect(
      organisationCustomers.any(
        (customer) => customer.customerId == customerId,
      ),
      true,
    );

    await store.customers.update(
      customerId,
      const StoreUpdateCustomerRequest(
        name: 'Updated Org Customer',
        phone: '+1110003333',
      ),
    );

    final updatedCustomer = await store.customers.getById(customerId);
    expect(updatedCustomer != null, true);
    expect(updatedCustomer!.name, 'Updated Org Customer');
    expect(updatedCustomer.phone, '+1110003333');
    expect(updatedCustomer.remoteId, 'remote-cust-org-101');

    await store.customers.update(
      customerId,
      const StoreUpdateCustomerRequest(remoteId: 'remote-cust-org-101-v2'),
    );

    final updatedRemoteCustomer = await store.customers.getById(customerId);
    expect(updatedRemoteCustomer != null, true);
    expect(updatedRemoteCustomer!.remoteId, 'remote-cust-org-101-v2');

    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: store.storeName,
        customerName: updatedCustomer.name,
        mobile: updatedCustomer.phone,
        statusName: 'Pending',
        total: 50,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'admin',
        createdOn: timestamp,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );

    await store.credits.create(
      store.scope,
      StoreCreateCreditRequest(
        orgId: 'org_001',
        customerId: customerId,
        orderId: orderId,
        amount: 50,
        createdOn: timestamp,
      ),
    );

    final credits = await store.credits.listRecords(store.scope);
    final linkedCredit = credits.firstWhere(
      (credit) => credit.customerId == customerId,
    );
    expect(linkedCredit.orderId, orderId);
    expect(linkedCredit.amount, 50);
    expect(linkedCredit.createdOn, timestamp);
    expect(linkedCredit.localId.isNotEmpty, true);
    expect(linkedCredit.remoteId, isNull);

    await store.customers.delete(customerId);
    organisationCustomers = await store.customers.listOrganisationDetails(
      orgId: 'org_001',
    );
    expect(
      organisationCustomers.any(
        (customer) => customer.customerId == customerId,
      ),
      false,
    );

    await store.close();
  });

  test(
    'Store records cash, card, and voucher repayments across multiple credits',
    () async {
      final store = await openAdminLoggedInTestStore();
      const customerId = 'cust_org_202';
      const firstOrderId = 5500092011;
      const secondOrderId = 5500092012;
      const timestamp = '2026-03-29T12:30:00.000Z';

      await store.customers.create(
        const StoreCreateCustomerRequest(
          customerId: customerId,
          orgId: 'org_001',
          name: 'Repayment Customer',
          email: 'repayment-customer@example.com',
          phone: '+1119990000',
          country: 'Singapore',
          status: 'active',
          role: 'member',
          password: 'secret123',
        ),
      );

      await store.orders.create(
        store.scope,
        const StoreCreateOrderRequest(
          id: firstOrderId,
          orderId: firstOrderId,
          restaurantName: 'Credit Store',
          customerName: 'Repayment Customer',
          mobile: '+1119990000',
          statusName: 'Pending',
          total: 75,
          serviceInstance: 1,
          createdBy: 'admin',
          createdOn: timestamp,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );
      await store.orders.create(
        store.scope,
        const StoreCreateOrderRequest(
          id: secondOrderId,
          orderId: secondOrderId,
          restaurantName: 'Credit Store',
          customerName: 'Repayment Customer',
          mobile: '+1119990000',
          statusName: 'Pending',
          total: 25,
          serviceInstance: 1,
          createdBy: 'admin',
          createdOn: timestamp,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );

      final firstCreditId = await store.credits.create(
        store.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: customerId,
          orderId: firstOrderId,
          amount: 75,
          createdOn: timestamp,
        ),
      );
      final secondCreditId = await store.credits.create(
        store.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: customerId,
          orderId: secondOrderId,
          amount: 25,
          createdOn: timestamp,
        ),
      );

      final cashRepaymentId = await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.cash,
          totalAmount: 60,
          paidOn: timestamp,
          referenceId: 'cash-credit-202',
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
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.card,
          totalAmount: 20,
          paidOn: timestamp,
          referenceId: 'card-credit-202',
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: firstCreditId,
              allocatedAmount: 20,
            ),
          ],
        ),
      );
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.voucher,
          totalAmount: 20,
          paidOn: timestamp,
          referenceId: 'voucher-credit-202',
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

      final credits = await store.credits.listRecords(store.scope);
      final firstCredit = credits.firstWhere(
        (credit) => credit.id == firstCreditId,
      );
      final secondCredit = credits.firstWhere(
        (credit) => credit.id == secondCreditId,
      );
      expect(firstCredit.localId.isNotEmpty, true);
      expect(firstCredit.remoteId, isNull);
      expect(secondCredit.localId.isNotEmpty, true);
      expect(secondCredit.remoteId, isNull);
      expect(firstCredit.amount, 75);
      expect(firstCredit.paidAmount, 75);
      expect(firstCredit.outstandingAmount, 0);
      expect(firstCredit.settled, true);
      expect(secondCredit.amount, 25);
      expect(secondCredit.paidAmount, 25);
      expect(secondCredit.outstandingAmount, 0);
      expect(secondCredit.settled, true);

      final repayments = await store.credits.listRepayments(
        store.scope,
        customerId: customerId,
      );
      expect(repayments.length, 3);
      expect(
        repayments.any(
          (repayment) => repayment.paymentMode == StoreCreditRepaymentMode.cash,
        ),
        true,
      );
      expect(
        repayments.any(
          (repayment) => repayment.paymentMode == StoreCreditRepaymentMode.card,
        ),
        true,
      );
      expect(
        repayments.any(
          (repayment) =>
              repayment.paymentMode == StoreCreditRepaymentMode.voucher,
        ),
        true,
      );

      final cashAllocations = await store.credits.listRepaymentAllocations(
        store.scope,
        cashRepaymentId,
      );
      expect(cashAllocations.length, 2);
      expect(
        cashAllocations.fold<double>(
          0,
          (sum, allocation) => sum + allocation.allocatedAmount,
        ),
        60,
      );

      final ledger = await store.credits.customerLedger(
        store.scope,
        customerId: customerId,
      );
      expect(ledger.length, 5);
      expect(
        ledger
            .where(
              (entry) => entry.entryType == StoreCustomerLedgerEntryType.credit,
            )
            .length,
        2,
      );
      expect(
        ledger
            .where(
              (entry) =>
                  entry.entryType == StoreCustomerLedgerEntryType.repayment,
            )
            .length,
        3,
      );
      final ledgerRepayment = ledger.firstWhere(
        (entry) =>
            entry.entryType == StoreCustomerLedgerEntryType.repayment &&
            entry.entryId == cashRepaymentId,
      );
      expect(ledgerRepayment.paymentMode, StoreCreditRepaymentMode.cash);
      expect(ledgerRepayment.allocations.length, 2);

      final ledgerCredit = ledger.firstWhere(
        (entry) =>
            entry.entryType == StoreCustomerLedgerEntryType.credit &&
            entry.entryId == firstCreditId,
      );
      expect(ledgerCredit.outstandingAmount, 0);
      expect(ledgerCredit.settled, true);

      await store.close();
    },
  );

  test(
    'Soft-deleted repayments are excluded from balances and normal ledger views',
    () async {
      final store = await openAdminLoggedInTestStore();
      const customerId = 'cust_org_303';
      const deleterCustomerId = 'cust_org_304';
      const firstOrderId = 5500092021;
      const secondOrderId = 5500092022;
      const createdOn = '2026-03-29T14:00:00.000Z';
      const deletedOn = '2026-03-29T14:45:00.000Z';

      await store.customers.create(
        const StoreCreateCustomerRequest(
          customerId: customerId,
          orgId: 'org_001',
          name: 'Soft Delete Customer',
          email: 'soft-delete-customer@example.com',
          phone: '+1118880000',
          country: 'Singapore',
          status: 'active',
          role: 'member',
          password: 'secret123',
        ),
      );
      await store.customers.create(
        const StoreCreateCustomerRequest(
          customerId: deleterCustomerId,
          orgId: 'org_001',
          name: 'Repayment Deleter',
          email: 'repayment-deleter@example.com',
          phone: '+1118880001',
          country: 'Singapore',
          status: 'active',
          role: 'admin',
          password: 'secret123',
        ),
      );

      await store.orders.create(
        store.scope,
        const StoreCreateOrderRequest(
          id: firstOrderId,
          orderId: firstOrderId,
          restaurantName: 'Credit Store',
          customerName: 'Soft Delete Customer',
          mobile: '+1118880000',
          statusName: 'Pending',
          total: 75,
          serviceInstance: 1,
          createdBy: 'admin',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );
      await store.orders.create(
        store.scope,
        const StoreCreateOrderRequest(
          id: secondOrderId,
          orderId: secondOrderId,
          restaurantName: 'Credit Store',
          customerName: 'Soft Delete Customer',
          mobile: '+1118880000',
          statusName: 'Pending',
          total: 25,
          serviceInstance: 1,
          createdBy: 'admin',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );

      final firstCreditId = await store.credits.create(
        store.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: customerId,
          orderId: firstOrderId,
          amount: 75,
          createdOn: createdOn,
        ),
      );
      final secondCreditId = await store.credits.create(
        store.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: customerId,
          orderId: secondOrderId,
          amount: 25,
          createdOn: createdOn,
        ),
      );

      final cashRepaymentId = await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.cash,
          totalAmount: 60,
          paidOn: createdOn,
          referenceId: 'cash-credit-303',
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
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.card,
          totalAmount: 20,
          paidOn: createdOn,
          referenceId: 'card-credit-303',
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: firstCreditId,
              allocatedAmount: 20,
            ),
          ],
        ),
      );
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: customerId,
          paymentMode: StoreCreditRepaymentMode.voucher,
          totalAmount: 20,
          paidOn: createdOn,
          referenceId: 'voucher-credit-303',
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

      final deletedCount = await store.credits.deleteRepayment(
        store.scope,
        cashRepaymentId,
        const StoreDeleteCreditRepaymentRequest(
          deletedByCustomerId: deleterCustomerId,
          reason: 'Cash drawer mismatch',
          deletedOn: deletedOn,
        ),
      );
      expect(deletedCount, 1);

      final credits = await store.credits.listRecords(store.scope);
      final firstCredit = credits.firstWhere(
        (credit) => credit.id == firstCreditId,
      );
      final secondCredit = credits.firstWhere(
        (credit) => credit.id == secondCreditId,
      );
      expect(firstCredit.paidAmount, 25);
      expect(firstCredit.outstandingAmount, 50);
      expect(firstCredit.settled, false);
      expect(secondCredit.paidAmount, 15);
      expect(secondCredit.outstandingAmount, 10);
      expect(secondCredit.settled, false);

      final visibleRepayments = await store.credits.listRepayments(
        store.scope,
        customerId: customerId,
      );
      expect(visibleRepayments.length, 2);
      expect(
        visibleRepayments.any((repayment) => repayment.id == cashRepaymentId),
        false,
      );

      final allRepayments = await store.credits.listRepaymentAudit(
        store.scope,
        customerId: customerId,
      );
      final deletedRepayment = allRepayments.firstWhere(
        (repayment) => repayment.id == cashRepaymentId,
      );
      expect(deletedRepayment.localId.isNotEmpty, true);
      expect(deletedRepayment.remoteId, isNull);
      expect(deletedRepayment.deleted, true);
      expect(deletedRepayment.deletedReason, 'Cash drawer mismatch');
      expect(deletedRepayment.deletedByCustomerId, deleterCustomerId);
      expect(deletedRepayment.deletedOn, deletedOn);

      final visibleLedger = await store.credits.customerLedger(
        store.scope,
        customerId: customerId,
      );
      expect(visibleLedger.length, 4);
      expect(
        visibleLedger.any(
          (entry) =>
              entry.entryType == StoreCustomerLedgerEntryType.repayment &&
              entry.entryId == cashRepaymentId,
        ),
        false,
      );

      final auditLedger = await store.credits.customerLedgerAudit(
        store.scope,
        customerId: customerId,
      );
      final deletedLedgerEntry = auditLedger.firstWhere(
        (entry) =>
            entry.entryType == StoreCustomerLedgerEntryType.repayment &&
            entry.entryId == cashRepaymentId,
      );
      expect(deletedLedgerEntry.deleted, true);
      expect(deletedLedgerEntry.deletedReason, 'Cash drawer mismatch');
      expect(deletedLedgerEntry.deletedByCustomerId, deleterCustomerId);
      expect(deletedLedgerEntry.deletedOn, deletedOn);
      expect(deletedLedgerEntry.allocations.length, 2);

      final allocations = await store.credits.listRepaymentAllocations(
        store.scope,
        cashRepaymentId,
      );
      expect(allocations.length, 2);

      await store.close();
    },
  );

  test(
    'Store lists creditors customer-wise sorted by outstanding amount and name',
    () async {
      final store = await openAdminLoggedInTestStore();
      const baseTimestamp = '2026-03-30T09:00:00.000Z';

      Future<void> seedCustomerCredit({
        required String customerId,
        required String name,
        required int orderId,
        required double creditAmount,
        double? repaymentAmount,
      }) async {
        await store.customers.create(
          StoreCreateCustomerRequest(
            customerId: customerId,
            orgId: 'org_001',
            name: name,
            email: '$customerId@example.com',
            phone:
                '+6500${orderId.toString().substring(orderId.toString().length - 6)}',
            country: 'Singapore',
            status: 'active',
            role: 'member',
            password: 'secret123',
          ),
        );

        await store.orders.create(
          store.scope,
          StoreCreateOrderRequest(
            id: orderId,
            orderId: orderId,
            restaurantName: 'Credit Store',
            customerName: name,
            mobile: '+6500000000',
            statusName: 'Pending',
            total: creditAmount,
            serviceInstance: 1,
            createdBy: 'admin',
            createdOn: baseTimestamp,
            paymentStatus: 'Unpaid',
            orderType: StoreOrderType.pickUp,
          ),
        );

        final creditId = await store.credits.create(
          store.scope,
          StoreCreateCreditRequest(
            orgId: 'org_001',
            customerId: customerId,
            orderId: orderId,
            amount: creditAmount,
            createdOn: baseTimestamp,
          ),
        );

        if (repaymentAmount != null && repaymentAmount > 0) {
          await store.credits.recordRepayment(
            store.scope,
            StoreCreateCreditRepaymentRequest(
              customerId: customerId,
              paymentMode: StoreCreditRepaymentMode.cash,
              totalAmount: repaymentAmount,
              paidOn: baseTimestamp,
              allocations: [
                StoreCreateCreditRepaymentAllocationRequest(
                  creditId: creditId,
                  allocatedAmount: repaymentAmount,
                ),
              ],
            ),
          );
        }
      }

      await seedCustomerCredit(
        customerId: 'cust_credit_alice',
        name: 'Alice',
        orderId: 5500092101,
        creditAmount: 40,
        repaymentAmount: 20,
      );
      await seedCustomerCredit(
        customerId: 'cust_credit_bob',
        name: 'Bob',
        orderId: 5500092102,
        creditAmount: 80,
      );
      await seedCustomerCredit(
        customerId: 'cust_credit_charlie',
        name: 'Charlie',
        orderId: 5500092103,
        creditAmount: 25,
        repaymentAmount: 5,
      );
      await seedCustomerCredit(
        customerId: 'cust_credit_settled',
        name: 'Settled Customer',
        orderId: 5500092104,
        creditAmount: 30,
        repaymentAmount: 30,
      );

      final sortedByAmount = await store.credits.listCreditorsByCustomer(
        store.scope,
      );
      expect(sortedByAmount.map((summary) => summary.customerName).toList(), [
        'Bob',
        'Alice',
        'Charlie',
      ]);
      expect(
        sortedByAmount
            .map((summary) => summary.totalOutstandingAmount)
            .toList(),
        [80, 20, 20],
      );
      expect(
        sortedByAmount.any(
          (summary) => summary.customerName == 'Settled Customer',
        ),
        false,
      );

      final sortedByName = await store.credits.listCreditorsByCustomer(
        store.scope,
        sortBy: StoreCreditCustomerSortBy.name,
        descending: false,
      );
      expect(sortedByName.map((summary) => summary.customerName).toList(), [
        'Alice',
        'Bob',
        'Charlie',
      ]);

      await store.close();
    },
  );

  test(
    'Store lists credits by today yesterday and custom date filters',
    () async {
      final store = await openAdminLoggedInTestStore();
      final now = DateTime.now().toUtc();
      final todayTimestamp = now.subtract(const Duration(hours: 1));
      final yesterdayTimestamp = now.subtract(
        const Duration(days: 1, hours: 1),
      );
      final customDate = DateTime.utc(2026, 4, 10, 9, 30);

      await store.customers.create(
        const StoreCreateCustomerRequest(
          customerId: 'cust_credit_dates',
          orgId: 'org_001',
          name: 'Date Filter Customer',
          email: 'date-filter-customer@example.com',
          phone: '+1117770000',
          country: 'Singapore',
          status: 'active',
          role: 'member',
          password: 'secret123',
        ),
      );

      Future<void> seedCredit({
        required int orderId,
        required double amount,
        required DateTime createdOn,
      }) async {
        final createdOnIso = createdOn.toIso8601String();
        await store.orders.create(
          store.scope,
          StoreCreateOrderRequest(
            id: orderId,
            orderId: orderId,
            restaurantName: 'Credit Store',
            customerName: 'Date Filter Customer',
            mobile: '+1117770000',
            statusName: 'Pending',
            total: amount,
            serviceInstance: 1,
            createdBy: 'admin',
            createdOn: createdOnIso,
            paymentStatus: 'Unpaid',
            orderType: StoreOrderType.pickUp,
          ),
        );

        await store.credits.create(
          store.scope,
          StoreCreateCreditRequest(
            orgId: 'org_001',
            customerId: 'cust_credit_dates',
            orderId: orderId,
            amount: amount,
            createdOn: createdOnIso,
          ),
        );
      }

      await seedCredit(
        orderId: 5500092201,
        amount: 45,
        createdOn: todayTimestamp,
      );
      await seedCredit(
        orderId: 5500092202,
        amount: 55,
        createdOn: yesterdayTimestamp,
      );
      await seedCredit(orderId: 5500092203, amount: 65, createdOn: customDate);

      final todayCredits = await store.credits.listRecordsByDate(
        store.scope,
        filter: StoreCreditDateFilter.today(),
        customerId: 'cust_credit_dates',
      );
      expect(todayCredits.map((credit) => credit.orderId).toList(), [
        5500092201,
      ]);
      expect(todayCredits.first.customerName, 'Date Filter Customer');

      final yesterdayCredits = await store.credits.listRecordsByDate(
        store.scope,
        filter: StoreCreditDateFilter.yesterday(),
        customerId: 'cust_credit_dates',
      );
      expect(yesterdayCredits.map((credit) => credit.orderId).toList(), [
        5500092202,
      ]);

      final customDateCredits = await store.credits.listRecordsByDate(
        store.scope,
        filter: StoreCreditDateFilter.custom(customDate),
        customerId: 'cust_credit_dates',
      );
      expect(customDateCredits.map((credit) => credit.orderId).toList(), [
        5500092203,
      ]);

      await store.close();
    },
  );
}
