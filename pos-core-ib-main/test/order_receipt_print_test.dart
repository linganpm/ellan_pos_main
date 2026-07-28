import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test('store.listAvailablePrinters returns the configured printer list', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter(
      printers: const [
        StorePrinterInfo(
          id: 'magnetic-printer-01',
          name: 'Magnetic Printer 01',
          purpose: StorePrinterPurpose.customer,
          isDefault: true,
          isSimulated: true,
        ),
        StorePrinterInfo(
          id: 'counter-printer-02',
          name: 'Counter Printer 02',
          purpose: StorePrinterPurpose.kitchen,
          isSimulated: true,
        ),
      ],
    );
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final printers = await store.listAvailablePrinters();

    expect(printers.length, 2);
    expect(printers.first.id, 'magnetic-printer-01');
    expect(printers.first.isDefault, isTrue);
    expect(printers.first.isSimulated, isTrue);
    expect(printers.first.purpose, StorePrinterPurpose.customer);
    expect(printers.last.name, 'Counter Printer 02');
  });

  test('store.print sends a formatted receipt to the configured printer adapter', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter();
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Main Course 10 Percent',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.percentage,
        targetIds: ['7'],
        percentageValue: 10,
      ),
    );

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Receipt Customer',
        mobile: '9000000999',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_41',
        productId: 'prod_41',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        addons: const [
          StoreAddOrderItemAddonRequest(
            addonGroupId: 'addon_group_4',
            addonGroupName: 'Toppings',
            addonItemId: 'addon_item_2',
            addonItemName: 'Onion',
            quantity: 1,
          ),
        ],
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: createdOn,
      ),
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details, isNotNull);

    await store.orders.addPayment(
      store.scope,
      orderId,
      StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: details!.total,
        referenceId: 'CASH-01',
      ),
    );

    final result = await store.print(
      'magnetic-printer-01',
      orderId,
      templateType: StoreReceiptTemplateType.customer,
      copies: 2,
      tableLabel: 'A1',
      tokenNumber: 'TK-42',
      note: 'Less spicy',
    );

    expect(result.success, isTrue);
    expect(result.printerId, 'magnetic-printer-01');
    expect(result.command, 'simulate-print');
    expect(result.templateType, StoreReceiptTemplateType.customer);
    expect(result.copies, 2);
    expect(printerAdapter.lastJob, isNotNull);
    expect(printerAdapter.jobs.length, 2);
    expect(printerAdapter.lastJob!.orderId, orderId);
    expect(printerAdapter.lastJob!.receipt.content, contains('CUSTOMER COPY'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Copy                                   2/2'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Token'));
    expect(printerAdapter.lastJob!.receipt.content, contains('TK-42'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Table'));
    expect(printerAdapter.lastJob!.receipt.content, contains('A1'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Note'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Less spicy'));
    expect(printerAdapter.lastJob!.receipt.content, contains(store.orgName.toUpperCase()));
    expect(printerAdapter.lastJob!.receipt.content, contains(store.storeName.toUpperCase()));
    expect(printerAdapter.lastJob!.receipt.content, contains(store.uniqueId));
    expect(printerAdapter.lastJob!.receipt.content, contains('Receipt Customer'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Podi Dosai'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Onion'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Main Course 10 Percent'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Payments'));
    expect(printerAdapter.lastJob!.receipt.content, contains('cash CASH-01'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Total'));
  });

  test('console printer emits receipt content for development use', () async {
    final consoleOutput = <String>[];
    final printerAdapter = StoreSimulatedPrinterAdapter(
      consoleWriter: consoleOutput.add,
    );
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final printers = await store.listAvailablePrinters();
    expect(
      printers.any((printer) => printer.id == StoreSimulatedPrinterAdapter.consolePrinterId),
      isTrue,
    );

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Console Customer',
        mobile: '9000000555',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'console-print-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'console-print-test',
        createdOn: createdOn,
      ),
    );

    final result = await store.print(
      StoreSimulatedPrinterAdapter.consolePrinterId,
      orderId,
      note: 'Console dev test',
    );

    expect(result.success, isTrue);
    expect(result.printerId, StoreSimulatedPrinterAdapter.consolePrinterId);
    expect(consoleOutput, hasLength(1));
    expect(consoleOutput.single, contains('STORE RECEIPT CUSTOMER 1/1'));
    expect(consoleOutput.single, contains('Console Customer'));
    expect(consoleOutput.single, contains('Plain Dosai'));
    expect(consoleOutput.single, contains('Console dev test'));
  });

  test('kitchen template prints items without totals or payments', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter();
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Kitchen Customer',
        mobile: '9000000888',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: createdOn,
      ),
    );

    final result = await store.print(
      'kitchen-printer-01',
      orderId,
      templateType: StoreReceiptTemplateType.kitchen,
      tableLabel: 'K2',
      tokenNumber: 'KT-7',
      note: 'No chutney',
    );

    expect(result.templateType, StoreReceiptTemplateType.kitchen);
    expect(result.kitchenBatchNumber, 1);
    expect(printerAdapter.lastJob!.receipt.content, contains('KITCHEN COPY'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Kitchen Batch'));
    expect(printerAdapter.lastJob!.receipt.content, contains('1. Plain Dosai x1'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Token'));
    expect(printerAdapter.lastJob!.receipt.content, contains('KT-7'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Table'));
    expect(printerAdapter.lastJob!.receipt.content, contains('K2'));
    expect(printerAdapter.lastJob!.receipt.content, contains('Note'));
    expect(printerAdapter.lastJob!.receipt.content, contains('No chutney'));
    expect(printerAdapter.lastJob!.receipt.content, isNot(contains('Payments')));
    expect(printerAdapter.lastJob!.receipt.content, isNot(contains('Subtotal')));
    expect(printerAdapter.lastJob!.receipt.content, isNot(contains('Total')));
  });

  test('kitchen sends only newly added items on subsequent sends', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter();
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Kitchen Flow Customer',
        mobile: '9000000777',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: createdOn,
      ),
    );

    final firstKitchen = await store.sendToKitchen(
      'kitchen-printer-01',
      orderId,
      tokenNumber: 'KT-9',
    );
    expect(firstKitchen.kitchenBatchNumber, 1);
    expect(firstKitchen.receiptContent, contains('1. Plain Dosai x1'));

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_40',
        productId: 'prod_40',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: DateTime.now().toIso8601String(),
      ),
    );

    final secondKitchen = await store.sendToKitchen(
      'kitchen-printer-01',
      orderId,
      tokenNumber: 'KT-9',
    );
    expect(secondKitchen.kitchenBatchNumber, 2);
    expect(secondKitchen.receiptContent, contains('1. Egg Dosai x1'));
    expect(secondKitchen.receiptContent, isNot(contains('Plain Dosai x1')));

    expect(
      () => store.sendToKitchen('kitchen-printer-01', orderId),
      throwsA(isA<StorePrinterException>()),
    );
  });

  test('kitchen send tracks pending quantity deltas for the same item row', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter();
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Quantity Flow Customer',
        mobile: '9000000666',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'receipt-test',
        createdOn: createdOn,
      ),
    );

    await store.sendToKitchen('kitchen-printer-01', orderId);
    await store.orders.updateItemQuantity(store.scope, itemId, 3);

    final secondKitchen = await store.sendToKitchen('kitchen-printer-01', orderId);
    expect(secondKitchen.kitchenBatchNumber, 2);
    expect(secondKitchen.receiptContent, contains('1. Plain Dosai x2'));

    final items = await store.orders.listItems(store.scope, orderId);
    expect(items.single.kitchenSentQuantity, 3);
  });

  test('reducing sent quantity records KOT cancellation separately', () async {
    final printerAdapter = StoreSimulatedPrinterAdapter();
    final store = await openAdminLoggedInTestStore(printerAdapter: printerAdapter);
    addTearDown(store.close);

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Cancellation Flow Customer',
        mobile: '9000000555',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 3,
        createdBy: 'receipt-test',
        createdOn: createdOn,
      ),
    );

    await store.sendToKitchen('kitchen-printer-01', orderId);
    await store.orders.updateItemQuantity(store.scope, itemId, 1);

    final cancellations = await store.orders.listKitchenCancellations(store.scope, orderId);
    expect(cancellations.length, 1);
    expect(cancellations.single.orderItemId, itemId);
    expect(cancellations.single.cancelledQuantity, 2);
    expect(cancellations.single.cancelledBy, isNotEmpty);

    final items = await store.orders.listItems(store.scope, orderId);
    expect(items.single.kitchenSentQuantity, 1);
  });

  test('store.print throws when the order does not exist', () async {
    final store = await openAdminLoggedInTestStore(printerAdapter: StoreSimulatedPrinterAdapter());
    addTearDown(store.close);

    expect(
      () => store.print('magnetic-printer-01', 999999999),
      throwsA(isA<StorePrinterException>()),
    );
  });

  test('store.print throws when the requested printer is not available', () async {
    final store = await openAdminLoggedInTestStore(
      printerAdapter: StoreSimulatedPrinterAdapter(
        printers: const [
          StorePrinterInfo(
            id: 'magnetic-printer-01',
            name: 'Magnetic Printer 01',
            purpose: StorePrinterPurpose.customer,
            isDefault: true,
            isSimulated: true,
          ),
        ],
      ),
    );
    addTearDown(store.close);

    expect(
      () => store.print('missing-printer', 5512345678),
      throwsA(isA<StorePrinterException>()),
    );
  });
}