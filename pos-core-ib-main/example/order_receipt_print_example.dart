import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<String> _resolveVariantName(Store store, String productVariantId) async {
  final variants = await store.products.searchDetails(
    scope: store.scope,
    limit: 500,
  );
  for (final variant in variants) {
    if (variant.localId == productVariantId) {
      return variant.productVariantName.isEmpty ? productVariantId : variant.productVariantName;
    }
  }
  return productVariantId;
}

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final printer = StoreSimulatedPrinterAdapter();
  final store = await Store.createForTest(
    config: config,
    printerAdapter: printer,
  );

  try {
    final session = await store.auth.login(
      store.scope,
      StoreLoginRequest(
        email: config.defaultLogin.email,
        password: config.defaultLogin.password,
      ),
    );
    if (session == null) {
      throw StateError('Login failed for receipt print example.');
    }

    final printers = await store.listAvailablePrinters();
    if (printers.isEmpty) {
      throw StateError('No printers are available for the receipt print example.');
    }
    final selectedPrinter = printers.firstWhere(
      (printerInfo) => printerInfo.id == StoreSimulatedPrinterAdapter.consolePrinterId,
      orElse: () => printers.firstWhere(
        (printerInfo) => printerInfo.isDefault,
        orElse: () => printers.first,
      ),
    );
    final kitchenPrinter = printers.firstWhere(
      (printerInfo) => printerInfo.purpose == StorePrinterPurpose.kitchen,
      orElse: () => printers.last,
    );

    print('Available printers:');
    for (final printerInfo in printers) {
      final defaultLabel = printerInfo.isDefault ? ' default' : '';
      final simulatedLabel = printerInfo.isSimulated ? ' simulated' : '';
      print('- ${printerInfo.id}: ${printerInfo.name} purpose=${printerInfo.purpose}$defaultLabel$simulatedLabel');
    }
    print('Customer receipt printer: ${selectedPrinter.id}');
    print('Kitchen receipt printer: ${kitchenPrinter.id}');

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Printer Demo Customer',
        mobile: '9000001234',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'receipt-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final dosaiItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        quantity: 1,
        createdBy: 'receipt-example',
        createdOn: createdOn,
      ),
    );

    final firstKitchenResult = await store.sendToKitchen(
      kitchenPrinter.id,
      orderId,
      tableLabel: 'A3',
      tokenNumber: 'TK-108',
      note: 'First send',
    );
    print('Simulated kitchen print for order ${firstKitchenResult.orderId} to ${firstKitchenResult.printerId}.');
    print(firstKitchenResult.message);
    print('--- KITCHEN RECEIPT BATCH ${firstKitchenResult.kitchenBatchNumber} START ---');
    print(firstKitchenResult.receiptContent);
    print('--- KITCHEN RECEIPT BATCH ${firstKitchenResult.kitchenBatchNumber} END ---');

    await store.orders.updateItemQuantity(store.scope, dosaiItemId, 3);

    final quantityDeltaKitchenResult = await store.sendToKitchen(
      kitchenPrinter.id,
      orderId,
      tableLabel: 'A3',
      tokenNumber: 'TK-108',
      note: 'Quantity increased',
    );
    print('Simulated kitchen print for order ${quantityDeltaKitchenResult.orderId} to ${quantityDeltaKitchenResult.printerId}.');
    print(quantityDeltaKitchenResult.message);
    print('--- KITCHEN RECEIPT BATCH ${quantityDeltaKitchenResult.kitchenBatchNumber} START ---');
    print(quantityDeltaKitchenResult.receiptContent);
    print('--- KITCHEN RECEIPT BATCH ${quantityDeltaKitchenResult.kitchenBatchNumber} END ---');

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_40',
        productId: 'prod_40',
        quantity: 1,
        createdBy: 'receipt-example',
        createdOn: DateTime.now().toIso8601String(),
      ),
    );

    final kitchenResult = await store.sendToKitchen(
      kitchenPrinter.id,
      orderId,
      tableLabel: 'A3',
      tokenNumber: 'TK-108',
      note: 'Second send',
    );
    print('Simulated kitchen print for order ${kitchenResult.orderId} to ${kitchenResult.printerId}.');
    print(kitchenResult.message);
    print('--- KITCHEN RECEIPT BATCH ${kitchenResult.kitchenBatchNumber} START ---');
    print(kitchenResult.receiptContent);
    print('--- KITCHEN RECEIPT BATCH ${kitchenResult.kitchenBatchNumber} END ---');

    await store.orders.updateItemQuantity(store.scope, dosaiItemId, 1);
    final cancellations = await store.orders.listKitchenCancellations(store.scope, orderId);
    print('KOT cancellations:');
    for (final cancellation in cancellations) {
      final itemName = await _resolveVariantName(store, cancellation.productVariantId);
      print(
        '- orderId=${cancellation.orderId} item=$itemName qty=${cancellation.cancelledQuantity} cancelledBy=${cancellation.cancelledBy ?? 'unknown'} sourceBatch=${cancellation.sourceKitchenBatch} note=${cancellation.note ?? ''}',
      );
    }

    final details = await store.orders.details(store.scope, orderId);
    if (details == null) {
      throw StateError('Order details were not found for receipt print example.');
    }

    await store.orders.addPayment(
      store.scope,
      orderId,
      StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: details.total,
        referenceId: 'CASH-DEMO',
      ),
    );

    final customerResult = await store.print(
      selectedPrinter.id,
      orderId,
      templateType: StoreReceiptTemplateType.customer,
      copies: 2,
      tableLabel: 'A3',
      tokenNumber: 'TK-108',
      note: 'Serve hot',
    );
    print('Simulated print for order ${customerResult.orderId} to ${customerResult.printerId}.');
    print(customerResult.message);
    print('--- CUSTOMER RECEIPT START ---');
    print(customerResult.receiptContent);
    print('--- CUSTOMER RECEIPT END ---');

    print('Captured jobs: ${printer.jobs.length}');
  } finally {
    await store.auth.logout();
    await store.close();
  }
}