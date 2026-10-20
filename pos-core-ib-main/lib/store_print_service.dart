part of 'store.dart';

abstract class StorePrinterAdapter {
  const StorePrinterAdapter();

  Future<List<StorePrinterInfo>> listAvailablePrinters();

  Future<StorePrintResult> print(StorePrintJob job);
}

class StoreReceiptTemplateType {
  static const String customer = 'customer';
  static const String kitchen = 'kitchen';

  static const Set<String> supported = {customer, kitchen};

  static String normalize(String? rawValue) {
    final normalized = (rawValue ?? '').trim().toLowerCase();
    if (normalized == kitchen) {
      return kitchen;
    }
    return customer;
  }

  static String requireSupported(String? rawValue) {
    final normalized = normalize(rawValue);
    if (!supported.contains(normalized)) {
      throw ArgumentError.value(
        rawValue,
        'templateType',
        'Unsupported receipt template type.',
      );
    }
    return normalized;
  }
}

class StorePrinterPurpose {
  static const String customer = 'customer';
  static const String kitchen = 'kitchen';
}

class StorePrinterInfo {
  final String id;
  final String name;
  final String purpose;
  final bool isDefault;
  final bool isSimulated;

  const StorePrinterInfo({
    required this.id,
    required this.name,
    this.purpose = StorePrinterPurpose.customer,
    this.isDefault = false,
    this.isSimulated = false,
  });
}

class StoreReceiptDocument {
  final int orderId;
  final String printerId;
  final String templateType;
  final int? kitchenBatchNumber;
  final int copyNumber;
  final int totalCopies;
  final String? tableLabel;
  final String? tokenNumber;
  final String? note;
  final String content;
  final String generatedOn;

  const StoreReceiptDocument({
    required this.orderId,
    required this.printerId,
    required this.templateType,
    required this.kitchenBatchNumber,
    required this.copyNumber,
    required this.totalCopies,
    required this.tableLabel,
    required this.tokenNumber,
    required this.note,
    required this.content,
    required this.generatedOn,
  });
}

class StorePrintJob {
  final StoreScope scope;
  final String printerId;
  final int orderId;
  final String templateType;
  final int? kitchenBatchNumber;
  final int copyNumber;
  final int totalCopies;
  final String? tableLabel;
  final String? tokenNumber;
  final String? note;
  final StoreReceiptDocument receipt;

  const StorePrintJob({
    required this.scope,
    required this.printerId,
    required this.orderId,
    required this.templateType,
    required this.kitchenBatchNumber,
    required this.copyNumber,
    required this.totalCopies,
    required this.tableLabel,
    required this.tokenNumber,
    required this.note,
    required this.receipt,
  });
}

class StorePrintResult {
  final String printerId;
  final int orderId;
  final String templateType;
  final int? kitchenBatchNumber;
  final int copies;
  final String receiptContent;
  final bool success;
  final int? exitCode;
  final String message;
  final String command;

  const StorePrintResult({
    required this.printerId,
    required this.orderId,
    required this.templateType,
    required this.kitchenBatchNumber,
    required this.copies,
    required this.receiptContent,
    required this.success,
    required this.exitCode,
    required this.message,
    required this.command,
  });
}

class StoreSimulatedPrinterAdapter implements StorePrinterAdapter {
  static const String consolePrinterId = 'console-printer-01';

  final List<StorePrinterInfo> printers;
  final void Function(String text) _consoleWriter;
  final List<StorePrintJob> _jobs = <StorePrintJob>[];

  StoreSimulatedPrinterAdapter({
    List<StorePrinterInfo>? printers,
    void Function(String text)? consoleWriter,
  }) : printers = List.unmodifiable(
         printers ??
             const <StorePrinterInfo>[
               StorePrinterInfo(
                 id: 'magnetic-printer-01',
                 name: 'Magnetic Printer 01',
                 purpose: StorePrinterPurpose.customer,
                 isDefault: true,
                 isSimulated: true,
               ),
               StorePrinterInfo(
                 id: 'kitchen-printer-01',
                 name: 'Kitchen Printer 01',
                 purpose: StorePrinterPurpose.kitchen,
                 isSimulated: true,
               ),
               StorePrinterInfo(
                 id: consolePrinterId,
                 name: 'Console Printer',
                 purpose: StorePrinterPurpose.customer,
                 isSimulated: true,
               ),
             ],
       ),
       _consoleWriter = consoleWriter ?? _defaultConsoleWriter;

