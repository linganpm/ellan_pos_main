part of 'store.dart';

class _StoreSyncExportSection {
  final String payloadKey;
  final bool advancesOffset;
  final Future<int> Function() count;
  final Future<List<Map<String, dynamic>>> Function(int limit, int offset)
  loadBatch;

  const _StoreSyncExportSection({
    required this.payloadKey,
    this.advancesOffset = true,
    required this.count,
    required this.loadBatch,
  });
}

class _StoreSyncImportBatch {
  final Map<String, dynamic> payload;
  final int batchCount;
  final int totalCount;
  final String? nextCursor;

  const _StoreSyncImportBatch({
    required this.payload,
    required this.batchCount,
    required this.totalCount,
    required this.nextCursor,
  });
}

class StoreSyncService {
  static const int defaultExportBatchSize = 500;

  final Store _store;
  Timer? _timer;
  bool _autoSyncInProgress = false;

  StoreSyncService._(this._store);

  bool get autoSyncEnabled => _store._config.sync.autoSyncEnabled;

  bool get isAutoSyncRunning => _timer?.isActive ?? false;

  Duration get periodicDuration => _store._config.sync.periodicDuration;

  Future<List<StoreSyncAttemptRecord>> history(
    StoreScope scope, {
    int limit = 500,
  }) {
    return _store._listSyncAttempts(scope, limit: limit);
  }

  Future<void> refreshAccessControl(
    StoreScope scope, {
    StoreDeviceRegistrationRequest? deviceRegistration,
  }) async {
    _store._validateScope(scope);
    await _store._refreshCurrentStoreAccessFromRemote(
      deviceRegistration: deviceRegistration,
    );
  }

  void _emitProgress(
    void Function(StoreSyncProgressUpdate update)? onProgress,
    StoreSyncProgressUpdate update,
  ) {
    onProgress?.call(update);
  }