  List<StorePrintJob> get jobs => List.unmodifiable(_jobs);

  StorePrintJob? get lastJob => _jobs.isEmpty ? null : _jobs.last;

  @override
  Future<List<StorePrinterInfo>> listAvailablePrinters() async {
    return printers;
  }

  @override
  Future<StorePrintResult> print(StorePrintJob job) async {
    _jobs.add(job);
    if (job.printerId == consolePrinterId) {
      _consoleWriter(
        '=== STORE RECEIPT ${job.templateType.toUpperCase()} ${job.copyNumber}/${job.totalCopies} '
        'order=${job.orderId} printer=${job.printerId} ===\n'
        '${job.receipt.content}'
        '=== END STORE RECEIPT ===',
      );
    }
    return StorePrintResult(
      printerId: job.printerId,
      orderId: job.orderId,
      templateType: job.templateType,
      kitchenBatchNumber: job.kitchenBatchNumber,
      copies: job.totalCopies,
      receiptContent: job.receipt.content,
      success: true,
      exitCode: 0,
      message:
          'Simulated print completed for printer ${job.printerId} (${job.templateType} copy ${job.copyNumber}/${job.totalCopies}).',
      command: 'simulate-print',
    );
  }
}

void _defaultConsoleWriter(String text) {
  stdout.writeln(text);
}

class StoreSystemPrinterAdapter implements StorePrinterAdapter {
  final String command;
  final List<String> additionalArguments;
  final Duration timeout;

  const StoreSystemPrinterAdapter({
    this.command = 'lp',
    this.additionalArguments = const [],
    this.timeout = const Duration(seconds: 15),
  });

  @override
  Future<List<StorePrinterInfo>> listAvailablePrinters() async {
    ProcessResult result;
    try {
      result = await Process.run('lpstat', const ['-a']).timeout(timeout);
    } on ProcessException catch (error) {
      throw StorePrinterException(
        'Failed to list printers with lpstat: ${error.message}',
      );
    } on TimeoutException {
      throw StorePrinterException(
        'Printer discovery command lpstat timed out.',
      );
    }
    if (result.exitCode != 0) {
      final stdoutText = '${result.stdout}'.trim();
      final stderrText = '${result.stderr}'.trim();
      throw StorePrinterException(
        'Printer discovery failed with exit code ${result.exitCode}: ${stderrText.isEmpty ? stdoutText : stderrText}',
      );
    }

    final lines = '${result.stdout}'
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines
        .map((line) {
          final printerId = line.split(' ').first.trim();
          return StorePrinterInfo(id: printerId, name: printerId);
        })
        .toList(growable: false);
  }