  StoreSyncProgressUpdate _progressUpdate({
    required String entity,
    required String direction,
    required StoreSyncProgressStage stage,
    required String message,
    int processedCount = 0,
    int totalCount = 0,
    int successCount = 0,
    int failureCount = 0,
    int batchIndex = 0,
    int totalBatches = 0,
  }) {
    return StoreSyncProgressUpdate(
      entity: entity,
      direction: direction,
      stage: stage,
      processedCount: processedCount,
      totalCount: totalCount,
      successCount: successCount,
      failureCount: failureCount,
      batchIndex: batchIndex,
      totalBatches: totalBatches,
      message: message,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  int _readPayloadCount(Map<String, dynamic> payload, int fallbackCount) {
    final rawTotal = payload['total_count'];
    if (rawTotal is num) {
      return rawTotal.toInt();
    }
    return fallbackCount;
  }

  String? _readNextCursor(Map<String, dynamic> payload) {
    final rawCursor = payload['next_cursor'];
    if (rawCursor == null) {
      return null;
    }
    final cursor = rawCursor.toString();
    return cursor.isEmpty ? null : cursor;
  }

  Future<_StoreSyncImportBatch> _fetchImportBatch(
    StoreScope scope,
    StoreSyncEndpointConfig config, {
    String? cursor,
    String? since,
  }) async {
    final deviceId = await _store.registeredDeviceId;
    final response = await http.get(
      Store._buildImportUri(
        config.importUrl,
        orgId: scope.orgId,
        storeId: scope.storeId,
        deviceId: deviceId,
        limit: config.importBatchSize,
        cursor: cursor,
        since: since,
      ),
      headers: {
        if (deviceId != null && deviceId.isNotEmpty) 'X-Pos-Device-Id': deviceId,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Remote import failed with status ${response.statusCode}.',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return _StoreSyncImportBatch(
      payload: payload,
      batchCount: ((payload['batch_count'] as num?)?.toInt()) ?? 0,
      totalCount: _readPayloadCount(
        payload,
        ((payload['batch_count'] as num?)?.toInt()) ?? 0,
      ),
      nextCursor: _readNextCursor(payload),
    );
  }

  Future<StoreSyncOperationResult> _importInBatches({
    required String entity,
    required String startedAt,
    required StoreScope scope,
    required StoreSyncEndpointConfig config,
    required String skipMessage,
    required String startMessage,
    required String Function(int processedCount) completeMessage,
    required Future<int> Function(Map<String, dynamic> payload) importBatch,
    required void Function(StoreSyncProgressUpdate update)? onProgress,
    String? since,
    void Function(Map<String, dynamic> payload)? onPayload,
  }) async {
    if (!config.canImport) {
      final result = StoreSyncOperationResult(
        entity: entity,
        direction: 'import',
        processedCount: 0,
        successCount: 0,
        failureCount: 0,
        skipped: true,
        success: true,
        startedAt: startedAt,
        completedAt: DateTime.now().toIso8601String(),
        message: skipMessage,
      );
      _emitProgress(
        onProgress,
        _progressUpdate(
          entity: entity,
          direction: 'import',
          stage: StoreSyncProgressStage.skipped,
          message: result.message,
        ),
      );
      return result;
    }

    _emitProgress(
      onProgress,
      _progressUpdate(
        entity: entity,
        direction: 'import',
        stage: StoreSyncProgressStage.running,
        message: startMessage,
      ),
    );

    var cursor = null as String?;
    var processedCount = 0;
    var totalCount = 0;
    var batchIndex = 0;

    while (true) {
      final batch = await _fetchImportBatch(
        scope,
        config,
        cursor: cursor,
        since: since,
      );
      batchIndex += 1;
      totalCount = batch.totalCount >= processedCount
          ? batch.totalCount
          : processedCount;
      onPayload?.call(batch.payload);
      final importedCount = await importBatch(batch.payload);
      processedCount += importedCount;

      _emitProgress(
        onProgress,
        _progressUpdate(
          entity: entity,
          direction: 'import',
          stage: StoreSyncProgressStage.running,
          processedCount: processedCount,
          totalCount: totalCount,
          successCount: processedCount,
          batchIndex: batchIndex,
          totalBatches: totalCount == 0
              ? 0
              : ((totalCount + config.importBatchSize - 1) ~/
                    config.importBatchSize),
          message: 'Imported $processedCount of $totalCount $entity records.',
        ),
      );

      cursor = batch.nextCursor;
      if (cursor == null) {
        break;
      }
    }

    final result = StoreSyncOperationResult(
      entity: entity,
      direction: 'import',
      processedCount: processedCount,
      successCount: processedCount,
      failureCount: 0,
      skipped: false,
      success: true,
      startedAt: startedAt,
      completedAt: DateTime.now().toIso8601String(),
      message: completeMessage(processedCount),
    );

    _emitProgress(
      onProgress,
      _progressUpdate(
        entity: entity,
        direction: 'import',
        stage: StoreSyncProgressStage.completed,
        processedCount: processedCount,
        totalCount: totalCount,
        successCount: processedCount,
        batchIndex: totalCount == 0
            ? 0
            : ((totalCount + config.importBatchSize - 1) ~/
                  config.importBatchSize),
        totalBatches: totalCount == 0
            ? 0
            : ((totalCount + config.importBatchSize - 1) ~/
                  config.importBatchSize),
        message: result.message,
      ),
    );

    return result;
  }

  Future<StoreSyncOperationResult> _exportSnapshotInChunks({
    required String entity,
    required String startedAt,
    required String exportUrl,
    required String exportToken,
    required List<_StoreSyncExportSection> sections,
    required String emptyMessage,
    required String Function(Map<String, int> sectionTotals) successMessage,
    required Future<void> Function(
      Map<String, List<Map<String, dynamic>>> batchPayload, [
      Map<String, dynamic>? responseJson,
    ])
    onBatchSucceeded,
    required void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    final effectiveBatchSize = batchSize > 0
        ? batchSize
        : defaultExportBatchSize;
    final sectionTotals = <String, int>{};
    var totalCount = 0;
    for (final section in sections) {
      final count = await section.count();
      sectionTotals[section.payloadKey] = count;
      totalCount += count;
    }

    if (totalCount == 0) {
      _emitProgress(
        onProgress,
        _progressUpdate(
          entity: entity,
          direction: 'export',
          stage: StoreSyncProgressStage.completed,
          processedCount: 0,
          totalCount: 0,
          successCount: 0,
          failureCount: 0,
          message: emptyMessage,
        ),
      );
      return StoreSyncOperationResult(
        entity: entity,
        direction: 'export',
        processedCount: 0,
        successCount: 0,
        failureCount: 0,
        skipped: false,
        success: true,
        startedAt: startedAt,
        completedAt: DateTime.now().toIso8601String(),
        message: emptyMessage,
      );
    }

    final totalBatches = sectionTotals.values.fold<int>(
      0,
      (maxBatches, count) => math.max(
        maxBatches,
        count == 0
            ? 0
            : ((count + effectiveBatchSize - 1) ~/ effectiveBatchSize),
      ),
    );

    _emitProgress(
      onProgress,
      _progressUpdate(
        entity: entity,
        direction: 'export',
        stage: StoreSyncProgressStage.running,
        processedCount: 0,
        totalCount: totalCount,
        successCount: 0,
        failureCount: 0,
        batchIndex: 0,
        totalBatches: totalBatches,
        message: 'Starting $entity export in $totalBatches batch(es).',
      ),
    );

      var processedCount = 0;
    try {
      final deviceId = await _store.registeredDeviceId;
      final resolvedExportUrl = Store._buildExportUri(
        exportUrl,
        orgId: _store.orgId,
        storeId: _store.storeId,
        deviceId: deviceId,
      ).toString();
      final exportHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $exportToken',
        if (deviceId != null && deviceId.isNotEmpty) 'X-Pos-Device-Id': deviceId,
      };
      for (var batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
        final payload = <String, List<Map<String, dynamic>>>{};
        var batchProcessed = 0;
        for (final section in sections) {
          final sectionTotal = sectionTotals[section.payloadKey] ?? 0;
          final offset = section.advancesOffset
              ? batchIndex * effectiveBatchSize
              : 0;
          final rows = offset >= sectionTotal
              ? const <Map<String, dynamic>>[]
              : await section.loadBatch(effectiveBatchSize, offset);
          payload[section.payloadKey] = rows;
          batchProcessed += rows.length;
        }
        if (batchProcessed == 0) {
          continue;
        }

        final response = await http.post(
          Uri.parse(resolvedExportUrl),
          headers: exportHeaders,
          body: jsonEncode(payload),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            '${entity[0].toUpperCase()}${entity.substring(1)} export failed with status ${response.statusCode}.',
          );
        }

        Map<String, dynamic>? responseJson;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            responseJson = decoded.cast<String, dynamic>();
          }
        } catch (_) {
          responseJson = null;
        }

        await onBatchSucceeded(payload, responseJson);
        processedCount += batchProcessed;

        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: entity,
            direction: 'export',
            stage: StoreSyncProgressStage.running,
            processedCount: processedCount,
            totalCount: totalCount,
            successCount: processedCount,
            failureCount: 0,
            batchIndex: batchIndex + 1,
            totalBatches: totalBatches,
            message: 'Exported $processedCount of $totalCount $entity records.',
          ),
        );
      }
    } catch (error) {
      _emitProgress(
        onProgress,
        _progressUpdate(
          entity: entity,
          direction: 'export',
          stage: StoreSyncProgressStage.failed,
          processedCount: processedCount,
          totalCount: totalCount,
          successCount: processedCount,
          failureCount: 1,
          totalBatches: totalBatches,
          message: error.toString(),
        ),
      );
      rethrow;
    }

    final message = successMessage(sectionTotals);
    _emitProgress(
      onProgress,
      _progressUpdate(
        entity: entity,
        direction: 'export',
        stage: StoreSyncProgressStage.completed,
        processedCount: processedCount,
        totalCount: totalCount,
        successCount: processedCount,
        failureCount: 0,
        batchIndex: totalBatches,
        totalBatches: totalBatches,
        message: message,
      ),
    );

    return StoreSyncOperationResult(
      entity: entity,
      direction: 'export',
      processedCount: processedCount,
      successCount: processedCount,
      failureCount: 0,
      skipped: false,
      success: true,
      startedAt: startedAt,
      completedAt: DateTime.now().toIso8601String(),
      message: message,
    );
  }

  Future<StoreSyncOperationResult> _runOperation(
    String entity,
    String direction,
    Future<StoreSyncOperationResult> Function(String startedAt) action, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    final startedAt = DateTime.now().toIso8601String();
    try {
      final result = await action(startedAt);
      await _store._recordSyncAttempt(result);
      return result;
    } catch (error) {
      final failed = StoreSyncOperationResult(
        entity: entity,
        direction: direction,
        processedCount: 0,
        successCount: 0,
        failureCount: 1,
        skipped: false,
        success: false,
        startedAt: startedAt,
        completedAt: DateTime.now().toIso8601String(),
        message: error.toString(),
      );
      _emitProgress(
        onProgress,
        _progressUpdate(
          entity: entity,
          direction: direction,
          stage: StoreSyncProgressStage.failed,
          processedCount: 0,
          totalCount: 0,
          successCount: 0,
          failureCount: 1,
          message: error.toString(),
        ),
      );
      await _store._recordSyncAttempt(failed);
      rethrow;
    }
  }

  Future<StoreSyncOperationResult> importOrders(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    bool fullRestore = false,
  }) async {
    return _runOperation('orders', 'import', (startedAt) async {
      final config = _store._config.sync.orders;
      final since = fullRestore
          ? null
          : await _store._getSyncWatermark(scope, 'orders');
      String? maxAppliedUpdatedOn;
      String? maxSeenUpdatedOn;
      var appliedTotal = 0;
      var skippedTotal = 0;
      final result = await _importInBatches(
        entity: 'orders',
        startedAt: startedAt,
        scope: scope,
        config: config,
        since: since,
        skipMessage: 'Orders import URL is not configured.',
        startMessage: fullRestore
            ? 'Fetching all orders from remote server.'
            : (since == null
                  ? 'Fetching orders from remote server.'
                  : 'Fetching order drifts since $since.'),
        completeMessage: (processedCount) =>
            'Imported $processedCount orders.',
        onPayload: (payload) {
          for (final row in payload['data'] as List<dynamic>? ?? const []) {
            if (row is! Map) continue;
            final raw = '${row['updated_on'] ?? row['updatedOn'] ?? ''}'.trim();
            if (raw.isEmpty) continue;
            if (maxSeenUpdatedOn == null ||
                raw.compareTo(maxSeenUpdatedOn!) > 0) {
              maxSeenUpdatedOn = raw;
            }
          }
        },
        importBatch: (payload) async {
          final outcome = await _store._importOrdersFromData(
            scope,
            payload,
            markAsExported: true,
            skipAuth: true,
          );
          appliedTotal += outcome.appliedCount;
          skippedTotal += outcome.skippedCount;
          final appliedMax = outcome.maxAppliedUpdatedOn;
          if (appliedMax != null &&
              (maxAppliedUpdatedOn == null ||
                  appliedMax.compareTo(maxAppliedUpdatedOn!) > 0)) {
            maxAppliedUpdatedOn = appliedMax;
          }
          return outcome.appliedCount;
        },
        onProgress: onProgress,
      );
      // Advance watermark from applied rows, or from seen drifts when every
      // row was LWW-skipped (equal timestamps) so we do not re-pull forever.
      // Never fall back to startedAt on empty pages.
      final watermark = maxAppliedUpdatedOn ?? maxSeenUpdatedOn;
      if (result.success && !result.skipped && watermark != null) {
        await _store._setSyncWatermark(scope, 'orders', watermark);
      }
      final message = skippedTotal > 0
          ? 'Imported $appliedTotal orders ($skippedTotal skipped).'
          : 'Imported $appliedTotal orders.';
      return result.copyWith(
        processedCount: appliedTotal,
        successCount: appliedTotal,
        message: message,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportOrders(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('orders', 'export', (startedAt) async {
      final config = _store._config.sync.orders;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'orders',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Orders export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'orders',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Orders export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'orders',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'data',
            advancesOffset: false,
            count: () => _store._countPendingExportOrders(scope),
            loadBatch: (limit, offset) => _store._listPendingExportOrders(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
        ],
        emptyMessage: 'No pending orders to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['data'] ?? 0} orders.',
        onBatchSucceeded: (batchPayload, [responseJson]) async {
          // Only mark exported when the gateway explicitly accepted local_ids
          // that finished ingest (DONE/DUPLICATE). Pending/failed stay queued.
          final ok = responseJson == null || responseJson['ok'] != false;
          if (!ok) {
            final failed = (responseJson['failed_local_ids'] as List?)
                    ?.map((id) => '$id'.trim())
                    .where((id) => id.isNotEmpty)
                    .toList() ??
                const <String>[];
            if (failed.isNotEmpty) {
              await _store._scheduleOrderExportBackoff(scope, failed);
            }
            return;
          }
          final fromServer = (responseJson?['local_ids'] as List?)
              ?.map((id) => '$id'.trim())
              .where((id) => id.isNotEmpty)
              .toList();
          if (fromServer == null || fromServer.isEmpty) {
            // No DONE ack yet (e.g. Celery-only race) — keep exported=0.
            final pending = (responseJson?['pending_local_ids'] as List?)
                    ?.map((id) => '$id'.trim())
                    .where((id) => id.isNotEmpty)
                    .toList() ??
                const <String>[];
            final failed = (responseJson?['failed_local_ids'] as List?)
                    ?.map((id) => '$id'.trim())
                    .where((id) => id.isNotEmpty)
                    .toList() ??
                const <String>[];
            if (failed.isNotEmpty) {
              await _store._scheduleOrderExportBackoff(scope, failed);
            } else if (pending.isNotEmpty) {
              // Soft backoff so auto-sync does not hammer a still-pending batch.
              await _store._scheduleOrderExportBackoff(scope, pending);
            }
            return;
          }
          await _store._markOrdersExported(scope, fromServer, exported: true);
          final failed = (responseJson?['failed_local_ids'] as List?)
                  ?.map((id) => '$id'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList() ??
              const <String>[];
          if (failed.isNotEmpty) {
            await _store._scheduleOrderExportBackoff(scope, failed);
          }
        },
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importProducts(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('products', 'import', (startedAt) async {
      final config = _store._config.sync.products;
      return _importInBatches(
        entity: 'products',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Products import URL is not configured.',
        startMessage: 'Fetching products from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount product variants.',
        importBatch: (payload) async {
          var count = 0;
          for (final category
              in payload['data'] as List<dynamic>? ?? const []) {
            count +=
                (category['product_variants'] as List<dynamic>? ?? const [])
                    .length;
          }
          await _store._importProductVariantsFromData(
            scope,
            payload,
            markAsExported: true,
          );
          return count;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importOffers(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('offers', 'import', (startedAt) async {
      final config = _store._config.sync.offers;
      return _importInBatches(
        entity: 'offers',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Offers import URL is not configured.',
        startMessage: 'Fetching offers from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount offers.',
        importBatch: (payload) async {
          final count =
              (payload['data'] as List<dynamic>? ?? const []).length;
          await _store._offersRepo.importOffersFromJsonData(
            payload,
            scope: scope,
          );
          return count;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importCustomers(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('customers', 'import', (startedAt) async {
      final config = _store._config.sync.customers;
      return _importInBatches(
        entity: 'customers',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Customers import URL is not configured.',
        startMessage: 'Fetching customers from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount customers and roles.',
        importBatch: (payload) async {
          final customers = Store._extractRowList(payload['data']);
          await _store._importCustomersFromData(scope, payload);
          return customers.length;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importCredits(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('credits', 'import', (startedAt) async {
      final config = _store._config.sync.credits;
      return _importInBatches(
        entity: 'credits',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Credits import URL is not configured.',
        startMessage: 'Fetching credits from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount credits.',
        importBatch: (payload) async {
          final credits = Store._extractRowList(payload['data']);
          await _store._importCreditsFromData(scope, payload);
          return credits.length;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importTables(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('tables', 'import', (startedAt) async {
      final config = _store._config.sync.tables;
      return _importInBatches(
        entity: 'tables',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Tables import URL is not configured.',
        startMessage: 'Fetching floors and tables from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount floor and table records.',
        importBatch: (payload) async {
          final floors = Store._extractRowList(payload['floors']);
          final tables = Store._extractRowList(payload['tables']);
          await _store._importTablesFromData(scope, payload, skipAuth: true);
          return floors.length + tables.length;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importWallets(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('wallets', 'import', (startedAt) async {
      final config = _store._config.sync.wallets;
      var isFirstBatch = true;
      return _importInBatches(
        entity: 'wallets',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Wallets import URL is not configured.',
        startMessage: 'Fetching store wallets from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount store wallet(s).',
        importBatch: (payload) async {
          final rows = Store._extractRowList(payload['data']);
          await _store._importWalletsFromData(
            scope,
            payload,
            skipAuth: true,
            replaceScope: isFirstBatch,
          );
          final rawVariants = payload['variants'];
          if (rawVariants is List && rawVariants.isNotEmpty) {
            await _store._saveWalletVariantCatalogue(
              scope,
              [
                for (final row in rawVariants.whereType<Map>())
                  Map<String, dynamic>.from(row),
              ],
            );
          }
          isFirstBatch = false;
          return rows.length;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> importSubscribers(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return _runOperation('subscribers', 'import', (startedAt) async {
      final config = _store._config.sync.subscribers;
      return _importInBatches(
        entity: 'subscribers',
        startedAt: startedAt,
        scope: scope,
        config: config,
        skipMessage: 'Subscribers import URL is not configured.',
        startMessage: 'Fetching subscribers from remote server.',
        completeMessage: (processedCount) =>
            'Imported $processedCount subscriber(s).',
        importBatch: (payload) async {
          final rows = Store._extractRowList(payload['data']);
          await _store._importSubscribersFromData(
            scope,
            payload,
            skipAuth: true,
          );
          return rows.length;
        },
        onProgress: onProgress,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportCustomers(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('customers', 'export', (startedAt) async {
      final config = _store._config.sync.customers;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'customers',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Customers export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'customers',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Customers export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'customers',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'data',
            count: () => _store._countCustomerExportRows(scope),
            loadBatch: (limit, offset) => _store._listCustomerExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'store_roles',
            count: () => _store._countStoreRoleExportRows(scope),
            loadBatch: (limit, offset) => _store._listStoreRoleExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'org_roles',
            count: () => _store._countOrganisationRoleExportRows(scope),
            loadBatch: (limit, offset) =>
                _store._listOrganisationRoleExportRows(
                  scope,
                  limit: limit,
                  offset: offset,
                ),
          ),
        ],
        emptyMessage: 'No customers or roles to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['data'] ?? 0} customers, ${sectionTotals['store_roles'] ?? 0} store roles, and ${sectionTotals['org_roles'] ?? 0} organisation roles.',
        onBatchSucceeded: (_, [__]) async {},
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportProducts(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('products', 'export', (startedAt) async {
      final config = _store._config.sync.products;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'products',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Products export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'products',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Products export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'products',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'data',
            advancesOffset: false,
            count: () => _store._countPendingExportProductVariants(scope),
            loadBatch: (limit, offset) =>
                _store._listPendingExportCatalogRows(
                  scope,
                  limit: limit,
                  offset: offset,
                ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'offers',
            advancesOffset: false,
            count: () => _store._countPendingExportOffers(scope),
            loadBatch: (limit, offset) => _store._listPendingExportOffers(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
        ],
        emptyMessage: 'No pending catalogue or offer changes to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['data'] ?? 0} product variants and ${sectionTotals['offers'] ?? 0} offers.',
        onBatchSucceeded: (batchPayload, [responseJson]) async {
          final accepted = responseJson == null ||
              responseJson['accepted'] != false;
          if (!accepted) {
            throw StateError(
              '${responseJson['message'] ?? 'Products export was not accepted by the server.'}',
            );
          }
          final acceptedFromServer =
              (responseJson?['accepted_local_ids'] as List?)
                  ?.map((id) => '$id'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList();
          final batchLocalIds =
              (batchPayload['data'] ?? const <Map<String, dynamic>>[])
                  .map((row) => row['localId'] as String?)
                  .whereType<String>()
                  .toList();
          // Only clear pending for rows the server accepted; never the whole batch.
          final localIds = (acceptedFromServer != null)
              ? acceptedFromServer
              : batchLocalIds;

          final mappingsRaw = responseJson?['mappings'];
          if (mappingsRaw is List && mappingsRaw.isNotEmpty) {
            await _store._applyProductExportMappings(
              scope,
              mappingsRaw
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(),
            );
          }

          await _store._markProductVariantsExported(
            scope,
            localIds,
            exported: true,
          );
          await _store._markCatalogRelatedExported(scope, localIds);

          final offerIdsFromServer =
              (responseJson?['accepted_offer_local_ids'] as List?)
                  ?.map((id) => '$id'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList();
          final offerIds = (offerIdsFromServer != null &&
                  offerIdsFromServer.isNotEmpty)
              ? offerIdsFromServer
              : (batchPayload['offers'] ?? const <Map<String, dynamic>>[])
                  .map((row) => '${row['local_id'] ?? row['localId'] ?? ''}'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList();
          await _store._markOffersExported(
            scope,
            offerIds,
            exported: true,
          );
        },
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportCredits(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('credits', 'export', (startedAt) async {
      final config = _store._config.sync.credits;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'credits',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Credits export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'credits',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Credits export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'credits',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'data',
            count: () => _store._countCreditExportRows(scope),
            loadBatch: (limit, offset) => _store._listCreditExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'repayments',
            count: () => _store._countCreditRepaymentExportRows(scope),
            loadBatch: (limit, offset) => _store._listCreditRepaymentExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'allocations',
            count: () =>
                _store._countCreditRepaymentAllocationExportRows(scope),
            loadBatch: (limit, offset) =>
                _store._listCreditRepaymentAllocationExportRows(
                  scope,
                  limit: limit,
                  offset: offset,
                ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'installments',
            count: () => _store._countCreditInstallmentExportRows(scope),
            loadBatch: (limit, offset) =>
                _store._listCreditInstallmentExportRows(
                  scope,
                  limit: limit,
                  offset: offset,
                ),
          ),
        ],
        emptyMessage: 'No credits or repayments to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['data'] ?? 0} credits, ${sectionTotals['repayments'] ?? 0} repayments, ${sectionTotals['allocations'] ?? 0} allocations, and ${sectionTotals['installments'] ?? 0} installments.',
        onBatchSucceeded: (_, [__]) async {},
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportTables(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('tables', 'export', (startedAt) async {
      final config = _store._config.sync.tables;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'tables',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Tables export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'tables',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Tables export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'tables',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'floors',
            count: () => _store._countFloorExportRows(scope),
            loadBatch: (limit, offset) => _store._listFloorExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
          _StoreSyncExportSection(
            payloadKey: 'tables',
            count: () => _store._countTableExportRows(scope),
            loadBatch: (limit, offset) => _store._listTableExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
        ],
        emptyMessage: 'No floors or tables to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['floors'] ?? 0} floors and ${sectionTotals['tables'] ?? 0} tables.',
        onBatchSucceeded: (_, [__]) async {},
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  Future<StoreSyncOperationResult> exportSubscribers(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int batchSize = defaultExportBatchSize,
  }) async {
    return _runOperation('subscribers', 'export', (startedAt) async {
      final config = _store._config.sync.subscribers;
      if (!config.canExport) {
        final result = StoreSyncOperationResult(
          entity: 'subscribers',
          direction: 'export',
          processedCount: 0,
          successCount: 0,
          failureCount: 0,
          skipped: true,
          success: true,
          startedAt: startedAt,
          completedAt: DateTime.now().toIso8601String(),
          message: 'Subscribers export URL is not configured.',
        );
        _emitProgress(
          onProgress,
          _progressUpdate(
            entity: 'subscribers',
            direction: 'export',
            stage: StoreSyncProgressStage.skipped,
            message: result.message,
          ),
        );
        return result;
      }
      if (config.exportToken.isEmpty) {
        throw StateError(
          'Subscribers export token is required when export URL is configured.',
        );
      }

      return _exportSnapshotInChunks(
        entity: 'subscribers',
        startedAt: startedAt,
        exportUrl: config.exportUrl,
        exportToken: config.exportToken,
        sections: [
          _StoreSyncExportSection(
            payloadKey: 'data',
            count: () => _store._countSubscriberExportRows(scope),
            loadBatch: (limit, offset) => _store._listSubscriberExportRows(
              scope,
              limit: limit,
              offset: offset,
            ),
          ),
        ],
        emptyMessage: 'No pending subscribers to export.',
        successMessage: (sectionTotals) =>
            'Exported ${sectionTotals['data'] ?? 0} subscriber(s).',
        onBatchSucceeded: (batchPayload, [responseJson]) async {
          final accepted =
              responseJson == null || responseJson['accepted'] != false;
          if (!accepted) {
            throw StateError(
              '${responseJson['message'] ?? 'Subscribers export was not accepted by the server.'}',
            );
          }
          final acceptedFromServer =
              (responseJson?['accepted_local_ids'] as List?)
                  ?.map((id) => '$id'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList();
          final batchLocalIds =
              (batchPayload['data'] ?? const <Map<String, dynamic>>[])
                  .map((row) => '${row['local_id'] ?? row['localId'] ?? ''}'.trim())
                  .where((id) => id.isNotEmpty)
                  .toList();
          final localIds = acceptedFromServer ?? batchLocalIds;
          final mappingsRaw = responseJson?['mappings'];
          final mappings = mappingsRaw is List
              ? mappingsRaw
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
              : const <Map<String, dynamic>>[];
          await _store._markSubscribersExported(
            scope,
            localIds,
            mappings: mappings,
          );
        },
        onProgress: onProgress,
        batchSize: batchSize,
      );
    }, onProgress: onProgress);
  }

  /// Import catalogue entities for the configured store.
  ///
  /// Routine Sync uses [fullOrderRestore]=false (watermarked order drifts).
  /// Explicit rebuild/recovery uses fullOrderRestore=true.
  Future<StoreSyncBatchResult> importConfiguredCatalogue(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    bool fullOrderRestore = false,
  }) async {
    await refreshAccessControl(scope);
    final syncConfig = _store._config.sync;
    final operations = <StoreSyncOperationResult>[];

    if (syncConfig.customers.canImport) {
      operations.add(await importCustomers(scope, onProgress: onProgress));
    }
    if (syncConfig.products.canImport) {
      operations.add(await importProducts(scope, onProgress: onProgress));
    }
    if (syncConfig.offers.canImport) {
      operations.add(await importOffers(scope, onProgress: onProgress));
    }
    if (syncConfig.orders.canImport) {
      operations.add(
        await importOrders(
          scope,
          onProgress: onProgress,
          fullRestore: fullOrderRestore,
        ),
      );
    }
    if (syncConfig.credits.canImport) {
      operations.add(await importCredits(scope, onProgress: onProgress));
    }
    if (syncConfig.tables.canImport) {
      operations.add(await importTables(scope, onProgress: onProgress));
    }
    if (syncConfig.wallets.canImport) {
      operations.add(await importWallets(scope, onProgress: onProgress));
    }
    if (syncConfig.subscribers.canImport) {
      operations.add(await importSubscribers(scope, onProgress: onProgress));
    }

    return StoreSyncBatchResult(operations: operations);
  }

  Future<StoreSyncBatchResult> restoreFromRemote(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return importConfiguredCatalogue(
      scope,
      onProgress: onProgress,
      fullOrderRestore: true,
    );
  }

  Future<StoreSyncBatchResult> runAll(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int exportBatchSize = defaultExportBatchSize,
  }) async {
    await refreshAccessControl(scope);
    final operations = <StoreSyncOperationResult>[
      await importCustomers(scope, onProgress: onProgress),
      await importProducts(scope, onProgress: onProgress),
      await importOffers(scope, onProgress: onProgress),
      // Push local order drifts before download so LWW does not wipe them.
      await exportOrders(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await importOrders(scope, onProgress: onProgress),
      await importCredits(scope, onProgress: onProgress),
      await importTables(scope, onProgress: onProgress),
      await importWallets(scope, onProgress: onProgress),
      await importSubscribers(scope, onProgress: onProgress),
      await exportCustomers(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportProducts(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportCredits(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportTables(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportSubscribers(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
    ];
    return StoreSyncBatchResult(operations: operations);
  }

  Future<StoreSyncBatchResult> runConfigured(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int exportBatchSize = defaultExportBatchSize,
  }) async {
    await refreshAccessControl(scope);
    final syncConfig = _store._config.sync;
    final operations = <StoreSyncOperationResult>[];

    if (syncConfig.customers.canImport) {
      operations.add(await importCustomers(scope, onProgress: onProgress));
    }
    if (syncConfig.products.canImport) {
      operations.add(await importProducts(scope, onProgress: onProgress));
    }
    if (syncConfig.offers.canImport) {
      operations.add(await importOffers(scope, onProgress: onProgress));
    }
    if (syncConfig.orders.canExport) {
      operations.add(
        await exportOrders(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }
    if (syncConfig.orders.canImport) {
      operations.add(await importOrders(scope, onProgress: onProgress));
    }
    if (syncConfig.credits.canImport) {
      operations.add(await importCredits(scope, onProgress: onProgress));
    }
    if (syncConfig.tables.canImport) {
      operations.add(await importTables(scope, onProgress: onProgress));
    }
    if (syncConfig.wallets.canImport) {
      operations.add(await importWallets(scope, onProgress: onProgress));
    }
    if (syncConfig.subscribers.canImport) {
      operations.add(await importSubscribers(scope, onProgress: onProgress));
    }
    if (syncConfig.customers.canExport) {
      operations.add(
        await exportCustomers(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }
    if (syncConfig.products.canExport) {
      operations.add(
        await exportProducts(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }
    if (syncConfig.credits.canExport) {
      operations.add(
        await exportCredits(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }
    if (syncConfig.tables.canExport) {
      operations.add(
        await exportTables(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }
    if (syncConfig.subscribers.canExport) {
      operations.add(
        await exportSubscribers(
          scope,
          onProgress: onProgress,
          batchSize: exportBatchSize,
        ),
      );
    }

    return StoreSyncBatchResult(operations: operations);
  }

  Future<StoreSyncBatchResult> syncOrdersProductsCredits(
    StoreScope scope, {
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int exportBatchSize = defaultExportBatchSize,
  }) async {
    await refreshAccessControl(scope);
    final operations = <StoreSyncOperationResult>[
      await importProducts(scope, onProgress: onProgress),
      await importOffers(scope, onProgress: onProgress),
      await exportOrders(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await importOrders(scope, onProgress: onProgress),
      await importCredits(scope, onProgress: onProgress),
      await importTables(scope, onProgress: onProgress),
      await importWallets(scope, onProgress: onProgress),
      await exportProducts(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportCredits(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
      await exportTables(
        scope,
        onProgress: onProgress,
        batchSize: exportBatchSize,
      ),
    ];
    return StoreSyncBatchResult(operations: operations);
  }

  bool kickStartAutoSync(StoreScope scope, {bool runImmediately = true}) {
    if (!autoSyncEnabled || periodicDuration <= Duration.zero) {
      stopAutoSync();
      return false;
    }

    _timer?.cancel();
    _timer = Timer.periodic(periodicDuration, (_) {
      _runAutoSyncCycle(scope);
    });

    if (runImmediately) {
      _runAutoSyncCycle(scope);
    }

    return true;
  }

  bool startAutoSync(StoreScope scope, {bool runImmediately = false}) {
    return kickStartAutoSync(scope, runImmediately: runImmediately);
  }

  void stopAutoSync() {
    _timer?.cancel();
    _timer = null;
    _autoSyncInProgress = false;
  }

  void _runAutoSyncCycle(StoreScope scope) {
    if (_autoSyncInProgress) {
      return;
    }

    _autoSyncInProgress = true;
    runConfigured(scope).then<void>((_) {}, onError: (_, __) {}).whenComplete(
      () {
        _autoSyncInProgress = false;
      },
    );
  }

  StoreSyncOperationResult _unsupportedOperationResult({
    required String entity,
    required String direction,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    return StoreSyncOperationResult(
      entity: entity,
      direction: direction,
      processedCount: 0,
      successCount: 0,
      failureCount: 0,
      skipped: true,
      success: true,
      startedAt: timestamp,
      completedAt: timestamp,
      message:
          '${entity[0].toUpperCase()}${entity.substring(1)} $direction is not supported.',
    );
  }
}