  @override
  Future<StorePrintResult> print(StorePrintJob job) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'store_receipt_print_',
    );
    final receiptFile = File('${tempDir.path}/receipt_${job.orderId}.txt');
    final args = <String>[
      '-d',
      job.printerId,
      ...additionalArguments,
      receiptFile.path,
    ];
    try {
      await receiptFile.writeAsString(job.receipt.content);
      ProcessResult result;
      try {
        result = await Process.run(command, args).timeout(timeout);
      } on ProcessException catch (error) {
        throw StorePrinterException(
          'Failed to execute printer command $command for printer ${job.printerId}: ${error.message}',
        );
      } on TimeoutException {
        throw StorePrinterException(
          'Printer command $command timed out for printer ${job.printerId}.',
        );
      }
      final stdoutText = '${result.stdout}'.trim();
      final stderrText = '${result.stderr}'.trim();
      if (result.exitCode != 0) {
        throw StorePrinterException(
          'Printer command $command failed for printer ${job.printerId} with exit code ${result.exitCode}: ${stderrText.isEmpty ? stdoutText : stderrText}',
        );
      }
      return StorePrintResult(
        printerId: job.printerId,
        orderId: job.orderId,
        templateType: job.templateType,
        kitchenBatchNumber: job.kitchenBatchNumber,
        copies: job.totalCopies,
        receiptContent: job.receipt.content,
        success: true,
        exitCode: result.exitCode,
        message: stdoutText.isEmpty ? 'Printed successfully.' : stdoutText,
        command: '$command ${args.join(' ')}',
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}

class StorePrintingService {
  final Store _store;

  StorePrintingService._(this._store);

  Future<StoreReceiptDocument> buildReceipt(
    String printerId,
    int orderId, {
    String templateType = StoreReceiptTemplateType.customer,
    int copyNumber = 1,
    int totalCopies = 1,
    String? tableLabel,
    String? tokenNumber,
    String? note,
  }) {
    return _store._buildOrderReceipt(
      _store.scope,
      printerId,
      orderId,
      templateType: templateType,
      copyNumber: copyNumber,
      totalCopies: totalCopies,
      tableLabel: tableLabel,
      tokenNumber: tokenNumber,
      note: note,
    );
  }

  Future<List<StorePrinterInfo>> listAvailablePrinters() {
    return _store._listAvailablePrinters();
  }

  Future<StorePrintResult> print(
    String printerId,
    int orderId, {
    String templateType = StoreReceiptTemplateType.customer,
    int copies = 1,
    String? tableLabel,
    String? tokenNumber,
    String? note,
  }) {
    return _store._printOrderReceipt(
      _store.scope,
      printerId,
      orderId,
      templateType: templateType,
      copies: copies,
      tableLabel: tableLabel,
      tokenNumber: tokenNumber,
      note: note,
    );
  }

  Future<StorePrintResult> sendToKitchen(
    String printerId,
    int orderId, {
    int copies = 1,
    String? tableLabel,
    String? tokenNumber,
    String? note,
  }) {
    return print(
      printerId,
      orderId,
      templateType: StoreReceiptTemplateType.kitchen,
      copies: copies,
      tableLabel: tableLabel,
      tokenNumber: tokenNumber,
      note: note,
    );
  }
}

class _StoreReceiptBuildData {
  final StoreOrderDetails details;
  final List<StoreOrderItemDetails> items;
  final int? kitchenBatchNumber;
  final Map<int, int> kitchenItemQuantitiesToMark;

  const _StoreReceiptBuildData({
    required this.details,
    required this.items,
    required this.kitchenBatchNumber,
    required this.kitchenItemQuantitiesToMark,
  });
}

extension on Store {
  Future<List<StorePrinterInfo>> _listAvailablePrinters() {
    return _printerAdapter.listAvailablePrinters();
  }

  Future<_StoreReceiptBuildData> _prepareReceiptBuildData(
    StoreScope scope,
    int orderId,
    String templateType,
  ) async {
    final details = await _getOrderDetails(scope, orderId);
    if (details == null) {
      throw StorePrinterException('Order $orderId was not found.');
    }
    if (templateType != StoreReceiptTemplateType.kitchen) {
      return _StoreReceiptBuildData(
        details: details,
        items: details.items,
        kitchenBatchNumber: null,
        kitchenItemQuantitiesToMark: const {},
      );
    }

    final pendingItems = <StoreOrderItemDetails>[];
    final quantitiesToMark = <int, int>{};
    for (final item in details.items) {
      final pendingQuantity =
          item.item.quantity - item.item.kitchenSentQuantity;
      if (pendingQuantity <= 0) {
        continue;
      }
      quantitiesToMark[item.item.id] = pendingQuantity;
      final pendingFinalPrice = item.item.quantity <= 0
          ? 0.0
          : item.item.finalPrice * (pendingQuantity / item.item.quantity);
      pendingItems.add(
        StoreOrderItemDetails(
          item: StoreOrderItemRecord(
            id: item.item.id,
            orgId: item.item.orgId,
            storeId: item.item.storeId,
            uniqueId: item.item.uniqueId,
            orderId: item.item.orderId,
            productVariantId: item.item.productVariantId,
            productId: item.item.productId,
            tableId: item.item.tableId,
            tableName: item.item.tableName,
            floorId: item.item.floorId,
            floorName: item.item.floorName,
            quantity: pendingQuantity,
            pricingMode: item.item.pricingMode,
            sellPrice: item.item.sellPrice,
            buyPrice: item.item.buyPrice,
            mrpPrice: item.item.mrpPrice,
            baseUnitPrice: item.item.baseUnitPrice,
            unitPrice: item.item.unitPrice,
            finalPrice: pendingFinalPrice,
            kitchenSentQuantity: item.item.kitchenSentQuantity,
            kitchenSentBatch: item.item.kitchenSentBatch,
            kitchenSentAt: item.item.kitchenSentAt,
          ),
          addons: item.addons,
          discountAmount: item.discountAmount,
          totalAfterDiscount: item.totalAfterDiscount,
          appliedOfferLocalIds: item.appliedOfferLocalIds,
        ),
      );
    }
    if (pendingItems.isEmpty) {
      throw StorePrinterException(
        'No new order items are pending for kitchen for order $orderId.',
      );
    }
    return _StoreReceiptBuildData(
      details: details,
      items: pendingItems,
      kitchenBatchNumber: await _ordersRepo.getNextKitchenBatchNumber(
        scope,
        orderId,
      ),
      kitchenItemQuantitiesToMark: quantitiesToMark,
    );
  }

  Future<StoreReceiptDocument> _buildOrderReceipt(
    StoreScope scope,
    String printerId,
    int orderId, {
    String templateType = StoreReceiptTemplateType.customer,
    int copyNumber = 1,
    int totalCopies = 1,
    String? tableLabel,
    String? tokenNumber,
    String? note,
    List<StoreOrderItemDetails>? resolvedItems,
    int? kitchenBatchNumber,
  }) async {
    final details = await _getOrderDetails(scope, orderId);
    if (details == null) {
      throw StorePrinterException('Order $orderId was not found.');
    }
    final resolvedTemplateType = StoreReceiptTemplateType.requireSupported(
      templateType,
    );
    final receiptItems = resolvedItems ?? details.items;
    final resolvedOrderTables = resolvedItems == null
        ? details.tables
        : _extractOrderTables(receiptItems);
    final resolvedTableLabel = _resolveReceiptTableLabel(
      tableLabel,
      resolvedOrderTables,
    );

    final offerNamesById = {
      for (final offer in details.appliedOffers) offer.localId: offer.name,
    };
    final buffer = StringBuffer();
    const width = 42;
    final generatedOn = DateTime.now().toIso8601String();

    _writeCentered(buffer, orgName.toUpperCase(), width);
    _writeCentered(buffer, storeName.toUpperCase(), width);
    _writeCentered(
      buffer,
      resolvedTemplateType == StoreReceiptTemplateType.kitchen
          ? 'KITCHEN COPY'
          : 'CUSTOMER COPY',
      width,
    );
    if (phone.isNotEmpty) {
      _writeCentered(buffer, 'Phone: $phone', width);
    }
    buffer.writeln(_receiptDivider(width));
    buffer.writeln(_receiptRow('Store Code', uniqueId, width));
    buffer.writeln(_receiptRow('Printer', printerId, width));
    buffer.writeln(_receiptRow('Order', details.orderId.toString(), width));
    if (resolvedTemplateType == StoreReceiptTemplateType.kitchen &&
        kitchenBatchNumber != null) {
      buffer.writeln(
        _receiptRow('Kitchen Batch', kitchenBatchNumber.toString(), width),
      );
    }
    buffer.writeln(_receiptRow('Copy', '$copyNumber/$totalCopies', width));
    if (_hasReceiptValue(tokenNumber)) {
      buffer.writeln(_receiptRow('Token', tokenNumber!.trim(), width));
    }
    if (_hasReceiptValue(resolvedTableLabel)) {
      buffer.writeln(_receiptRow('Table', resolvedTableLabel!, width));
    }
    if (details.customerName.trim().isNotEmpty) {
      buffer.writeln(_receiptRow('Customer', details.customerName, width));
    }
    if (details.mobile.isNotEmpty) {
      buffer.writeln(_receiptRow('Mobile', details.mobile, width));
    }
    buffer.writeln(_receiptRow('Type', details.orderType, width));
    buffer.writeln(_receiptRow('Status', details.statusName, width));
    buffer.writeln(
      _receiptRow('Created', _formatReceiptTimestamp(details.createdOn), width),
    );
    if (_hasReceiptValue(note)) {
      buffer.writeln(_receiptRow('Note', note!.trim(), width));
    }
    buffer.writeln(_receiptDivider(width));

    for (var itemIndex = 0; itemIndex < receiptItems.length; itemIndex++) {
      final itemDetails = receiptItems[itemIndex];
      final variant = await _productRepo.getProductVariantById(
        scope,
        itemDetails.item.productVariantId,
      );
      final itemName =
          (itemDetails.item.itemName.trim().isNotEmpty
              ? itemDetails.item.itemName.trim()
              : null) ??
          (variant?['product_variant_name'] as String?) ??
          (variant?['product_name'] as String?) ??
          itemDetails.item.productId;
      final itemTableLabel = _formatOrderItemTableLabel(itemDetails.item);
      final itemLabel = resolvedTemplateType == StoreReceiptTemplateType.kitchen
          ? '${itemIndex + 1}. $itemName x${itemDetails.item.quantity}${itemTableLabel.isEmpty ? '' : ' [$itemTableLabel]'}'
          : '$itemName x${itemDetails.item.quantity}';
      final itemPriceText =
          resolvedTemplateType == StoreReceiptTemplateType.kitchen
          ? ''
          : _formatMoney(itemDetails.item.finalPrice);
      buffer.writeln(_receiptRow(itemLabel, itemPriceText, width));
      for (final addon in itemDetails.addons) {
        final addonPriceText =
            resolvedTemplateType == StoreReceiptTemplateType.kitchen
            ? ''
            : _formatMoney(addon.totalPrice);
        buffer.writeln(
          _receiptRow(
            '  + ${addon.addonItemName} x${addon.quantity}',
            addonPriceText,
            width,
          ),
        );
      }
      if (resolvedTemplateType == StoreReceiptTemplateType.customer &&
          itemDetails.discountAmount > 0) {
        final appliedNames = itemDetails.appliedOfferLocalIds
            .map((offerId) => offerNamesById[offerId] ?? offerId)
            .join(', ');
        buffer.writeln(
          _receiptRow(
            appliedNames.isEmpty ? '  discount' : '  discount $appliedNames',
            '-${_formatMoney(itemDetails.discountAmount)}',
            width,
          ),
        );
      }
    }

    if (resolvedTemplateType == StoreReceiptTemplateType.customer) {
      buffer.writeln(_receiptDivider(width));
      buffer.writeln(
        _receiptRow('Subtotal', _formatMoney(details.subtotal), width),
      );
      if (details.totalDiscount > 0) {
        buffer.writeln(
          _receiptRow(
            'Discount',
            '-${_formatMoney(details.totalDiscount)}',
            width,
          ),
        );
      }
      buffer.writeln(_receiptRow('Total', _formatMoney(details.total), width));

      if (details.appliedOffers.isNotEmpty) {
        buffer.writeln(_receiptDivider(width));
        buffer.writeln('Applied offers');
        for (final offer in details.appliedOffers) {
          buffer.writeln(
            _receiptRow(
              '${offer.name} (${offer.offerType})',
              '-${_formatMoney(offer.discountAmount)}',
              width,
            ),
          );
        }
      }

      if (details.payments.isNotEmpty) {
        buffer.writeln(_receiptDivider(width));
        buffer.writeln('Payments');
        for (final payment in details.payments) {
          final label =
              payment.referenceId == null || payment.referenceId!.isEmpty
              ? payment.paymentMode
              : '${payment.paymentMode} ${payment.referenceId}';
          buffer.writeln(
            _receiptRow(label, _formatMoney(payment.amount), width),
          );
        }
      }
    }

    buffer.writeln(_receiptDivider(width));
    _writeCentered(buffer, 'Thank you', width);

    return StoreReceiptDocument(
      orderId: orderId,
      printerId: printerId,
      templateType: resolvedTemplateType,
      kitchenBatchNumber: kitchenBatchNumber,
      copyNumber: copyNumber,
      totalCopies: totalCopies,
      tableLabel: resolvedTableLabel,
      tokenNumber: tokenNumber?.trim().isEmpty ?? true
          ? null
          : tokenNumber!.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      content: buffer.toString(),
      generatedOn: generatedOn,
    );
  }

  Future<StorePrintResult> _printOrderReceipt(
    StoreScope scope,
    String printerId,
    int orderId, {
    String templateType = StoreReceiptTemplateType.customer,
    int copies = 1,
    String? tableLabel,
    String? tokenNumber,
    String? note,
  }) async {
    final normalizedPrinterId = printerId.trim();
    if (normalizedPrinterId.isEmpty) {
      throw StorePrinterException('printerId is required.');
    }
    if (copies <= 0) {
      throw StorePrinterException('copies must be greater than zero.');
    }
    final resolvedTemplateType = StoreReceiptTemplateType.requireSupported(
      templateType,
    );
    final availablePrinters = await _listAvailablePrinters();
    if (availablePrinters.isNotEmpty &&
        !availablePrinters.any(
          (printer) => printer.id == normalizedPrinterId,
        )) {
      throw StorePrinterException(
        'Printer $normalizedPrinterId is not available.',
      );
    }
    final receiptData = await _prepareReceiptBuildData(
      scope,
      orderId,
      resolvedTemplateType,
    );
    StorePrintResult? lastResult;
    for (var copyNumber = 1; copyNumber <= copies; copyNumber++) {
      final receipt = await _buildOrderReceipt(
        scope,
        normalizedPrinterId,
        orderId,
        templateType: resolvedTemplateType,
        copyNumber: copyNumber,
        totalCopies: copies,
        tableLabel: tableLabel,
        tokenNumber: tokenNumber,
        note: note,
        resolvedItems: receiptData.items,
        kitchenBatchNumber: receiptData.kitchenBatchNumber,
      );
      lastResult = await _printerAdapter.print(
        StorePrintJob(
          scope: scope,
          printerId: normalizedPrinterId,
          orderId: orderId,
          templateType: resolvedTemplateType,
          kitchenBatchNumber: receiptData.kitchenBatchNumber,
          copyNumber: copyNumber,
          totalCopies: copies,
          tableLabel: receipt.tableLabel,
          tokenNumber: tokenNumber,
          note: note,
          receipt: receipt,
        ),
      );
    }
    if (resolvedTemplateType == StoreReceiptTemplateType.kitchen &&
        receiptData.kitchenItemQuantitiesToMark.isNotEmpty) {
      await _ordersRepo.markOrderItemsSentToKitchen(
        scope,
        receiptData.kitchenItemQuantitiesToMark,
        batchNumber: receiptData.kitchenBatchNumber ?? 1,
        sentAt: DateTime.now().toIso8601String(),
      );
    }
    return lastResult!;
  }
}

String _receiptDivider(int width) => ''.padLeft(width, '-');

bool _hasReceiptValue(String? value) =>
    value != null && value.trim().isNotEmpty;

String? _resolveReceiptTableLabel(
  String? requestedTableLabel,
  List<StoreOrderTableRecord> orderTables,
) {
  if (_hasReceiptValue(requestedTableLabel)) {
    return requestedTableLabel!.trim();
  }
  if (orderTables.isEmpty) {
    return null;
  }
  return orderTables.map((table) => table.displayLabel).join(', ');
}

String _formatOrderItemTableLabel(StoreOrderItemRecord item) {
  final tableName = item.tableName?.trim() ?? '';
  if (tableName.isEmpty) {
    return '';
  }
  final floorName = item.floorName?.trim() ?? '';
  return floorName.isEmpty ? tableName : '$floorName / $tableName';
}

void _writeCentered(StringBuffer buffer, String value, int width) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return;
  }
  if (trimmed.length >= width) {
    buffer.writeln(trimmed);
    return;
  }
  final leftPadding = ((width - trimmed.length) / 2).floor();
  buffer.writeln('${' ' * leftPadding}$trimmed');
}

String _receiptRow(String left, String right, int width) {
  final normalizedLeft = left.trim();
  final normalizedRight = right.trim();
  if (normalizedLeft.isEmpty) {
    return normalizedRight;
  }
  if (normalizedRight.isEmpty) {
    return normalizedLeft;
  }
  final maxLeftWidth = width - normalizedRight.length - 1;
  if (maxLeftWidth <= 0) {
    return '$normalizedLeft $normalizedRight';
  }
  if (normalizedLeft.length <= maxLeftWidth) {
    return normalizedLeft.padRight(maxLeftWidth) + ' ' + normalizedRight;
  }
  final wrappedLines = <String>[];
  var remaining = normalizedLeft;
  while (remaining.length > maxLeftWidth) {
    wrappedLines.add(remaining.substring(0, maxLeftWidth));
    remaining = remaining.substring(maxLeftWidth);
  }
  wrappedLines.add(remaining.padRight(maxLeftWidth) + ' ' + normalizedRight);
  return wrappedLines.join('\n');
}

String _formatMoney(double value) => value.toStringAsFixed(2);

String _formatReceiptTimestamp(String rawValue) {
  final hostFormatter = Store.receiptTimestampFormatter;
  if (hostFormatter != null) {
    try {
      final formatted = hostFormatter(rawValue);
      if (formatted.trim().isNotEmpty) return formatted;
    } catch (_) {}
  }
  final parsed = DateTime.tryParse(rawValue);
  if (parsed == null) {
    return rawValue;
  }
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}-${twoDigits(parsed.month)}-${twoDigits(parsed.day)} ${twoDigits(parsed.hour)}:${twoDigits(parsed.minute)}';
}
