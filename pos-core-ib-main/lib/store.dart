import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'sqflite_ffi_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'backend_setup.dart';
import 'offers_repository.dart';
import 'orders_repository.dart';
import 'product_repository.dart';
import 'customer_repository.dart';
import 'product_data_importer.dart';
import 'product_image_cache.dart';
import 'store_offer_engine.dart';
import 'store_config.dart';
import 'store_exceptions.dart';
import 'store_models.dart';
import 'sync_diagnostics_log.dart';
import 'sync_timestamps.dart';

part 'store_auth_service.dart';
part 'store_orders_service.dart';
part 'store_products_service.dart';
part 'store_customers_service.dart';
part 'store_tables_service.dart';
part 'store_credits_service.dart';
part 'store_wallets_service.dart';
part 'store_offers_service.dart';
part 'store_print_service.dart';
part 'store_sync_service.dart';
part 'store_dashboard_service.dart';

class Store {
  /// Optional host hook to render receipt timestamps in the org timezone.
  static String Function(String rawValue)? receiptTimestampFormatter;

  static const int _localOrderIdPrefix = 55;
  static const int _localOrderIdRandomDigits = 8;
  static const Map<String, int> _rolePriority = {
    'guest': 0,
    'member': 1,
    'admin': 2,
  };
  static final Uuid _uuid = Uuid();

  // Store metadata
  final String orgId;
  final String? organisationRemoteId;
  final String orgName;
  final String orgCode;
  final String storeId;
  final String? storeRemoteId;
  final int serviceInstanceId;
  final String storeName;
  final String logo;
  final String uniqueId; // 8 digit
  final String contactEmail;
  final String phone;
  final String contactPerson;
  String status;
  final String serviceVariantType;

  // Internal
  final Database _db;
  final OrdersRepository _ordersRepo;
  final OffersRepository _offersRepo;
  final ProductRepository _productRepo;
  final CustomerRepository _customerRepo;
  final StorePrinterAdapter _printerAdapter;
  final Duration _sessionDuration;
  StoreConfig _config;

  /// Short-lived auth cache so checkout/order loops do not re-hit SQLite
  /// for session + store-access on every role check.
  StoreSession? _sessionCache;
  DateTime? _sessionCacheAt;
  DateTime? _localAccessCheckedAt;
  static const Duration _sessionCacheTtl = Duration(seconds: 3);

  /// Latest store_settings blob from credits import (consumed by the tablet).
  Map<String, dynamic>? _lastImportedCreditStoreSettings;
  late final StoreAuthService auth = StoreAuthService._(this);
  late final StoreOrdersService orders = StoreOrdersService._(this);
  late final StoreProductsService products = StoreProductsService._(this);
  late final StoreCustomersService customers = StoreCustomersService._(this);
  late final StoreTablesService tables = StoreTablesService._(this);
  late final StoreCreditsService credits = StoreCreditsService._(this);
  late final StoreWalletsService wallets = StoreWalletsService._(this);
  late final StoreOffersService offers = StoreOffersService._(this);
  late final StorePrintingService printing = StorePrintingService._(this);
  late final StoreSyncService sync = StoreSyncService._(this);

  /// Idempotent local SQLite repairs used before Sync / wallet catalogue ops.
  Future<void> ensureLocalSchema() => BackendSetup.ensureSchemaRepairs(_db);

  Future<Map<String, dynamic>> loadCompanyProfile() async {
    await _requireRole('member');
    final rows = await _db.query(
      _storeInfoTable,
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [orgId, storeId],
      limit: 1,
    );
    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return {
      'storeName': row['storeName'] ?? storeName,
      'phone': row['phone'] ?? phone,
      'contactEmail': row['contactEmail'] ?? contactEmail,
      'contactPerson': row['contactPerson'] ?? contactPerson,
      'address': row['address'] ?? '',
      'registration_number': row['registration_number'] ?? '',
      'tax_number': row['tax_number'] ?? '',
      'identifier': row['identifier'] ?? '',
      'logo': row['logo'] ?? logo,
      'logo_pending_sync': (row['logo_pending_sync'] as num?)?.toInt() ?? 0,
      'profile_pending_sync':
          (row['profile_pending_sync'] as num?)?.toInt() ?? 0,
      'uniqueId': uniqueId,
      'serviceInstanceId': serviceInstanceId,
      'storeRemoteId': storeRemoteId,
      'orgId': orgId,
      'storeId': storeId,
    };
  }

  Future<void> saveCompanyProfileLocal({
    String? storeName,
    String? phone,
    String? contactEmail,
    String? address,
    String? registrationNumber,
    String? taxNumber,
    String? identifier,
    String? logo,
    bool? logoPendingSync,
    bool? profilePendingSync,
  }) async {
    await _requireRole('admin');
    final patch = <String, Object?>{};
    if (storeName != null) patch['storeName'] = storeName;
    if (phone != null) patch['phone'] = phone;
    if (contactEmail != null) patch['contactEmail'] = contactEmail;
    if (address != null) patch['address'] = address;
    if (registrationNumber != null) {
      patch['registration_number'] = registrationNumber;
    }
    if (taxNumber != null) patch['tax_number'] = taxNumber;
    if (identifier != null) patch['identifier'] = identifier;
    if (logo != null) patch['logo'] = logo;
    if (logoPendingSync != null) {
      patch['logo_pending_sync'] = logoPendingSync ? 1 : 0;
    }
    if (profilePendingSync != null) {
      patch['profile_pending_sync'] = profilePendingSync ? 1 : 0;
    }
    if (patch.isEmpty) return;
    await _db.update(
      _storeInfoTable,
      patch,
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [orgId, storeId],
    );
  }

  /// Persist a picked logo file path for later company-settings sync.
  Future<void> setCompanyLogoLocal(String absolutePath) async {
    await saveCompanyProfileLocal(logo: absolutePath, logoPendingSync: true);
  }

  /// Applies a store directory refresh (as login/bootstrap does) to this
  /// store's `store_info` row.
  Future<void> applyStoreDirectoryEntryForTest(StoreDirectoryEntry entry) =>
      _saveStoreDirectoryEntry(_db, entry);

  Future<List<Map<String, dynamic>>> listReportSubscribers() async {
    await _requireRole('member');
    final rows = await _db.query(
      'subscribers',
      where:
          'orgId = ? AND storeId = ? AND type = ? AND deleted = 0 AND active = 1',
      whereArgs: [orgId, storeId, 'report'],
      orderBy: 'is_owner_default DESC, name COLLATE NOCASE ASC',
    );
    // Keep a `cadence` alias for older UI callers.
    return rows
        .map((row) => {...row, 'cadence': row['periodicity'] ?? 'daily'})
        .toList(growable: false);
  }

  Future<void> ensureOwnerReportSubscriber({
    required String email,
    required String name,
  }) async {
    await _requireRole('admin');
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty || !trimmed.contains('@')) return;
    final existing = await _db.query(
      'subscribers',
      where:
          'orgId = ? AND storeId = ? AND email = ? AND type = ? AND deleted = 0',
      whereArgs: [orgId, storeId, trimmed, 'report'],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _db.insert('subscribers', {
      'local_id': _newLocalSyncId('subscriber'),
      'orgId': orgId,
      'storeId': storeId,
      'name': name.trim().isEmpty ? 'Owner' : name.trim(),
      'email': trimmed,
      'type': 'report',
      'notification_type': 'email',
      'periodicity': 'daily',
      'deleted': 0,
      'active': 1,
      'is_owner_default': 1,
      'created_on': now,
      'updated_on': now,
      'pending_sync': 1,
      'exported': 0,
    });
  }

  Future<int> addReportSubscriber({
    required String name,
    required String email,
    required String cadence,
    String notificationType = 'email',
    String? phoneNumber,
    String? countryId,
    String? userId,
  }) async {
    await _requireRole('admin');
    final trimmed = email.trim().toLowerCase();
    final phone = phoneNumber?.trim() ?? '';
    final channel = notificationType.trim().toLowerCase();
    const allowedChannels = {'email', 'slack', 'whatsapp', 'sms', 'push'};
    if (!allowedChannels.contains(channel)) {
      throw ArgumentError(
        'Notification type must be email, slack, whatsapp, sms, or push.',
      );
    }
    if (channel == 'email' && (trimmed.isEmpty || !trimmed.contains('@'))) {
      throw ArgumentError('A valid email is required.');
    }
    if ((channel == 'sms' || channel == 'whatsapp') &&
        phone.isEmpty &&
        (trimmed.isEmpty || !trimmed.contains('@'))) {
      throw ArgumentError('A phone number (or email) is required.');
    }
    final allowed = {'daily', 'weekly', 'monthly', 'annually', 'annual'};
    var kind = cadence.trim().toLowerCase();
    if (kind == 'annual' || kind == 'yearly') kind = 'annually';
    if (!allowed.contains(kind)) {
      throw ArgumentError(
        'Periodicity must be daily, weekly, monthly, or annually.',
      );
    }
    final now = DateTime.now().toIso8601String();
    return _db.insert('subscribers', {
      'local_id': _newLocalSyncId('subscriber'),
      'orgId': orgId,
      'storeId': storeId,
      'name': name.trim().isEmpty
          ? (trimmed.isNotEmpty ? trimmed : phone)
          : name.trim(),
      'email': trimmed,
      'phone_number': phone.isEmpty ? null : phone,
      'country_id': countryId?.trim(),
      'user_id': userId?.trim(),
      'type': 'report',
      'notification_type': channel,
      'periodicity': kind,
      'deleted': 0,
      'active': 1,
      'is_owner_default': 0,
      'created_on': now,
      'updated_on': now,
      'pending_sync': 1,
      'exported': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteReportSubscriber(int id) async {
    await _requireRole('admin');
    final now = DateTime.now().toIso8601String();
    await _db.update(
      'subscribers',
      {
        'deleted': 1,
        'active': 0,
        'pending_sync': 1,
        'exported': 0,
        'updated_on': now,
      },
      where:
          'id = ? AND orgId = ? AND storeId = ? AND is_owner_default = 0 AND type = ?',
      whereArgs: [id, orgId, storeId, 'report'],
    );
  }

  Future<void> _importSubscribersFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    final rawRows = data['data'] ?? data['subscribers'] ?? const <dynamic>[];
    if (rawRows is! List) return;
    final now = DateTime.now().toIso8601String();
    for (final raw in rawRows.whereType<Map>()) {
      final row = raw.cast<String, dynamic>();
      final email = (row['email'] as String?)?.trim().toLowerCase() ?? '';
      if (email.isEmpty || !email.contains('@')) continue;
      final type = (row['type'] as String?)?.trim().toLowerCase() ?? 'report';
      final notificationType =
          (row['notification_type'] as String?)?.trim().toLowerCase() ??
          (row['notificationType'] as String?)?.trim().toLowerCase() ??
          'email';
      var periodicity =
          (row['periodicity'] as String?)?.trim().toLowerCase() ??
          (row['cadence'] as String?)?.trim().toLowerCase() ??
          'daily';
      if (periodicity == 'annual' || periodicity == 'yearly') {
        periodicity = 'annually';
      }
      final remoteId =
          (row['remote_id'] as num?)?.toInt() ?? (row['id'] as num?)?.toInt();
      final localId = (row['local_id'] as String?)?.trim().isNotEmpty == true
          ? (row['local_id'] as String).trim()
          : (remoteId != null
                ? 'subscriber-$remoteId'
                : _newLocalSyncId('subscriber'));
      final deleted = row['deleted'] is bool
          ? ((row['deleted'] as bool) ? 1 : 0)
          : ((row['deleted'] as num?)?.toInt() ?? 0);
      final active = deleted == 1
          ? 0
          : (row['active'] is bool
                ? ((row['active'] as bool) ? 1 : 0)
                : ((row['active'] as num?)?.toInt() ?? 1));
      final values = <String, Object?>{
        'local_id': localId,
        'remote_id': remoteId,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'name': ((row['name'] as String?)?.trim().isNotEmpty == true)
            ? (row['name'] as String).trim()
            : email,
        'user_id': row['user_id']?.toString() ?? row['userId']?.toString(),
        'email': email,
        'phone_number':
            (row['phone_number'] as String?) ?? (row['phone'] as String?),
        'country_id':
            row['country_id']?.toString() ?? row['countryId']?.toString(),
        'type': type,
        'notification_type': notificationType,
        'periodicity': periodicity,
        'deleted': deleted,
        'active': active,
        'is_owner_default': (row['is_owner_default'] as num?)?.toInt() ?? 0,
        'created_by':
            row['created_by']?.toString() ?? row['createdBy']?.toString(),
        'created_on': (row['created_on'] as String?) ?? now,
        'updated_on': (row['updated_on'] as String?) ?? now,
        'pending_sync': 0,
        'exported': 1,
      };

      Map<String, dynamic>? existing;
      if (remoteId != null) {
        final byRemote = await _db.query(
          'subscribers',
          where: 'orgId = ? AND storeId = ? AND remote_id = ?',
          whereArgs: [scope.orgId, scope.storeId, remoteId],
          limit: 1,
        );
        if (byRemote.isNotEmpty) existing = byRemote.first;
      }
      if (existing == null) {
        final byLocal = await _db.query(
          'subscribers',
          where: 'orgId = ? AND storeId = ? AND local_id = ?',
          whereArgs: [scope.orgId, scope.storeId, localId],
          limit: 1,
        );
        if (byLocal.isNotEmpty) existing = byLocal.first;
      }
      if (existing == null) {
        final byEmail = await _db.query(
          'subscribers',
          where:
              'orgId = ? AND storeId = ? AND email = ? AND type = ? AND notification_type = ?',
          whereArgs: [
            scope.orgId,
            scope.storeId,
            email,
            type,
            notificationType,
          ],
          limit: 1,
        );
        if (byEmail.isNotEmpty) existing = byEmail.first;
      }

      if (existing == null) {
        await _db.insert('subscribers', values);
      } else {
        // Prefer server truth when not pending local edits.
        final pending = ((existing['pending_sync'] as num?)?.toInt() ?? 0) == 1;
        if (pending) continue;
        await _db.update(
          'subscribers',
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
  }

  Future<int> _countSubscriberExportRows(StoreScope scope) async {
    _validateScope(scope);
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM subscribers
      WHERE orgId = ? AND storeId = ? AND pending_sync = 1
      ''',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listSubscriberExportRows(
    StoreScope scope, {
    required int limit,
    required int offset,
  }) async {
    _validateScope(scope);
    final rows = await _db.query(
      'subscribers',
      where: 'orgId = ? AND storeId = ? AND pending_sync = 1',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (row) => <String, dynamic>{
            'local_id': row['local_id'] ?? 'subscriber-${row['id']}',
            'remote_id': row['remote_id'],
            'orgId': scope.orgId,
            'storeId': scope.storeId,
            'name': row['name'],
            'user_id': row['user_id'],
            'email': row['email'],
            'phone_number': row['phone_number'],
            'country_id': row['country_id'],
            'type': row['type'] ?? 'report',
            'notification_type': row['notification_type'] ?? 'email',
            'periodicity': row['periodicity'] ?? 'daily',
            'deleted': (row['deleted'] as num?)?.toInt() ?? 0,
            'active': (row['active'] as num?)?.toInt() ?? 1,
            'is_owner_default': (row['is_owner_default'] as num?)?.toInt() ?? 0,
            'created_by': row['created_by'],
            'created_on': row['created_on'],
            'updated_on': row['updated_on'],
          },
        )
        .toList(growable: false);
  }

  Future<void> _markSubscribersExported(
    StoreScope scope,
    List<String> localIds, {
    List<Map<String, dynamic>> mappings = const [],
  }) async {
    _validateScope(scope);
    if (localIds.isEmpty && mappings.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final remoteByLocal = <String, int>{};
    for (final mapping in mappings) {
      final localId = '${mapping['local_id'] ?? ''}'.trim();
      final remoteId = (mapping['remote_id'] as num?)?.toInt();
      if (localId.isEmpty || remoteId == null) continue;
      remoteByLocal[localId] = remoteId;
    }
    final ids = {
      ...localIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
      ...remoteByLocal.keys,
    };
    for (final localId in ids) {
      final patch = <String, Object?>{
        'pending_sync': 0,
        'exported': 1,
        'updated_on': now,
      };
      final remoteId = remoteByLocal[localId];
      if (remoteId != null) {
        patch['remote_id'] = remoteId;
      }
      await _db.update(
        'subscribers',
        patch,
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
      );
    }
  }

  Future<Map<String, dynamic>?> loadEmailConfig(String purpose) async {
    await _requireRole('member');
    final rows = await _db.query(
      'store_email_config',
      where: 'orgId = ? AND storeId = ? AND purpose = ?',
      whereArgs: [orgId, storeId, purpose],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Persist email config. Locked / system purposes cannot be created or edited.
  Future<void> saveEmailConfig({
    required String purpose,
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromEmail,
    required String fromName,
    bool useTls = true,
    bool locked = false,
    bool pendingSync = true,
  }) async {
    await _requireRole('admin');
    final key = purpose.trim().toLowerCase();
    if (key == 'sales_reports' || key == 'invoice_booking') {
      throw StateError(
        'System email credentials are fixed and cannot be changed.',
      );
    }
    final existing = await loadEmailConfig(purpose);
    if (existing != null && ((existing['locked'] as num?)?.toInt() ?? 0) == 1) {
      throw StateError(
        'This email configuration is locked and cannot be changed.',
      );
    }
    await _db.insert('store_email_config', {
      'orgId': orgId,
      'storeId': storeId,
      'purpose': purpose,
      'host': host.trim(),
      'port': port,
      'username': username.trim(),
      'password': password,
      'from_email': fromEmail.trim(),
      'from_name': fromName.trim(),
      'use_tls': useTls ? 1 : 0,
      'locked': locked ? 1 : 0,
      'pending_sync': pendingSync ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Upsert locked system mailers from gateway public rows (no password).
  ///
  /// Password is never taken from [rows]; keep any existing local password, or
  /// leave blank when the remote seed has no prior row.
  Future<void> applyFixedEmailMailersFromRemote(
    List<Map<String, dynamic>> rows, {
    String? localPasswordFallback,
  }) async {
    for (final row in rows) {
      final purpose = '${row['purpose'] ?? ''}'.trim();
      if (purpose.isEmpty) continue;
      final existingRows = await _db.query(
        'store_email_config',
        where: 'orgId = ? AND storeId = ? AND purpose = ?',
        whereArgs: [orgId, storeId, purpose],
        limit: 1,
      );
      final existing = existingRows.isEmpty ? null : existingRows.first;
      final existingPassword = '${existing?['password'] ?? ''}'.trim();
      final password = existingPassword.isNotEmpty
          ? existingPassword
          : (localPasswordFallback ?? '');
      // Never accept a password field from remote rows.
      final host = '${row['host'] ?? ''}'.trim();
      final username = '${row['username'] ?? ''}'.trim();
      final fromEmail = '${row['from_email'] ?? row['fromEmail'] ?? username}'
          .trim();
      final fromName = '${row['from_name'] ?? row['fromName'] ?? ''}'.trim();
      final port =
          (row['port'] as num?)?.toInt() ??
          int.tryParse('${row['port'] ?? ''}') ??
          587;
      final useTls = row['use_tls'] is bool
          ? (row['use_tls'] as bool)
          : ((row['use_tls'] as num?)?.toInt() ?? 1) == 1;

      await _db.insert('store_email_config', {
        'orgId': orgId,
        'storeId': storeId,
        'purpose': purpose,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'from_email': fromEmail,
        'from_name': fromName,
        'use_tls': useTls ? 1 : 0,
        'locked': 1,
        'pending_sync': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Ensure both fixed system mailers exist (immutable). Password is local-only.
  Future<void> ensureFixedSystemMailers({
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromEmail,
    required String reportsFromName,
    required String invoicesFromName,
    bool useTls = true,
  }) async {
    await applyFixedEmailMailersFromRemote([
      {
        'purpose': 'sales_reports',
        'host': host,
        'port': port,
        'username': username,
        'from_email': fromEmail,
        'from_name': reportsFromName,
        'use_tls': useTls,
        'locked': true,
      },
      {
        'purpose': 'invoice_booking',
        'host': host,
        'port': port,
        'username': username,
        'from_email': fromEmail,
        'from_name': invoicesFromName,
        'use_tls': useTls,
        'locked': true,
      },
    ], localPasswordFallback: password);
  }

  /// Ensure the fixed system report mailer row exists (immutable).
  Future<void> ensureFixedReportMailer({
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromEmail,
    required String fromName,
    bool useTls = true,
  }) async {
    await ensureFixedSystemMailers(
      host: host,
      port: port,
      username: username,
      password: password,
      fromEmail: fromEmail,
      reportsFromName: fromName,
      invoicesFromName: 'Ellan POS Invoices',
      useTls: useTls,
    );
  }

  static const String _storeInfoTable = 'store_info';
  static const String _organisationTable = 'organisation';
  static const String _storeSessionTable = 'store_session';
  static const String _deviceAccessTable = 'device_access_cache';
  static const String _syncAttemptsTable = 'sync_attempts';

  /// Soft safety cap so a misbehaving device cannot grow forever.
  static const int _syncAttemptsHardCap = 5000;

  /// Keep sync history for at least this many days on device.
  static const int _syncAttemptsKeepDays = 45;

  StoreScope get scope => StoreScope(orgId: orgId, storeId: storeId);

  Future<String?> get registeredDeviceId async {
    final row = await _loadDeviceAccess(_db, orgId);
    final deviceId = row?['deviceId'] as String? ?? '';
    return deviceId.isEmpty ? null : deviceId;
  }

  static Future<StoreConfig> _resolveConfig({
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) {
    if (config != null) {
      return Future.value(config);
    }
    return StoreConfig.loadFromFile(configPath);
  }

  static Future<CustomerRepository> _loadDirectoryRepository(
    String customerJson,
  ) async {
    final repository = await CustomerRepository.createInMemory();
    await repository.importCustomersFromJsonFile(customerJson);
    return repository;
  }

  Store._({
    required this.orgId,
    required this.organisationRemoteId,
    required this.orgName,
    required this.orgCode,
    required this.storeId,
    required this.storeRemoteId,
    required this.serviceInstanceId,
    required this.storeName,
    required this.logo,
    required this.uniqueId,
    required this.contactEmail,
    required this.phone,
    required this.contactPerson,
    required this.status,
    required this.serviceVariantType,
    required Database db,
    required OrdersRepository ordersRepo,
    required OffersRepository offersRepo,
    required ProductRepository productRepo,
    required CustomerRepository customerRepo,
    StorePrinterAdapter? printerAdapter,
    required Duration sessionDuration,
    required StoreConfig config,
  }) : _db = db,
       _ordersRepo = ordersRepo,
       _offersRepo = offersRepo,
       _productRepo = productRepo,
       _customerRepo = customerRepo,
       _printerAdapter = printerAdapter ?? StoreSimulatedPrinterAdapter(),
       _sessionDuration = sessionDuration,
       _config = config;

  /// Refresh sync/bootstrap settings without reopening the database.
  /// Used when the POS app repairs older sealed configs (new entities, URLs).
  void applyConfig(StoreConfig config) {
    _config = config;
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
    return printing.print(
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
    return printing.sendToKitchen(
      printerId,
      orderId,
      copies: copies,
      tableLabel: tableLabel,
      tokenNumber: tokenNumber,
      note: note,
    );
  }

  Future<List<StorePrinterInfo>> listAvailablePrinters() {
    return printing.listAvailablePrinters();
  }

  static Future<Store> createAndInit({
    required String orgId,
    String? organisationRemoteId,
    required String orgName,
    required String orgCode,
    required String storeId,
    String? storeRemoteId,
    required int serviceInstanceId,
    required String storeName,
    required String logo,
    required String uniqueId,
    required String contactEmail,
    required String phone,
    required String contactPerson,
    required String status,
    required String serviceVariantType,
    String? orderJson,
    String? productJson,
    String? customerJson,
    String? offerJson,
    String? tableJson,
    String? databasePath,
    Duration? sessionDuration,
    StoreConfig? config,
    StorePrinterAdapter? printerAdapter,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final resolvedSessionDuration =
        sessionDuration ?? resolvedConfig.defaultSessionDuration;
    final dbRoot = databasePath ?? await databaseFactoryFfi.getDatabasesPath();
    final dbFilePath = p.join(
      dbRoot,
      resolvedConfig.buildOrganisationDatabaseFileName(orgId),
    );
    if (await File(dbFilePath).exists()) {
      // Org DB may already exist from earlier branch stores. Upsert this store's
      // metadata before reopen so Restaurant/Grocery/Services SIs work on the
      // first open after the POS store list change.
      final existingDb = await _openDatabase(dbFilePath);
      try {
        await existingDb.insert(_organisationTable, {
          'orgId': orgId,
          'remote_id': organisationRemoteId ?? orgId,
          'org_name': orgName,
          'org_code': orgCode,
          'logo': logo,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _saveStoreDirectoryEntry(
          existingDb,
          StoreDirectoryEntry(
            orgId: orgId,
            orgName: orgName,
            orgCode: orgCode,
            storeId: storeId,
            remoteId: storeRemoteId,
            serviceInstanceId: serviceInstanceId,
            storeName: storeName,
            logo: logo,
            uniqueId: uniqueId.isNotEmpty ? uniqueId : storeId.padLeft(8, '0'),
            contactEmail: contactEmail,
            phone: phone,
            contactPerson: contactPerson,
            status: status,
            serviceVariantType: serviceVariantType,
          ),
        );
      } finally {
        await existingDb.close();
      }
      return reopenPersistent(
        orgId: orgId,
        storeId: storeId,
        uniqueId: uniqueId.isNotEmpty ? uniqueId : storeId.padLeft(8, '0'),
        databasePath: dbRoot,
        sessionDuration: resolvedSessionDuration,
        config: resolvedConfig,
        printerAdapter: printerAdapter,
      );
    }

    return openPersistent(
      orgId: orgId,
      organisationRemoteId: organisationRemoteId,
      orgName: orgName,
      orgCode: orgCode,
      storeId: storeId,
      storeRemoteId: storeRemoteId,
      serviceInstanceId: serviceInstanceId,
      storeName: storeName,
      logo: logo,
      uniqueId: uniqueId,
      contactEmail: contactEmail,
      phone: phone,
      contactPerson: contactPerson,
      status: status,
      serviceVariantType: serviceVariantType,
      orderJson: orderJson,
      productJson: productJson,
      customerJson: customerJson,
      offerJson: offerJson,
      tableJson: tableJson,
      databasePath: dbRoot,
      sessionDuration: resolvedSessionDuration,
      config: resolvedConfig,
      printerAdapter: printerAdapter,
    );
  }

  static Future<Store> createInMemory({
    required String orgId,
    String? organisationRemoteId,
    required String orgName,
    required String orgCode,
    required String storeId,
    String? storeRemoteId,
    required int serviceInstanceId,
    required String storeName,
    required String logo,
    required String uniqueId,
    required String contactEmail,
    required String phone,
    required String contactPerson,
    required String status,
    required String serviceVariantType,
    String? orderJson,
    String? productJson,
    String? customerJson,
    String? offerJson,
    String? tableJson,
    Duration? sessionDuration,
    StoreConfig? config,
    StorePrinterAdapter? printerAdapter,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    sqfliteFfiInit();
    final db = await _openDatabase(inMemoryDatabasePath);
    final ordersRepo = OrdersRepository(db);
    final offersRepo = OffersRepository(db);
    final productRepo = ProductRepository(db);
    final customerRepo = CustomerRepository(db);

    final store = Store._(
      orgId: orgId,
      organisationRemoteId: organisationRemoteId ?? orgId,
      orgName: orgName,
      orgCode: orgCode,
      storeId: storeId,
      storeRemoteId: storeRemoteId ?? storeId,
      serviceInstanceId: serviceInstanceId,
      storeName: storeName,
      logo: logo,
      uniqueId: uniqueId,
      contactEmail: contactEmail,
      phone: phone,
      contactPerson: contactPerson,
      status: status,
      serviceVariantType: serviceVariantType,
      db: db,
      ordersRepo: ordersRepo,
      offersRepo: offersRepo,
      productRepo: productRepo,
      customerRepo: customerRepo,
      printerAdapter: printerAdapter,
      sessionDuration: sessionDuration ?? resolvedConfig.defaultSessionDuration,
      config: resolvedConfig,
    );

    if (orderJson != null) {
      final file = File(orderJson);
      if (file.existsSync()) {
        await ordersRepo.importOrdersFromJsonFile(
          orderJson,
          scope: store.scope,
        );
      }
    }
    if (productJson != null && productJson.isNotEmpty) {
      final file = File(productJson);
      if (file.existsSync()) {
        final importer = ProductDataImporter(db);
        await importer.importFromJsonFile(productJson, scope: store.scope);
      }
    }
    if (customerJson != null) {
      final file = File(customerJson);
      if (file.existsSync()) {
        await customerRepo.importCustomersFromJsonFile(customerJson);
      }
    }
    if (offerJson != null) {
      final file = File(offerJson);
      if (file.existsSync()) {
        await offersRepo.importOffersFromJsonFile(
          offerJson,
          scope: store.scope,
        );
      }
    }
    if (tableJson != null && File(tableJson).existsSync()) {
      await store._importTablesFromJsonFile(
        store.scope,
        tableJson,
        skipAuth: true,
      );
    }

    return store;
  }

  static Future<Database> _openDatabase(String path) async {
    // Ensure parent directory exists before attempting to open database
    final file = File(path);
    await file.parent.create(recursive: true);

    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: BackendSetup.schemaVersion,
        onCreate: (db, version) async {
          await BackendSetup.createTablesForTest(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await BackendSetup.upgradeTablesForTest(db, oldVersion, newVersion);
        },
        onOpen: (db) async {
          // Repair missing tables/columns even when user_version is already current
          // (e.g. wallet_variants after a partial v48 upgrade).
          try {
            await BackendSetup.ensureSchemaRepairs(db);
          } catch (_) {}
        },
      ),
    );
  }

  static Future<void> _saveStoreInfo(Database db, Store store) {
    return db.insert(_storeInfoTable, {
      'uniqueId': store.uniqueId,
      'storeId': store.storeId,
      'remote_id': store.storeRemoteId,
      'orgId': store.orgId,
      'serviceInstanceId': store.serviceInstanceId,
      'storeName': store.storeName,
      'logo': store.logo,
      'contactEmail': store.contactEmail,
      'phone': store.phone,
      'contactPerson': store.contactPerson,
      'status': store.status,
      'serviceVariantType': store.serviceVariantType,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _saveStoreDirectoryEntry(
    Database db,
    StoreDirectoryEntry entry,
  ) async {
    final existing = await _loadStoreInfoByStoreId(
      db,
      orgId: entry.orgId,
      storeId: entry.storeId,
    );
    final row = <String, Object?>{
      'uniqueId': entry.uniqueId.isNotEmpty
          ? entry.uniqueId
          : (existing?['uniqueId'] as String? ?? entry.storeId),
      'storeId': entry.storeId,
      'remote_id': entry.remoteId,
      'orgId': entry.orgId,
      'serviceInstanceId': entry.serviceInstanceId,
      'storeName': entry.storeName,
      'logo': entry.logo,
      'contactEmail': entry.contactEmail,
      'phone': entry.phone,
      'contactPerson': entry.contactPerson,
      'status': entry.status,
      'serviceVariantType': entry.serviceVariantType,
      'address': entry.address.isNotEmpty
          ? entry.address
          : (existing?['address'] as String? ?? ''),
      'registration_number': entry.registrationNumber.isNotEmpty
          ? entry.registrationNumber
          : (existing?['registration_number'] as String? ?? ''),
      'tax_number': entry.taxNumber.isNotEmpty
          ? entry.taxNumber
          : (existing?['tax_number'] as String? ?? ''),
      'identifier': entry.identifier.isNotEmpty
          ? entry.identifier
          : (existing?['identifier'] as String? ?? ''),
    };
    if (existing != null) {
      // A directory refresh must not overwrite company edits (or a picked
      // logo) that were saved offline and have not been pushed yet.
      for (final flag in const ['logo_pending_sync', 'profile_pending_sync']) {
        if (existing.containsKey(flag)) row[flag] = existing[flag];
      }
      if ((existing['profile_pending_sync'] as num?)?.toInt() == 1) {
        for (final column in const [
          'storeName',
          'contactEmail',
          'phone',
          'address',
          'registration_number',
          'tax_number',
          'identifier',
        ]) {
          if (existing[column] != null) row[column] = existing[column];
        }
      }
      if ((existing['logo_pending_sync'] as num?)?.toInt() == 1 &&
          existing['logo'] != null) {
        row['logo'] = existing['logo'];
      }
    }
    await db.insert(
      _storeInfoTable,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _saveOrganisation(Database db, Store store) {
    return db.insert(_organisationTable, {
      'orgId': store.orgId,
      'remote_id': store.organisationRemoteId,
      'org_name': store.orgName,
      'org_code': store.orgCode,
      'logo': store.logo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> _loadStoreInfo(
    Database db,
    String uniqueId,
  ) async {
    final rows = await db.query(
      _storeInfoTable,
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>?> _loadStoreInfoByStoreId(
    Database db, {
    required String orgId,
    required String storeId,
  }) async {
    final rows = await db.query(
      _storeInfoTable,
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [orgId, storeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>?> _loadOrganisation(
    Database db,
    String orgId,
  ) async {
    final rows = await db.query(
      _organisationTable,
      where: 'orgId = ?',
      whereArgs: [orgId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> _saveSession(Database db, StoreSession session) async {
    await db.insert(_storeSessionTable, {
      'id': 1,
      'customerId': session.customerId,
      'email': session.email,
      'loginAt': session.loginAt,
      'role': session.storeRole,
      'org_role': session.organisationRole,
      'store_role': session.storeRole,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _clearSession(Database db) async {
    await db.delete(_storeSessionTable, where: 'id = ?', whereArgs: [1]);
  }

  static Future<void> _saveStoreRoleAccess(
    Database db,
    StoreRoleAccess access,
  ) {
    return db.insert('store_roles', {
      'remote_id':
          access.remoteId ??
          '${access.orgId}:${access.storeId}:${access.customerId}:${access.storeRole}',
      'customerId': access.customerId,
      'orgId': access.orgId,
      'storeId': access.storeId,
      'role': access.storeRole,
      'access_enabled': access.accessEnabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> _loadSession(Database db) async {
    final rows = await db.query(
      _storeSessionTable,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> _saveDeviceAccess(
    Database db, {
    required String orgId,
    required StoreDeviceRegistrationRequest request,
    required StoreDeviceRegistrationResult result,
  }) {
    return db.insert(_deviceAccessTable, {
      'orgId': orgId,
      'deviceId': result.deviceId.isNotEmpty
          ? result.deviceId
          : request.deviceId,
      'make': result.make.isNotEmpty ? result.make : request.make,
      'model': result.model.isNotEmpty ? result.model : request.model,
      'lat': result.lat ?? request.lat,
      'lan': result.lan ?? request.lan,
      'status': result.status,
      'message': result.message,
      'registered_at': result.registeredAt,
      'updated_at': result.updatedAt,
      'last_checked_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> _loadDeviceAccess(
    Database db,
    String orgId,
  ) async {
    final rows = await db.query(
      _deviceAccessTable,
      where: 'orgId = ?',
      whereArgs: [orgId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static StoreDeviceRegistrationRequest? _deviceRequestFromAccessRow(
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return null;
    }
    final deviceId = row['deviceId'] as String? ?? '';
    final make = row['make'] as String? ?? '';
    final model = row['model'] as String? ?? '';
    if (deviceId.isEmpty || make.isEmpty || model.isEmpty) {
      return null;
    }
    return StoreDeviceRegistrationRequest(
      deviceId: deviceId,
      make: make,
      model: model,
      lat: (row['lat'] as num?)?.toDouble(),
      lan: (row['lan'] as num?)?.toDouble(),
    );
  }

  static bool _isActiveStatus(String? status) =>
      (status ?? '').toLowerCase() == 'active';

  static bool _isActiveCustomerStatus(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'active' ||
        normalized == 'approved' ||
        normalized == '1';
  }

  static Future<Database?> _openExistingOrganisationDatabaseIfPresent({
    required String orgId,
    required String dbRoot,
    required StoreConfig config,
  }) async {
    final dbFilePath = p.join(
      dbRoot,
      config.buildOrganisationDatabaseFileName(orgId),
    );
    if (!await File(dbFilePath).exists()) {
      return null;
    }
    sqfliteFfiInit();
    return _openDatabase(dbFilePath);
  }

  static Future<int> _saveSyncAttempt(
    Database db,
    StoreSyncOperationResult result,
  ) async {
    final id = await db.insert(_syncAttemptsTable, {
      'entity': result.entity,
      'direction': result.direction,
      'started_at': result.startedAt,
      'completed_at': result.completedAt,
      'processed_count': result.processedCount,
      'success_count': result.successCount,
      'failure_count': result.failureCount,
      'skipped': result.skipped ? 1 : 0,
      'success': result.success ? 1 : 0,
      'message': result.message,
    });
    await _pruneSyncAttempts(db);
    return id;
  }

  /// Keep sync attempts for [_syncAttemptsKeepDays], with a hard row cap.
  static Future<void> _pruneSyncAttempts(Database db) async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: _syncAttemptsKeepDays))
        .toIso8601String();
    await db.rawDelete(
      '''
      DELETE FROM $_syncAttemptsTable
      WHERE started_at < ?
      ''',
      [cutoff],
    );
    await db.rawDelete(
      '''
      DELETE FROM $_syncAttemptsTable
      WHERE id NOT IN (
        SELECT id FROM $_syncAttemptsTable
        ORDER BY id DESC
        LIMIT ?
      )
      ''',
      [_syncAttemptsHardCap],
    );
  }

  static Future<List<Map<String, dynamic>>> _loadSyncAttempts(
    Database db, {
    int limit = 500,
  }) {
    final capped = limit <= 0
        ? 500
        : (limit > _syncAttemptsHardCap ? _syncAttemptsHardCap : limit);
    return db.query(_syncAttemptsTable, orderBy: 'id DESC', limit: capped);
  }

  static Future<Store> openPersistent({
    required String orgId,
    String? organisationRemoteId,
    required String orgName,
    required String orgCode,
    required String storeId,
    String? storeRemoteId,
    required int serviceInstanceId,
    required String storeName,
    required String logo,
    required String uniqueId,
    required String contactEmail,
    required String phone,
    required String contactPerson,
    required String status,
    required String serviceVariantType,
    String? orderJson,
    String? productJson,
    String? customerJson,
    String? offerJson,
    String? tableJson,
    String? databasePath,
    Duration? sessionDuration,
    StoreConfig? config,
    StorePrinterAdapter? printerAdapter,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    sqfliteFfiInit();
    final dbRoot = databasePath ?? await databaseFactoryFfi.getDatabasesPath();
    final dbFilePath = p.join(
      dbRoot,
      resolvedConfig.buildOrganisationDatabaseFileName(orgId),
    );
    final db = await _openDatabase(dbFilePath);
    final ordersRepo = OrdersRepository(db);
    final offersRepo = OffersRepository(db);
    final productRepo = ProductRepository(db);
    final customerRepo = CustomerRepository(db);

    final store = Store._(
      orgId: orgId,
      organisationRemoteId: organisationRemoteId ?? orgId,
      orgName: orgName,
      orgCode: orgCode,
      storeId: storeId,
      storeRemoteId: storeRemoteId ?? storeId,
      serviceInstanceId: serviceInstanceId,
      storeName: storeName,
      logo: logo,
      uniqueId: uniqueId,
      contactEmail: contactEmail,
      phone: phone,
      contactPerson: contactPerson,
      status: status,
      serviceVariantType: serviceVariantType,
      db: db,
      ordersRepo: ordersRepo,
      offersRepo: offersRepo,
      productRepo: productRepo,
      customerRepo: customerRepo,
      printerAdapter: printerAdapter,
      sessionDuration: sessionDuration ?? resolvedConfig.defaultSessionDuration,
      config: resolvedConfig,
    );

    await _saveOrganisation(db, store);
    await _saveStoreInfo(db, store);

    if (orderJson != null && File(orderJson).existsSync()) {
      await ordersRepo.importOrdersFromJsonFile(orderJson, scope: store.scope);
    }
    if (productJson != null && File(productJson).existsSync()) {
      final importer = ProductDataImporter(db);
      await importer.importFromJsonFile(productJson, scope: store.scope);
    }
    if (customerJson != null && File(customerJson).existsSync()) {
      await customerRepo.importCustomersFromJsonFile(customerJson);
    }
    if (offerJson != null && File(offerJson).existsSync()) {
      await offersRepo.importOffersFromJsonFile(offerJson, scope: store.scope);
    }
    if (tableJson != null && File(tableJson).existsSync()) {
      await store._importTablesFromJsonFile(
        store.scope,
        tableJson,
        skipAuth: true,
      );
    }

    return store;
  }

  static Future<Store> reopenPersistent({
    String? orgId,
    String? storeId,
    required String uniqueId,
    String? databasePath,
    Duration? sessionDuration,
    StoreConfig? config,
    StorePrinterAdapter? printerAdapter,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    sqfliteFfiInit();
    final dbRoot = databasePath ?? await databaseFactoryFfi.getDatabasesPath();
    final resolvedOrgId =
        orgId ?? _inferOrganisationId(resolvedConfig, uniqueId: uniqueId);
    final dbFilePath = p.join(
      dbRoot,
      resolvedConfig.buildOrganisationDatabaseFileName(resolvedOrgId),
    );
    final db = await _openDatabase(dbFilePath);
    final storeInfo = storeId != null
        ? await _loadStoreInfoByStoreId(
            db,
            orgId: resolvedOrgId,
            storeId: storeId,
          )
        : await _loadStoreInfo(db, uniqueId);
    if (storeInfo == null) {
      await db.close();
      throw StateError(
        'No persisted store metadata found for orgId=$resolvedOrgId uniqueId=$uniqueId storeId=${storeId ?? ''}',
      );
    }
    final organisation = await _loadOrganisation(
      db,
      storeInfo['orgId'] as String? ?? '',
    );

    return Store._(
      orgId: storeInfo['orgId'] as String? ?? '',
      organisationRemoteId:
          organisation?['remote_id'] as String? ??
          (storeInfo['orgId'] as String?),
      orgName: organisation?['org_name'] as String? ?? '',
      orgCode: organisation?['org_code'] as String? ?? '',
      storeId: storeInfo['storeId'] as String? ?? '',
      storeRemoteId:
          storeInfo['remote_id'] as String? ??
          (storeInfo['storeId'] as String?),
      serviceInstanceId: (storeInfo['serviceInstanceId'] as num?)?.toInt() ?? 0,
      storeName: storeInfo['storeName'] as String? ?? '',
      logo: storeInfo['logo'] as String? ?? '',
      uniqueId: storeInfo['uniqueId'] as String? ?? uniqueId,
      contactEmail: storeInfo['contactEmail'] as String? ?? '',
      phone: storeInfo['phone'] as String? ?? '',
      contactPerson: storeInfo['contactPerson'] as String? ?? '',
      status: storeInfo['status'] as String? ?? '',
      serviceVariantType: storeInfo['serviceVariantType'] as String? ?? '',
      db: db,
      ordersRepo: OrdersRepository(db),
      offersRepo: OffersRepository(db),
      productRepo: ProductRepository(db),
      customerRepo: CustomerRepository(db),
      printerAdapter: printerAdapter,
      sessionDuration: sessionDuration ?? resolvedConfig.defaultSessionDuration,
      config: resolvedConfig,
    );
  }

  static String _inferOrganisationId(
    StoreConfig config, {
    required String uniqueId,
  }) {
    for (final store in config.stores) {
      if (store.uniqueId == uniqueId) {
        return store.orgId;
      }
    }
    if (config.testStore?.uniqueId == uniqueId) {
      return config.testStore!.orgId;
    }
    if (config.defaultStore?.uniqueId == uniqueId) {
      return config.defaultStore!.orgId;
    }
    return uniqueId;
  }

  static Future<Store> createForTest({
    String? orderJson,
    String? productJson,
    String? customerJson,
    String? offerJson,
    String? tableJson,
    Duration? sessionDuration,
    StoreConfig? config,
    StoreMetadataConfig? metadata,
    StorePrinterAdapter? printerAdapter,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final testStore =
        metadata ??
        resolvedConfig.testStore ??
        StoreConfig.defaultTestStoreMetadata;
    return createInMemory(
      orgId: testStore.orgId,
      orgName: testStore.orgName,
      orgCode: testStore.orgCode,
      storeId: testStore.storeId,
      serviceInstanceId: testStore.serviceInstanceId,
      storeName: testStore.storeName,
      logo: testStore.logo,
      uniqueId: testStore.uniqueId,
      contactEmail: testStore.contactEmail,
      phone: testStore.phone,
      contactPerson: testStore.contactPerson,
      status: testStore.status,
      serviceVariantType: testStore.serviceVariantType,
      orderJson: orderJson ?? resolvedConfig.assetPaths.orders,
      productJson: productJson ?? resolvedConfig.assetPaths.products,
      customerJson: customerJson ?? resolvedConfig.assetPaths.customers,
      offerJson: offerJson ?? resolvedConfig.assetPaths.offers,
      tableJson: tableJson,
      sessionDuration: sessionDuration ?? resolvedConfig.defaultSessionDuration,
      config: resolvedConfig,
      printerAdapter: printerAdapter,
    );
  }

  static Future<StoreOrganisation?> resolveOrganisationByCode(
    String orgCode, {
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final bootstrap = await _fetchBootstrapPayload(
      config: resolvedConfig,
      orgCode: orgCode,
    );
    if (bootstrap == null) {
      return resolvedConfig.findOrganisationByCode(orgCode);
    }
    final organisationRow = _requireBootstrapOrganisation(bootstrap);
    if (organisationRow == null) {
      return resolvedConfig.findOrganisationByCode(orgCode);
    }
    return StoreOrganisation.fromRow(organisationRow);
  }

  static Future<StoreOrganisation?> resolveOrganisationByCodeFromUrl(
    String orgCode, {
    required String lookupUrl,
  }) async {
    final bootstrap = await _fetchBootstrapPayloadFromUrl(
      lookupUrl: lookupUrl,
      orgCode: orgCode,
    );
    if (bootstrap == null) {
      return null;
    }
    final organisationRow = _requireBootstrapOrganisation(bootstrap);
    if (organisationRow == null) {
      return null;
    }
    return StoreOrganisation.fromRow(organisationRow);
  }

  static Future<List<StoreDirectoryEntry>> listStoresForOrganisation(
    String orgId, {
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final bootstrap = await _fetchBootstrapPayload(
      config: resolvedConfig,
      orgId: orgId,
    );
    if (bootstrap == null) {
      return resolvedConfig
          .storesForOrganisation(orgId)
          .map((store) => store.toDirectoryEntry())
          .toList(growable: false);
    }
    return _extractBootstrapStores(
      bootstrap,
    ).map(StoreDirectoryEntry.fromRow).toList(growable: false);
  }

  static Future<StoreOrganisationLoginResult?> loginToOrganisation({
    required String orgCode,
    required String email,
    required String password,
    String? customerJson,
    String? deviceId,
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,

    /// When true, skip remote gateway login and use local customer hashes.
    bool preferLocal = false,

    /// Cached bootstrap payload for offline local login (avoids network lookup).
    Map<String, dynamic>? localBootstrap,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );

    final remoteLoginUrl = preferLocal
        ? null
        : _resolveRemoteLoginUrl(resolvedConfig);
    if (remoteLoginUrl != null) {
      return _loginToOrganisationRemote(
        orgCode: orgCode,
        email: email,
        password: password,
        deviceId: deviceId,
        loginUrl: remoteLoginUrl,
      );
    }

    // Offline / lease-valid path: never hit bootstrap lookup over the network.
    final Map<String, dynamic>? bootstrap;
    if (preferLocal) {
      bootstrap = localBootstrap;
    } else {
      bootstrap =
          localBootstrap ??
          await _fetchBootstrapPayload(
            config: resolvedConfig,
            orgCode: orgCode,
          );
    }
    final organisationRow = bootstrap == null
        ? null
        : _requireBootstrapOrganisation(bootstrap);
    final organisation = organisationRow == null
        ? resolvedConfig.findOrganisationByCode(orgCode)
        : StoreOrganisation.fromRow(organisationRow);
    if (organisation == null) {
      return null;
    }

    Map<String, dynamic>? customer;
    List<Map<String, dynamic>> roles = const [];

    // 1) Bootstrap / customers JSON (setup-time hashes — may be stale after
    //    the first online login that rotates PosUserCredential).
    final repository = bootstrap != null
        ? await _loadDirectoryRepositoryFromData(bootstrap)
        : await _loadDirectoryRepository(
            customerJson ?? resolvedConfig.assetPaths.customers,
          );
    try {
      customer = await repository.authenticateCustomerForOrganisation(
        orgId: organisation.orgId,
        email: email,
        password: password,
      );
      if (customer != null) {
        roles = await repository.listStoreRolesForCustomer(
          orgId: organisation.orgId,
          customerId: customer['customerId'] as String? ?? '',
        );
      }
    } finally {
      await repository.close();
    }

    // 2) Lease-valid cold start: fall back to the org SQLite customers table,
    //    which is updated with the real password hash on online login.
    if (customer == null && preferLocal) {
      try {
        final dbRoot = await databaseFactoryFfi.getDatabasesPath();
        final existingDb = await _openExistingOrganisationDatabaseIfPresent(
          orgId: organisation.orgId,
          dbRoot: dbRoot,
          config: resolvedConfig,
        );
        if (existingDb != null) {
          try {
            final localRepo = CustomerRepository(existingDb);
            customer = await localRepo.authenticateCustomerForOrganisation(
              orgId: organisation.orgId,
              email: email,
              password: password,
            );
            if (customer != null) {
              roles = await localRepo.listStoreRolesForCustomer(
                orgId: organisation.orgId,
                customerId: customer['customerId'] as String? ?? '',
              );
            }
          } finally {
            // Only close when this open is a separate handle. If the store
            // already holds the same single-instance DB, closing would break it.
            try {
              await existingDb.close();
            } catch (_) {}
          }
        }
      } catch (_) {
        // Treat local DB open/query failures as failed auth, not a crash.
        customer = null;
      }
    }

    if (customer == null) {
      return null;
    }

    final bootstrapStores = bootstrap != null
        ? _extractBootstrapStores(bootstrap).map(StoreDirectoryEntry.fromRow)
        : resolvedConfig
              .storesForOrganisation(organisation.orgId)
              .map((store) => store.toDirectoryEntry());
    var storesById = {
      for (final store in bootstrapStores) store.storeId: store,
    };

    // When roles exist in SQLite but bootstrap store list is thin, fill from DB.
    if (preferLocal && roles.isNotEmpty) {
      final missing = roles
          .map((row) => row['storeId'] as String? ?? '')
          .where((id) => id.isNotEmpty && !storesById.containsKey(id))
          .toList(growable: false);
      if (missing.isNotEmpty) {
        try {
          final dbRoot = await databaseFactoryFfi.getDatabasesPath();
          final existingDb = await _openExistingOrganisationDatabaseIfPresent(
            orgId: organisation.orgId,
            dbRoot: dbRoot,
            config: resolvedConfig,
          );
          if (existingDb != null) {
            try {
              final storeRows = await existingDb.query(
                _storeInfoTable,
                where: 'orgId = ?',
                whereArgs: [organisation.orgId],
              );
              for (final row in storeRows) {
                final entry = StoreDirectoryEntry.fromRow({
                  ...row,
                  'org_name': organisation.orgName,
                  'org_code': organisation.orgCode,
                });
                storesById[entry.storeId] = entry;
              }
            } finally {
              try {
                await existingDb.close();
              } catch (_) {}
            }
          }
        } catch (_) {
          // Keep bootstrap store list; missing extras are non-fatal for login.
        }
      }
    }

    final accessibleStores = roles
        .map(StoreRoleAccess.fromRow)
        .where((access) => storesById.containsKey(access.storeId))
        .map(
          (access) => StoreAccessibleStore(
            store: storesById[access.storeId]!,
            access: access,
          ),
        )
        .toList(growable: false);

    if (accessibleStores.isEmpty) {
      return null;
    }

    return StoreOrganisationLoginResult(
      organisation: organisation,
      customerId: customer['customerId'] as String? ?? '',
      customerName: customer['name'] as String? ?? '',
      email: customer['email'] as String? ?? email,
      organisationRole: customer['role'] as String? ?? '',
      accessibleStores: accessibleStores,
      customerRow: Map<String, dynamic>.from(customer),
    );
  }

  static Future<StoreOrganisationLoginResult?> _loginToOrganisationRemote({
    required String orgCode,
    required String email,
    required String password,
    required String loginUrl,
    String? deviceId,
  }) async {
    final resolvedLoginUrl =
        _normalizePosGatewayLoginUrl(loginUrl) ?? loginUrl.trim();
    final body = <String, dynamic>{
      'orgCode': orgCode,
      'email': email,
      'password': password,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    };
    final response = await http.post(
      Uri.parse(resolvedLoginUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.notFound) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Login failed with status ${response.statusCode}.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody['message'] != null) {
          message = errorBody['message'].toString();
        }
      } catch (_) {}
      throw StateError(message);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['ok'] == false) {
      return null;
    }

    final organisationRaw = payload['organisation'];
    if (organisationRaw is! Map) {
      return null;
    }
    final organisation = StoreOrganisation.fromRow(
      organisationRaw.cast<String, dynamic>(),
    );

    final accessibleRaw = payload['accessibleStores'];
    final accessibleStores = <StoreAccessibleStore>[];
    if (accessibleRaw is List) {
      for (final entry in accessibleRaw) {
        if (entry is! Map) continue;
        final row = entry.cast<String, dynamic>();
        final storeRaw = row['store'];
        final accessRaw = row['access'];
        if (storeRaw is! Map || accessRaw is! Map) continue;
        accessibleStores.add(
          StoreAccessibleStore(
            store: StoreDirectoryEntry.fromRow(
              storeRaw.cast<String, dynamic>(),
            ),
            access: StoreRoleAccess.fromRow(accessRaw.cast<String, dynamic>()),
          ),
        );
      }
    }
    if (accessibleStores.isEmpty) {
      return null;
    }

    final si = payload['service_instance_id'];
    return StoreOrganisationLoginResult(
      organisation: organisation,
      customerId: payload['customerId'] as String? ?? '',
      customerName: payload['customerName'] as String? ?? '',
      email: payload['email'] as String? ?? email,
      organisationRole: payload['organisationRole'] as String? ?? '',
      accessibleStores: accessibleStores,
      customerRow: payload['customer'] is Map
          ? (payload['customer'] as Map).cast<String, dynamic>()
          : null,
      accessToken: '${payload['access_token'] ?? ''}'.trim().isEmpty
          ? null
          : '${payload['access_token']}'.trim(),
      refreshToken: '${payload['refresh_token'] ?? ''}'.trim().isEmpty
          ? null
          : '${payload['refresh_token']}'.trim(),
      sessionId: '${payload['session_id'] ?? ''}'.trim().isEmpty
          ? null
          : '${payload['session_id']}'.trim(),
      serviceInstanceId: si == null || '$si'.trim().isEmpty
          ? null
          : '$si'.trim(),
    );
  }

  static String? _resolveRemoteLoginUrl(StoreConfig config) {
    final configured = _normalizePosGatewayLoginUrl(config.bootstrap.loginUrl);
    if (configured != null) {
      return configured;
    }
    // Derive from sync.base_url when login_url was sealed away. base_url may be
    // the origin (http://host:port) or the gateway root (.../api/pos).
    final base = config.sync.baseUrl.trim();
    if (base.isEmpty) {
      return null;
    }
    final normalized = base.replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/api/pos')) {
      return _normalizePosGatewayLoginUrl('$normalized/login');
    }
    return _normalizePosGatewayLoginUrl('$normalized/api/pos/login');
  }

  /// Collapses accidental `/api/pos/api/pos/...` from older cached configs.
  static String? _normalizePosGatewayLoginUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    while (url.contains('/api/pos/api/pos')) {
      url = url.replaceAll('/api/pos/api/pos', '/api/pos');
    }
    return url;
  }

  static Future<StoreOrganisationBootstrapSyncResult?>
  syncOrganisationBootstrap({
    required String orgCode,
    String? customerJson,
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final bootstrap = await _fetchBootstrapPayload(
      config: resolvedConfig,
      orgCode: orgCode,
    );
    if (bootstrap == null) {
      final organisation = resolvedConfig.findOrganisationByCode(orgCode);
      if (organisation == null) {
        return null;
      }

      final payload = await _loadOrganisationCustomerPayload(
        orgId: organisation.orgId,
        customerJson: customerJson,
        config: resolvedConfig,
      );
      final customerRows = _extractRowList(payload['data'])
          .where(
            (row) =>
                (row['orgId'] as String? ?? organisation.orgId) ==
                organisation.orgId,
          )
          .toList(growable: false);
      final storeRoleRows = _extractRowList(payload['store_roles'])
          .where(
            (row) =>
                (row['orgId'] as String? ?? organisation.orgId) ==
                organisation.orgId,
          )
          .toList(growable: false);

      return StoreOrganisationBootstrapSyncResult(
        organisation: organisation,
        stores: resolvedConfig
            .storesForOrganisation(organisation.orgId)
            .map((store) => store.toDirectoryEntry())
            .toList(growable: false),
        customers: customerRows
            .map(StoreCustomer.fromRow)
            .toList(growable: false),
        storeRoles: storeRoleRows
            .map(StoreRoleAccess.fromRow)
            .toList(growable: false),
        organisationRoles: _extractOrganisationRoleRows(payload, customerRows),
      );
    }

    final organisationRow = _requireBootstrapOrganisation(bootstrap);
    if (organisationRow == null) {
      return null;
    }
    final organisation = StoreOrganisation.fromRow(organisationRow);
    final customerRows = _extractRowList(bootstrap['data'])
        .where(
          (row) =>
              (row['orgId'] as String? ?? organisation.orgId) ==
              organisation.orgId,
        )
        .toList(growable: false);
    final storeRoleRows = _extractRowList(bootstrap['store_roles'])
        .where(
          (row) =>
              (row['orgId'] as String? ?? organisation.orgId) ==
              organisation.orgId,
        )
        .toList(growable: false);

    return StoreOrganisationBootstrapSyncResult(
      organisation: organisation,
      stores: _extractBootstrapStores(
        bootstrap,
      ).map(StoreDirectoryEntry.fromRow).toList(growable: false),
      customers: customerRows
          .map(StoreCustomer.fromRow)
          .toList(growable: false),
      storeRoles: storeRoleRows
          .map(StoreRoleAccess.fromRow)
          .toList(growable: false),
      organisationRoles: _extractOrganisationRoleRows(bootstrap, customerRows),
    );
  }

  static Future<StoreOrganisationBootstrapSyncResult?>
  syncOrganisationBootstrapFromUrl({
    required String orgCode,
    required String lookupUrl,
  }) async {
    final bootstrap = await _fetchBootstrapPayloadFromUrl(
      lookupUrl: lookupUrl,
      orgCode: orgCode,
    );
    if (bootstrap == null) {
      return null;
    }
    final organisationRow = _requireBootstrapOrganisation(bootstrap);
    if (organisationRow == null) {
      return null;
    }
    final organisation = StoreOrganisation.fromRow(organisationRow);
    final customerRows = _extractRowList(bootstrap['data'])
        .where(
          (row) =>
              (row['orgId'] as String? ?? organisation.orgId) ==
              organisation.orgId,
        )
        .toList(growable: false);
    final storeRoleRows = _extractRowList(bootstrap['store_roles'])
        .where(
          (row) =>
              (row['orgId'] as String? ?? organisation.orgId) ==
              organisation.orgId,
        )
        .toList(growable: false);

    return StoreOrganisationBootstrapSyncResult(
      organisation: organisation,
      stores: _extractBootstrapStores(
        bootstrap,
      ).map(StoreDirectoryEntry.fromRow).toList(growable: false),
      customers: customerRows
          .map(StoreCustomer.fromRow)
          .toList(growable: false),
      storeRoles: storeRoleRows
          .map(StoreRoleAccess.fromRow)
          .toList(growable: false),
      organisationRoles: _extractOrganisationRoleRows(bootstrap, customerRows),
    );
  }

  static Future<CustomerRepository> _loadDirectoryRepositoryFromData(
    Map<String, dynamic> data,
  ) async {
    final repository = await CustomerRepository.createInMemory();
    await repository.importCustomersFromJsonData(data);
    return repository;
  }

  static Future<Map<String, dynamic>?> _fetchBootstrapPayload({
    required StoreConfig config,
    String? orgCode,
    String? orgId,
  }) async {
    if (!config.bootstrap.isConfigured) {
      return null;
    }
    return _fetchBootstrapPayloadFromUrl(
      lookupUrl: config.bootstrap.lookupUrl,
      orgCode: orgCode,
      orgId: orgId,
    );
  }

  static Future<Map<String, dynamic>?> _fetchBootstrapPayloadFromUrl({
    required String lookupUrl,
    String? orgCode,
    String? orgId,
  }) async {
    final parsedLookupUri = Uri.parse(lookupUrl);
    final mergedQueryParameters = <String, String>{
      for (final entry in parsedLookupUri.queryParametersAll.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.last,
      if (orgCode != null && orgCode.isNotEmpty) 'orgCode': orgCode,
      if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
    };
    final uri = parsedLookupUri.replace(queryParameters: mergedQueryParameters);
    final response = await http.get(uri);
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Bootstrap lookup failed with status ${response.statusCode}.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Map<String, dynamic>? _requireBootstrapOrganisation(
    Map<String, dynamic> payload,
  ) {
    final value = payload['organisation'];
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  static List<Map<String, dynamic>> _extractBootstrapStores(
    Map<String, dynamic> payload,
  ) {
    return _extractRowList(payload['stores']);
  }

  static List<StoreOrganisationRoleRecord> _extractOrganisationRoleRows(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> customerRows,
  ) {
    final orgRoleRows = _extractRowList(payload['org_roles']);
    if (orgRoleRows.isNotEmpty) {
      return orgRoleRows
          .map(StoreOrganisationRoleRecord.fromRow)
          .toList(growable: false);
    }
    return customerRows
        .map(StoreOrganisationRoleRecord.fromCustomerRow)
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> _loadOrganisationCustomerPayload({
    required String orgId,
    required StoreConfig config,
    String? customerJson,
  }) async {
    final customerSync = config.sync.customers;
    if (customerSync.canImport) {
      final uri = _buildImportUri(customerSync.importUrl, orgId: orgId);
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Customers bootstrap import failed with status ${response.statusCode}.',
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final filePath = customerJson ?? config.assetPaths.customers;
    final content = await File(filePath).readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  static Uri _buildImportUri(
    String rawUrl, {
    required String orgId,
    String? storeId,
    String? deviceId,
    int? limit,
    String? cursor,
    String? since,
    Map<String, String> extraQuery = const {},
  }) {
    final uri = Uri.parse(rawUrl);
    final queryParameters = <String, String>{
      ...uri.queryParameters,
      ...extraQuery,
      'orgId': orgId,
    };
    if (storeId != null && storeId.isNotEmpty) {
      queryParameters['storeId'] = storeId;
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      queryParameters['deviceId'] = deviceId;
    }
    if (limit != null && limit > 0) {
      queryParameters['limit'] = '$limit';
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }
    if (since != null && since.isNotEmpty) {
      queryParameters['since'] = since;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  static Uri _buildExportUri(
    String rawUrl, {
    String? orgId,
    String? storeId,
    String? deviceId,
  }) {
    final uri = Uri.parse(rawUrl);
    final queryParameters = <String, String>{...uri.queryParameters};
    if (orgId != null && orgId.isNotEmpty) {
      queryParameters['orgId'] = orgId;
    }
    if (storeId != null && storeId.isNotEmpty) {
      queryParameters['storeId'] = storeId;
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      queryParameters['deviceId'] = deviceId;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  static List<Map<String, dynamic>> _extractRowList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }

  static Future<StoreDeviceRegistrationResult?> registerDeviceForOrganisation({
    required String orgId,
    required StoreDeviceRegistrationRequest request,
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    if (!resolvedConfig.bootstrap.requiresDeviceRegistration) {
      return null;
    }
    try {
      final registration = await _submitDeviceRegistration(
        orgId: orgId,
        request: request,
        config: resolvedConfig,
      );
      if (!registration.isActive) {
        throw StoreDeviceAccessException(
          registration.message ??
              'This device is not active for organisation $orgId.',
        );
      }
      return registration;
    } on StoreDeviceAccessException {
      rethrow;
    } catch (error) {
      throw StoreDeviceAccessException('Device registration failed: $error');
    }
  }

  static Future<StoreDeviceRegistrationResult> _submitDeviceRegistration({
    required String orgId,
    required StoreDeviceRegistrationRequest request,
    required StoreConfig config,
  }) async {
    final response = await http.post(
      Uri.parse(config.bootstrap.deviceRegistrationUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson(orgId: orgId)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Device registration failed with status ${response.statusCode}.',
      );
    }
    return StoreDeviceRegistrationResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<Store> openAccessibleStore({
    required StoreOrganisationLoginResult login,
    required String storeId,
    StoreDeviceRegistrationRequest? deviceRegistration,
    String? orderJson,
    String? productJson,
    String? customerJson,
    String? offerJson,
    String? tableJson,
    String? databasePath,
    Duration? sessionDuration,
    StoreConfig? config,
    String configPath = StoreConfig.defaultAssetPath,
  }) async {
    final resolvedConfig = await _resolveConfig(
      config: config,
      configPath: configPath,
    );
    final accessibleStore = login.accessibleStores
        .where((entry) => entry.store.storeId == storeId)
        .firstWhere(
          (_) => true,
          orElse: () => throw StoreAuthorizationException(
            'Customer does not have access to storeId=$storeId.',
          ),
        );
    var metadata = accessibleStore.store;
    var dbRoot = databasePath;

    // If no explicit path provided, get default and validate it
    if (dbRoot == null) {
      dbRoot = await databaseFactoryFfi.getDatabasesPath();

      // Fallback to temp directory if default path is invalid (e.g., read-only system path)
      if (dbRoot.startsWith('/') &&
          !dbRoot.startsWith(Directory.systemTemp.path)) {
        try {
          // Check if we can write to this directory
          final testFile = File(p.join(dbRoot, '.write_test'));
          await testFile.create();
          await testFile.delete();
        } catch (e) {
          // If we can't write, use system temp directory instead
          dbRoot = Directory.systemTemp.path;
        }
      }
    }

    final existingDb = await _openExistingOrganisationDatabaseIfPresent(
      orgId: metadata.orgId,
      dbRoot: dbRoot,
      config: resolvedConfig,
    );
    StoreDeviceRegistrationRequest? effectiveDeviceRegistration =
        deviceRegistration;
    StoreDeviceRegistrationResult? remoteDeviceAccess;
    var remoteConnectivityAvailable = false;

    try {
      // Always persist stores from the login result. First-launch configs clear
      // bootstrap.lookup_url, so we cannot rely on a remote refresh here.
      if (existingDb != null) {
        for (final accessible in login.accessibleStores) {
          if (accessible.store.orgId == metadata.orgId) {
            await _saveStoreDirectoryEntry(existingDb, accessible.store);
          }
        }
        await _saveStoreDirectoryEntry(existingDb, metadata);
      }

      if (resolvedConfig.bootstrap.isConfigured) {
        try {
          final bootstrap = await _fetchBootstrapPayload(
            config: resolvedConfig,
            orgId: metadata.orgId,
          );
          if (bootstrap != null) {
            remoteConnectivityAvailable = true;
            for (final row in _extractBootstrapStores(bootstrap)) {
              final entry = StoreDirectoryEntry.fromRow(row);
              if (existingDb != null) {
                await _saveStoreDirectoryEntry(existingDb, entry);
              }
              if (entry.storeId == metadata.storeId) {
                metadata = entry;
              }
            }
          }
        } catch (_) {}
      }

      if (!_isActiveStatus(metadata.status)) {
        if (existingDb != null) {
          await _saveStoreDirectoryEntry(existingDb, metadata);
        }
        throw StoreAuthorizationException(
          'Store ${metadata.storeId} is not active.',
        );
      }

      if (resolvedConfig.bootstrap.requiresDeviceRegistration) {
        effectiveDeviceRegistration ??= _deviceRequestFromAccessRow(
          existingDb == null
              ? null
              : await _loadDeviceAccess(existingDb, metadata.orgId),
        );
        if (effectiveDeviceRegistration == null) {
          throw const StoreDeviceAccessException(
            'Device registration is required before opening the store.',
          );
        }
        try {
          remoteDeviceAccess = await _submitDeviceRegistration(
            orgId: metadata.orgId,
            request: effectiveDeviceRegistration,
            config: resolvedConfig,
          );
          remoteConnectivityAvailable = true;
          if (existingDb != null) {
            await _saveDeviceAccess(
              existingDb,
              orgId: metadata.orgId,
              request: effectiveDeviceRegistration,
              result: remoteDeviceAccess,
            );
          }
          if (!remoteDeviceAccess.isActive) {
            throw StoreDeviceAccessException(
              remoteDeviceAccess.message ??
                  'This device is not active for organisation ${metadata.orgId}.',
            );
          }
        } catch (error) {
          if (remoteDeviceAccess != null && !remoteDeviceAccess.isActive) {
            rethrow;
          }
          final cachedAccess = existingDb == null
              ? null
              : await _loadDeviceAccess(existingDb, metadata.orgId);
          final hasActiveCachedAccess =
              cachedAccess != null &&
              _isActiveStatus(cachedAccess['status'] as String?);
          if (!hasActiveCachedAccess) {
            throw StoreDeviceAccessException(
              'Device registration failed and no active cached access is available: $error',
            );
          }
        }
      }
    } finally {
      await existingDb?.close();
    }

    final shouldRestoreFromRemote =
        resolvedConfig.sync.customers.canImport ||
        resolvedConfig.sync.orders.canImport ||
        resolvedConfig.sync.products.canImport ||
        resolvedConfig.sync.credits.canImport ||
        resolvedConfig.sync.tables.canImport ||
        resolvedConfig.sync.wallets.canImport;

    final store = await Store.createAndInit(
      orgId: metadata.orgId,
      organisationRemoteId: login.organisation.remoteId,
      orgName: metadata.orgName,
      orgCode: metadata.orgCode,
      storeId: metadata.storeId,
      storeRemoteId: metadata.remoteId,
      serviceInstanceId: metadata.serviceInstanceId,
      storeName: metadata.storeName,
      logo: metadata.logo,
      uniqueId: metadata.uniqueId,
      contactEmail: metadata.contactEmail,
      phone: metadata.phone,
      contactPerson: metadata.contactPerson,
      status: metadata.status,
      serviceVariantType: metadata.serviceVariantType,
      // Products/orders never seed from bundled fixtures — only remote import
      // or an explicit caller-supplied path. Customers may use the local
      // bootstrap cache when remote import is not configured.
      orderJson: shouldRestoreFromRemote ? null : orderJson,
      productJson: shouldRestoreFromRemote ? null : productJson,
      customerJson: shouldRestoreFromRemote
          ? null
          : (customerJson ?? resolvedConfig.assetPaths.customers),
      offerJson: shouldRestoreFromRemote ? null : offerJson,
      tableJson: tableJson,
      databasePath: dbRoot,
      sessionDuration: sessionDuration,
      config: resolvedConfig,
    );

    await _saveStoreDirectoryEntry(store._db, metadata);
    for (final entry in login.accessibleStores.where(
      (entry) => entry.access.orgId == metadata.orgId,
    )) {
      await _saveStoreRoleAccess(store._db, entry.access);
    }
    await _ensureLoggedInCustomerPersisted(
      store._db,
      login: login,
      storeId: metadata.storeId,
    );
    store.status = metadata.status;
    if (remoteDeviceAccess != null && effectiveDeviceRegistration != null) {
      await _saveDeviceAccess(
        store._db,
        orgId: metadata.orgId,
        request: effectiveDeviceRegistration,
        result: remoteDeviceAccess,
      );
    }
    await store._ensureLocalAccessAllowed();

    if (shouldRestoreFromRemote && remoteConnectivityAvailable) {
      final recoverySession = StoreSession(
        customerId: login.customerId,
        email: login.email,
        loginAt: DateTime.now().toIso8601String(),
        organisationRole: login.organisationRole,
        storeRole: accessibleStore.access.storeRole,
      );
      await _saveSession(store._db, recoverySession);
      await store.sync.restoreFromRemote(store.scope);
      // Remote restore may overwrite customers; keep the signed-in user.
      await _ensureLoggedInCustomerPersisted(
        store._db,
        login: login,
        storeId: metadata.storeId,
      );
    }

    final customer = await store._customerRepo.getCustomerById(
      login.customerId,
    );
    if (customer == null) {
      await store.close();
      throw const StoreAuthException('Customer not found in selected store.');
    }

    final role = await store._customerRepo.getStoreRole(
      orgId: accessibleStore.access.orgId,
      customerId: login.customerId,
      storeId: accessibleStore.access.storeId,
    );
    if (role == null) {
      await store.close();
      throw StoreAuthorizationException(
        'Customer does not have access to storeId=$storeId.',
      );
    }

    final session = StoreSession(
      customerId: login.customerId,
      email: login.email,
      loginAt: DateTime.now().toIso8601String(),
      organisationRole: login.organisationRole,
      storeRole: accessibleStore.access.storeRole,
    );
    await _saveSession(store._db, session);
    return store;
  }

  static Future<void> _ensureLoggedInCustomerPersisted(
    Database db, {
    required StoreOrganisationLoginResult login,
    required String storeId,
  }) async {
    if (login.customerId.isEmpty) {
      return;
    }
    final repo = CustomerRepository(db);
    final row = login.customerRow ?? const <String, dynamic>{};
    final rawPassword = '${row['password'] ?? ''}';
    final normalizedPassword = rawPassword.isEmpty || rawPassword.length == 64
        ? rawPassword
        : CustomerRepository.hashPassword(rawPassword);
    await repo.createCustomer({
      'customerId': login.customerId,
      'remote_id': row['remote_id'] ?? login.customerId,
      'orgId': row['orgId']?.toString() ?? login.organisation.orgId,
      'storeId': row['storeId']?.toString() ?? storeId,
      'name': row['name']?.toString() ?? login.customerName,
      'email': row['email']?.toString() ?? login.email,
      'phone': row['phone']?.toString() ?? '',
      'country': row['country']?.toString() ?? '',
      'status': () {
        final raw = row['status']?.toString().trim() ?? '';
        return raw.isEmpty ? 'active' : raw;
      }(),
      'role': row['role']?.toString() ?? login.organisationRole,
      'password': normalizedPassword,
      'usr_reg_num': '${row['usr_reg_num'] ?? row['reg_num'] ?? ''}',
    });
    for (final accessible in login.accessibleStores) {
      await _saveStoreRoleAccess(db, accessible.access);
    }
  }

  void _invalidateSessionCache() {
    _sessionCache = null;
    _sessionCacheAt = null;
    _localAccessCheckedAt = null;
  }

  Future<void> _ensureLocalAccessAllowed({
    bool clearSessionOnFailure = false,
  }) async {
    final now = DateTime.now();
    if (_localAccessCheckedAt != null &&
        now.difference(_localAccessCheckedAt!) < _sessionCacheTtl) {
      return;
    }
    final persistedStoreInfo = await _loadStoreInfoByStoreId(
      _db,
      orgId: orgId,
      storeId: storeId,
    );
    final persistedStatus = persistedStoreInfo?['status'] as String? ?? status;
    if (!_isActiveStatus(persistedStatus)) {
      _invalidateSessionCache();
      if (clearSessionOnFailure) {
        await _clearSession(_db);
      }
      throw StoreAuthorizationException('Store $storeId is not active.');
    }
    if (_config.bootstrap.requiresDeviceRegistration) {
      final cachedDeviceAccess = await _loadDeviceAccess(_db, orgId);
      if (cachedDeviceAccess != null &&
          !_isActiveStatus(cachedDeviceAccess['status'] as String?)) {
        _invalidateSessionCache();
        if (clearSessionOnFailure) {
          await _clearSession(_db);
        }
        throw StoreDeviceAccessException(
          cachedDeviceAccess['message'] as String? ??
              'This device is not active for organisation $orgId.',
        );
      }
    }
    _localAccessCheckedAt = now;
  }

  Future<void> _refreshCurrentStoreAccessFromRemote({
    StoreDeviceRegistrationRequest? deviceRegistration,
  }) async {
    if (_config.bootstrap.isConfigured) {
      final bootstrap = await _fetchBootstrapPayload(
        config: _config,
        orgId: orgId,
      );
      if (bootstrap != null) {
        final organisationRow = _requireBootstrapOrganisation(bootstrap);
        if (organisationRow != null) {
          await _db.insert(_organisationTable, {
            'orgId':
                organisationRow['orgId'] as String? ??
                organisationRow['org_id'] as String? ??
                orgId,
            'remote_id': organisationRow['remote_id'] as String?,
            'org_name':
                organisationRow['org_name'] as String? ??
                organisationRow['orgName'] as String? ??
                orgName,
            'org_code':
                organisationRow['org_code'] as String? ??
                organisationRow['orgCode'] as String? ??
                orgCode,
            'logo': organisationRow['logo'] as String? ?? logo,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in _extractBootstrapStores(bootstrap)) {
          final entry = StoreDirectoryEntry.fromRow(row);
          await _saveStoreDirectoryEntry(_db, entry);
          if (entry.storeId == storeId) {
            status = entry.status;
          }
        }
      }
    }

    if (_config.bootstrap.requiresDeviceRegistration) {
      final effectiveDeviceRegistration =
          deviceRegistration ??
          _deviceRequestFromAccessRow(await _loadDeviceAccess(_db, orgId));
      if (effectiveDeviceRegistration != null) {
        final registration = await _submitDeviceRegistration(
          orgId: orgId,
          request: effectiveDeviceRegistration,
          config: _config,
        );
        await _saveDeviceAccess(
          _db,
          orgId: orgId,
          request: effectiveDeviceRegistration,
          result: registration,
        );
        if (!registration.isActive) {
          await _clearSession(_db);
          throw StoreDeviceAccessException(
            registration.message ??
                'This device is not active for organisation $orgId.',
          );
        }
      }
    }

    await _ensureLocalAccessAllowed(clearSessionOnFailure: true);
  }

  Future<StoreSession?> _getCurrentSession() async {
    final now = DateTime.now();
    final cached = _sessionCache;
    final cachedAt = _sessionCacheAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _sessionCacheTtl) {
      final loginAt = DateTime.tryParse(cached.loginAt);
      if (loginAt != null && now.difference(loginAt) <= _sessionDuration) {
        await _ensureLocalAccessAllowed(clearSessionOnFailure: true);
        return cached;
      }
    }

    final row = await _loadSession(_db);
    if (row == null) {
      _invalidateSessionCache();
      return null;
    }
    final loginAtRaw = row['loginAt'] as String?;
    final loginAt = loginAtRaw == null ? null : DateTime.tryParse(loginAtRaw);
    if (loginAt == null || now.difference(loginAt) > _sessionDuration) {
      _invalidateSessionCache();
      await _clearSession(_db);
      throw const StoreSessionExpiredException(
        'The login session has expired. Please login again.',
      );
    }
    final customer = await _customerRepo.getCustomerById(
      row['customerId'] as String? ?? '',
    );
    if (customer == null ||
        !_isActiveCustomerStatus(customer['status'] as String?)) {
      _invalidateSessionCache();
      await _clearSession(_db);
      return null;
    }
    await _ensureLocalAccessAllowed(clearSessionOnFailure: true);
    final session = StoreSession.fromRow(row);
    _sessionCache = session;
    _sessionCacheAt = now;
    return session;
  }

  Future<bool> _isLoggedIn() async {
    try {
      return await _getCurrentSession() != null;
    } on StoreSessionExpiredException {
      return false;
    } on StoreAuthorizationException {
      return false;
    } on StoreDeviceAccessException {
      return false;
    }
  }

  Future<StoreCustomer?> _getCurrentCustomer() async {
    final session = await _getCurrentSession();
    if (session == null) {
      return null;
    }
    final row = await _customerRepo.getCustomerById(session.customerId);
    return row == null ? null : StoreCustomer.fromRow(row);
  }

  void _validateScope(StoreScope scope) {
    if (scope.orgId != orgId || scope.storeId != storeId) {
      throw StoreAuthorizationException(
        'Scope mismatch. Expected orgId=$orgId and storeId=$storeId.',
      );
    }
  }

  Future<void> _requireScopedAccess(StoreScope scope) async {
    _validateScope(scope);
    await _requireValidSession();
  }

  Future<StoreSession?> _login(
    StoreScope scope,
    StoreLoginRequest request,
  ) async {
    _validateScope(scope);
    // Prefer store-scoped row, then org-wide (operators are often stored with
    // another storeId / first-accessible store, not the open branch).
    var customer = await _customerRepo.authenticateCustomer(
      scope: scope,
      email: request.email,
      password: request.password,
    );
    customer ??= await _customerRepo.authenticateCustomerForOrganisation(
      orgId: scope.orgId,
      email: request.email,
      password: request.password,
    );
    if (customer == null) {
      return null;
    }
    return _openSessionFor(scope, customer, fallbackEmail: request.email);
  }

  /// Session for an operator the app already verified (e.g. lock-screen PIN).
  Future<StoreSession?> _loginVerifiedCustomer(
    StoreScope scope,
    String customerId,
  ) async {
    _validateScope(scope);
    final customer = await _customerRepo.getCustomerById(customerId);
    if (customer == null) return null;
    final status = '${customer['status'] ?? ''}'.trim().toLowerCase();
    if (!const {'', 'active', 'approved', '1'}.contains(status)) return null;
    if ('${customer['orgId'] ?? ''}'.trim() != scope.orgId) return null;
    return _openSessionFor(
      scope,
      customer,
      fallbackEmail: '${customer['email'] ?? ''}',
    );
  }

  Future<StoreSession?> _openSessionFor(
    StoreScope scope,
    Map<String, dynamic> customer, {
    required String fallbackEmail,
  }) async {
    final customerId = customer['customerId'] as String? ?? '';
    final storeRole = await _customerRepo.getStoreRole(
      orgId: scope.orgId,
      customerId: customerId,
      storeId: scope.storeId,
    );
    final customerStoreId = '${customer['storeId'] ?? ''}'.trim();
    final roleFromCustomer = '${customer['role'] ?? ''}'.trim().toLowerCase();
    final isDirectoryCustomer =
        roleFromCustomer == 'retail_customer' ||
        roleFromCustomer == 'business_customer';
    // Prefer store_roles; allow same-branch customer row for operators when
    // roles were not imported yet (otherwise unlock traps the tablet).
    if (storeRole == null) {
      if (isDirectoryCustomer ||
          (customerStoreId.isNotEmpty && customerStoreId != scope.storeId)) {
        return null;
      }
    }
    final session = StoreSession(
      customerId: customerId,
      email: customer['email'] as String? ?? fallbackEmail,
      loginAt: DateTime.now().toIso8601String(),
      organisationRole: customer['role'] as String? ?? '',
      storeRole:
          storeRole?['role'] as String? ??
          (roleFromCustomer.isNotEmpty ? roleFromCustomer : 'member'),
    );
    await _saveSession(_db, session);
    _sessionCache = session;
    _sessionCacheAt = DateTime.now();
    return session;
  }

  Future<void> _logout() async {
    _invalidateSessionCache();
    await _clearSession(_db);
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final customer = await _getCurrentCustomer();
    if (customer == null) {
      throw const StoreAuthException('No valid login session.');
    }
    final authenticated = await _customerRepo.authenticateCustomer(
      scope: StoreScope(orgId: customer.orgId, storeId: customer.storeId),
      email: customer.email,
      password: currentPassword,
    );
    if (authenticated == null) {
      throw const StoreAuthException('Current password is incorrect.');
    }
    await _customerRepo.updateCustomerPasswordById(
      customerId: customer.customerId,
      newPassword: newPassword,
    );
    final refreshedCustomer = await _customerRepo.getCustomerById(
      customer.customerId,
    );
    final refreshedSession = StoreSession(
      customerId: customer.customerId,
      email: refreshedCustomer?['email'] as String? ?? customer.email,
      loginAt: DateTime.now().toIso8601String(),
      organisationRole: refreshedCustomer?['role'] as String? ?? customer.role,
      storeRole: (await _getCurrentSession())?.storeRole ?? '',
    );
    await _saveSession(_db, refreshedSession);
    _sessionCache = refreshedSession;
    _sessionCacheAt = DateTime.now();
  }

  Future<void> _resetCustomerPassword({
    required String customerId,
    required String newPassword,
  }) async {
    await _requireRole('admin');
    final updated = await _customerRepo.updateCustomerPasswordById(
      customerId: customerId,
      newPassword: newPassword,
    );
    if (updated == 0) {
      throw const StoreAuthException('Customer not found for password reset.');
    }
  }

  Future<void> _resetCustomerPasswordByEmail({
    required String email,
    required String newPassword,
  }) async {
    await _requireRole('admin');
    final updated = await _customerRepo.updateCustomerPasswordByEmail(
      email: email,
      newPassword: newPassword,
    );
    if (updated == 0) {
      throw const StoreAuthException('Customer not found for password reset.');
    }
  }

  /// Persist a verified password hash for offline unlock until the next sync
  /// that carries a newer credential.
  Future<void> _persistVerifiedOfflinePassword({
    required String password,
    String? customerId,
    String? identifier,
  }) async {
    final hash = CustomerRepository.hashPassword(password);
    final ids = <String>{};
    final cid = (customerId ?? '').trim();
    if (cid.isNotEmpty) ids.add(cid);

    final key = (identifier ?? '').trim();
    if (key.isNotEmpty) {
      final rows = await _db.query(
        'customers',
        columns: ['customerId', 'email', 'phone', 'usr_reg_num'],
        where: 'orgId = ?',
        whereArgs: [orgId],
      );
      final keyLower = key.toLowerCase();
      final digits = key.replaceAll(RegExp(r'[^0-9]'), '');
      for (final row in rows) {
        final email = '${row['email'] ?? ''}'.trim().toLowerCase();
        final phone = '${row['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
        final reg = '${row['usr_reg_num'] ?? ''}'.trim().toLowerCase();
        final match =
            (email.isNotEmpty && email == keyLower) ||
            (reg.isNotEmpty && (reg == keyLower || reg == digits)) ||
            (digits.length >= 7 &&
                phone.length >= 7 &&
                (phone == digits ||
                    phone.endsWith(digits) ||
                    digits.endsWith(phone)));
        if (match) {
          final id = '${row['customerId'] ?? ''}'.trim();
          if (id.isNotEmpty) ids.add(id);
        }
      }
    }

    for (final id in ids) {
      await _db.update(
        'customers',
        {'password': hash},
        where: 'customerId = ? AND orgId = ?',
        whereArgs: [id, orgId],
      );
    }
  }

  Future<void> _requireValidSession() async {
    try {
      if (await _getCurrentSession() == null) {
        throw const StoreAuthException(
          'No valid login session. Call login() before using Store operations.',
        );
      }
    } on StoreSessionExpiredException {
      rethrow;
    }
  }

  static bool _roleSatisfies(String actualRole, String requiredRole) {
    final actual = _rolePriority[actualRole] ?? -1;
    final required = _rolePriority[requiredRole] ?? 999;
    return actual >= required;
  }

  Future<String?> _getCurrentOrganisationRole() async {
    final session = await _getCurrentSession();
    return session?.organisationRole;
  }

  Future<String?> _getCurrentStoreRoleValue() async {
    final session = await _getCurrentSession();
    return session?.storeRole;
  }

  Future<bool> _hasOrganisationRole(String role) async {
    final session = await _getCurrentSession();
    if (session == null) {
      return false;
    }
    return _roleSatisfies(session.organisationRole, role);
  }

  Future<bool> _hasStoreRole(String role) async {
    final session = await _getCurrentSession();
    if (session == null) {
      return false;
    }
    return _roleSatisfies(session.storeRole, role);
  }

  Future<StoreRoleAccess?> _getCurrentStoreAccess(StoreScope scope) async {
    await _requireScopedAccess(scope);
    final session = await _getCurrentSession();
    if (session == null) {
      return null;
    }
    final row = await _customerRepo.getStoreRole(
      orgId: scope.orgId,
      customerId: session.customerId,
      storeId: scope.storeId,
    );
    return row == null ? null : StoreRoleAccess.fromRow(row);
  }

  Future<bool> _canCurrentCustomerAccessStore(StoreScope scope) async {
    return await _getCurrentStoreAccess(scope) != null;
  }

  Future<void> _requireRole(String role) async {
    final session = await _getCurrentSession();
    if (session == null) {
      throw const StoreAuthException(
        'No valid login session. Call login() before using Store operations.',
      );
    }
    final actualRole = session.storeRole;
    if (!_roleSatisfies(actualRole, role)) {
      throw StoreAuthorizationException(
        'Operation requires role $role or higher.',
      );
    }
  }

  // Orders
  Future<List<Map<String, dynamic>>> _listOrders(
    StoreScope scope, {
    String? pricingMode,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.listOrders(scope, pricingMode: pricingMode);
  }

  Future<List<StoreOrderSummary>> _listOrderSummaries(
    StoreScope scope, {
    String? pricingMode,
  }) async {
    final rows = await _listOrders(scope, pricingMode: pricingMode);
    return rows.map(StoreOrderSummary.fromRow).toList();
  }

  Future<int> _getServeNumberMaximum(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.getServeNumberMaximum(scope);
  }

  Future<void> _setServeNumberMaximum(StoreScope scope, int maximum) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _ordersRepo.setServeNumberMaximum(scope, maximum);
  }

  Future<void> _importOrdersFromJsonFile(
    StoreScope scope,
    String filePath,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _ordersRepo.importOrdersFromJsonFile(filePath, scope: scope);
  }

  Future<StoreOrderImportOutcome> _importOrdersFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool markAsExported = true,
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    return _ordersRepo.importOrdersFromJsonData(
      data,
      scope: scope,
      markAsExported: markAsExported,
    );
  }

  Future<int> _addOrder(StoreScope scope, Map<String, dynamic> order) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.addOrder(scope, order);
  }

  Future<int> _nextOrderId(StoreScope scope) async {
    const maxAttempts = 32;
    final base =
        _localOrderIdPrefix * math.pow(10, _localOrderIdRandomDigits).toInt();
    final limit = math.pow(10, _localOrderIdRandomDigits).toInt();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = base + math.Random.secure().nextInt(limit);
      final existingOrder = await _ordersRepo.getOrderById(scope, candidate);
      if (existingOrder == null) {
        return candidate;
      }
    }

    throw StateError(
      'Unable to generate a unique 10-digit orderId with 55 prefix.',
    );
  }

  String _newCustomerId() => 'cust-local-${_uuid.v4()}';

  bool _isValidLocalOrderId(int orderId) {
    final value = '$orderId';
    return value.length == (_localOrderIdRandomDigits + 2) &&
        value.startsWith('$_localOrderIdPrefix');
  }

  Future<int> _createOrder(StoreScope scope, StoreCreateOrderRequest request) {
    return _createOrderWithPayments(scope, request);
  }

  Future<int> _createOrderWithPayments(
    StoreScope scope,
    StoreCreateOrderRequest request,
  ) async {
    if (request.orderId != null && !_isValidLocalOrderId(request.orderId!)) {
      throw ArgumentError.value(
        request.orderId,
        'orderId',
        'Local orderId must be a random 10-digit number starting with 55.',
      );
    }
    final resolvedOrderId = request.orderId ?? await _nextOrderId(scope);
    var serveNumber = request.serveNumber;
    if (serveNumber == null &&
        !StoreOrderStatus.isSyncExcluded(request.statusName)) {
      serveNumber = await _ordersRepo.allocateServeNumber(scope);
    }
    final row = request.toRow(scope, resolvedOrderId: resolvedOrderId);
    if (serveNumber != null) {
      row['serve_number'] = serveNumber;
    }
    await _addOrder(scope, row);
    for (final payment in request.payments) {
      await _ordersRepo.addOrderPayment(
        scope,
        payment.toRow(scope, resolvedOrderId),
      );
    }
    return resolvedOrderId;
  }

  Future<Map<String, dynamic>?> _getOrderById(
    StoreScope scope,
    int orderId,
  ) async {
    await _requireScopedAccess(scope);
    return _ordersRepo.getOrderById(scope, orderId);
  }

  Future<StoreOrderDetails?> _getOrderDetails(
    StoreScope scope,
    int orderId,
  ) async {
    final row = await _getOrderById(scope, orderId);
    if (row == null) {
      return null;
    }
    final payments = await _getOrderPaymentRecords(scope, orderId);
    final accounting = (await _ordersRepo.listOrders(
      scope,
      orderId: orderId,
    )).single;
    final pricingSnapshot = await _buildOrderPricingSnapshot(scope, orderId);
    final itemDetails =
        (pricingSnapshot['items'] as List<StoreOrderItemDetails>? ?? const []);
    return StoreOrderDetails(
      creditRepaidAmount:
          (accounting['credit_repaid_amount'] as num?)?.toDouble() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      id: (row['id'] as num?)?.toInt() ?? 0,
      uniqueId: row['unique_id'] as String?,
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      restaurantName: row['restaurant_name'] as String? ?? '',
      customerName: row['name'] as String? ?? '',
      mobile: row['mobile'] as String? ?? '',
      customerUniqueId: row['customer_unique_id'] as String?,
      statusName: row['status_name'] as String? ?? '',
      totalValue:
          (row['total_value'] as num?)?.toDouble() ??
          (pricingSnapshot['subtotal'] as num?)?.toDouble() ??
          0,
      offerAppliedValue:
          (row['offer_applied_value'] as num?)?.toDouble() ??
          (pricingSnapshot['totalDiscount'] as num?)?.toDouble() ??
          0,
      finalValue:
          (row['final_value'] as num?)?.toDouble() ??
          (pricingSnapshot['total'] as num?)?.toDouble() ??
          0,
      total:
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      serviceInstance: (row['service_instance'] as num?)?.toInt() ?? 0,
      createdBy: row['created_by'] as String? ?? '',
      createdOn: row['created_on'] as String? ?? '',
      paymentStatus: StoreOrderSummary.fromRow(accounting).paymentStatus,
      orderType: StoreOrderType.normalize(row['order_type'] as String? ?? ''),
      pricingMode: StoreOrderPricingMode.normalize(row['pricing_mode']),
      subtotal: (pricingSnapshot['subtotal'] as num?)?.toDouble() ?? 0,
      totalDiscount:
          (pricingSnapshot['totalDiscount'] as num?)?.toDouble() ?? 0,
      tables: _extractOrderTables(itemDetails),
      items: itemDetails,
      appliedOffers:
          (pricingSnapshot['appliedOffers'] as List<StoreAppliedOfferRecord>? ??
          const []),
      payments: payments,
      exported: ((row['exported'] as num?)?.toInt() ?? 0) == 1,
      lastImportedAt: row['last_imported_at'] as String?,
      lastExportedAt: row['last_exported_at'] as String?,
      serveNumber: (row['serve_number'] as num?)?.toInt(),
    );
  }

  Future<int> _updateOrderStatus(
    StoreScope scope,
    int orderId,
    String status,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.updateOrderStatus(scope, orderId, status);
  }

  Future<int> _updateOrderPaymentStatus(
    StoreScope scope,
    int orderId,
    String paymentStatus,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.updatePaymentStatus(scope, orderId, paymentStatus);
  }

  Future<bool> _alignOrderPricingMode(
    StoreScope scope,
    int orderId,
    String pricingMode,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.alignOrderPricingMode(scope, orderId, pricingMode);
  }

  Future<int> _closeOrder(
    StoreScope scope,
    int orderId, {
    String status = 'Closed',
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final order = await _ordersRepo.getOrderById(scope, orderId);
    if (order == null) {
      throw StoreOrderStateException('Order $orderId was not found.');
    }
    final orderTotal =
        (order['final_value'] as num?)?.toDouble() ??
        (order['total'] as num?)?.toDouble() ??
        0;
    final pricingMode = StoreOrderPricingMode.normalize(order['pricing_mode']);
    final paidTotal = await _ordersRepo.getOrderPaymentsTotal(scope, orderId);
    // Buy-mode orders represent procurement and may close without customer payment.
    if (pricingMode != StoreOrderPricingMode.buying &&
        paidTotal + 0.0001 < orderTotal) {
      throw StoreOrderStateException(
        'Cannot close order $orderId. Paid amount $paidTotal is less than final price $orderTotal.',
      );
    }
    return _ordersRepo.updateOrderStatus(scope, orderId, status);
  }

  Future<List<Map<String, dynamic>>> _getOrderItems(
    StoreScope scope,
    int orderId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.getOrderItems(scope, orderId);
  }

  Future<List<StoreOrderItemRecord>> _getOrderItemRecords(
    StoreScope scope,
    int orderId,
  ) async {
    final rows = await _getOrderItems(scope, orderId);
    return rows.map(StoreOrderItemRecord.fromRow).toList();
  }

  Future<List<Map<String, dynamic>>> _getOrderItemAddons(
    StoreScope scope,
    int itemId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.getOrderItemAddons(scope, itemId);
  }

  Future<List<StoreOrderItemAddonRecord>> _getOrderItemAddonRecords(
    StoreScope scope,
    int itemId,
  ) async {
    final rows = await _getOrderItemAddons(scope, itemId);
    return rows.map(StoreOrderItemAddonRecord.fromRow).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _getOrderPayments(
    StoreScope scope,
    int orderId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.getOrderPayments(scope, orderId);
  }

  Future<List<StoreOrderPaymentRecord>> _getOrderPaymentRecords(
    StoreScope scope,
    int orderId,
  ) async {
    final rows = await _getOrderPayments(scope, orderId);
    final records = <StoreOrderPaymentRecord>[];
    for (final row in rows) {
      final paymentId = (row['id'] as num?)?.toInt() ?? 0;
      final refunded = paymentId == 0
          ? 0.0
          : await _ordersRepo.getPaymentRefundedTotal(scope, paymentId);
      records.add(
        StoreOrderPaymentRecord.fromRow({...row, 'refunded_amount': refunded}),
      );
    }
    return records;
  }

  Future<List<StoreOrderRefundRecord>> _getOrderRefundRecords(
    StoreScope scope, {
    int? orderId,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = orderId == null
        ? await _ordersRepo.listAllOrderRefunds(scope)
        : await _ordersRepo.getOrderRefunds(scope, orderId);
    return rows.map(StoreOrderRefundRecord.fromRow).toList(growable: false);
  }

  Future<int> _addOrderRefund(
    StoreScope scope,
    int orderId,
    StoreCreateOrderRefundRequest request,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final amount = double.parse(request.amount.toStringAsFixed(2));
    if (amount <= 0) {
      throw ArgumentError.value(
        request.amount,
        'amount',
        'Refund must be > 0.',
      );
    }
    final payments = await _ordersRepo.getOrderPayments(scope, orderId);
    Map<String, dynamic>? payment;
    for (final row in payments) {
      if ((row['id'] as num?)?.toInt() == request.paymentId) {
        payment = row;
        break;
      }
    }
    if (payment == null) {
      throw StoreOrderStateException(
        'Payment ${request.paymentId} was not found on order $orderId.',
      );
    }
    final paid = (payment['amount'] as num?)?.toDouble() ?? 0;
    final already = await _ordersRepo.getPaymentRefundedTotal(
      scope,
      request.paymentId,
    );
    final remaining = double.parse((paid - already).toStringAsFixed(2));
    if (amount > remaining + 0.0001) {
      throw StoreOrderStateException(
        'Refund $amount exceeds refundable balance $remaining.',
      );
    }
    final now = request.createdOn ?? DateTime.now().toIso8601String();
    final localId = (request.localId ?? '').trim().isNotEmpty
        ? request.localId!.trim()
        : _newLocalSyncId('order-refund');
    final refundId = await _ordersRepo.addOrderRefund(scope, {
      'local_id': localId,
      'order_id': orderId,
      'payment_id': request.paymentId,
      'payment_local_id': payment['local_id'],
      'payment_reference_id': payment['reference_id'],
      'amount': amount,
      'reason': request.reason,
      'status': 'success',
      'created_on': now,
      'exported': 0,
    });
    final order = await _ordersRepo.getOrderById(scope, orderId);
    final localOrderId = order?['local_id'] as String?;
    if (localOrderId != null && localOrderId.isNotEmpty) {
      await _ordersRepo.markOrdersExported(scope, [
        localOrderId,
      ], exported: false);
    }
    return refundId;
  }

  Future<void> _deleteDraftOrder(StoreScope scope, int orderId) async {
    _validateScope(scope);
    await _requireRole('member');
    await _ordersRepo.deleteDraftOrder(scope, orderId);
  }

  /// Discards an unpaid, unclosed order and frees its table.
  ///
  /// Orders that never reached the kitchen or the server are hard-deleted
  /// (returns true). Otherwise the order is kept as Cancelled for audit/sync,
  /// with kitchen cancellations logged for any sent quantity (returns false).
  Future<bool> _discardOrder(StoreScope scope, int orderId) async {
    _validateScope(scope);
    await _requireRole('member');
    final order = await _ordersRepo.getOrderById(scope, orderId);
    if (order == null) {
      throw StoreOrderStateException('Order $orderId was not found.');
    }
    final status = '${order['status_name'] ?? ''}'.trim();
    if (StoreOrderStatus.isCompleted(status)) {
      throw StoreOrderStateException(
        'Order $orderId is $status and cannot be deleted.',
      );
    }
    if (await _ordersRepo.countOrderPayments(scope, orderId) > 0) {
      throw StoreOrderStateException(
        'Order $orderId has payments. Refund it from Payments, then cancel.',
      );
    }

    final reachedServer =
        !StoreOrderStatus.isSyncExcluded(status) &&
        (((order['exported'] as num?)?.toInt() ?? 0) == 1 ||
            order['last_exported_at'] != null ||
            order['last_imported_at'] != null ||
            order['remote_id'] != null);
    final items = await _ordersRepo.getOrderItems(scope, orderId);
    final sentToKitchen =
        items.any(
          (item) => ((item['kitchen_sent_quantity'] as num?) ?? 0) > 0,
        ) ||
        (await _ordersRepo.getKitchenCancellations(scope, orderId)).isNotEmpty;

    if (!reachedServer && !sentToKitchen) {
      await _ordersRepo.purgeOrder(scope, orderId);
      return true;
    }

    for (final item in items) {
      await _trackKitchenCancellationIfNeeded(
        scope,
        item,
        nextQuantity: 0,
        note: 'Order deleted before billing',
      );
    }
    if (!StoreOrderStatus.isCancelled(status)) {
      await _ordersRepo.updateOrderStatus(
        scope,
        orderId,
        StoreOrderStatus.cancelled,
      );
    }
    return false;
  }

  Future<List<StoreKitchenCancellationRecord>> _getKitchenCancellationRecords(
    StoreScope scope,
    int orderId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = await _ordersRepo.getKitchenCancellations(scope, orderId);
    return rows
        .map(StoreKitchenCancellationRecord.fromRow)
        .toList(growable: false);
  }

  Future<String?> _getCurrentSessionActor() async {
    final session = await _getCurrentSession();
    if (session == null) {
      return null;
    }
    final email = session.email.trim();
    if (email.isNotEmpty) {
      return email;
    }
    final customerId = session.customerId.trim();
    if (customerId.isNotEmpty) {
      return customerId;
    }
    return null;
  }

  Future<void> _trackKitchenCancellationIfNeeded(
    StoreScope scope,
    Map<String, dynamic> item, {
    required int nextQuantity,
    String? note,
  }) async {
    final sentQuantity = (item['kitchen_sent_quantity'] as num?)?.toInt() ?? 0;
    if (sentQuantity <= nextQuantity) {
      return;
    }
    final cancelQuantity = sentQuantity - nextQuantity;
    final cancelledBy = await _getCurrentSessionActor();
    await _ordersRepo.addKitchenCancellation(scope, {
      'order_id': (item['order_id'] as num?)?.toInt() ?? 0,
      'order_item_id': (item['id'] as num?)?.toInt() ?? 0,
      'product_variant_id': item['product_variant_id'] as String? ?? '',
      'product_id': item['product_id'] as String? ?? '',
      'cancelled_qty': cancelQuantity,
      'cancelled_by': cancelledBy,
      'source_kitchen_batch': (item['kitchen_sent_batch'] as num?)?.toInt(),
      'created_on': DateTime.now().toIso8601String(),
      'note': note,
    });
    await _ordersRepo.updateKitchenSentQuantity(
      scope,
      (item['id'] as num?)?.toInt() ?? 0,
      kitchenSentQuantity: nextQuantity,
    );
  }

  Future<int> _addOrderPayment(
    StoreScope scope,
    StoreCreateOrderPaymentRequest request,
    int orderId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.addOrderPayment(scope, request.toRow(scope, orderId));
  }

  Future<int> _addOrderItem(StoreScope scope, Map<String, dynamic> item) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.addOrderItem(scope, item);
  }

  double _roundCurrency(double value) => double.parse(value.toStringAsFixed(2));

  List<String> _buildUniqueTargetIds(Iterable<dynamic> rawValues) {
    final values = <String>[];
    for (final rawValue in rawValues) {
      if (rawValue == null) {
        continue;
      }
      final value = '$rawValue'.trim();
      if (value.isEmpty || values.contains(value)) {
        continue;
      }
      values.add(value);
    }
    return values;
  }

  int? _parseCategoryId(dynamic categoryLocalId) {
    final raw = categoryLocalId as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw.replaceFirst('cat_', ''));
  }

  Future<Map<String, dynamic>> _buildOrderPricingSnapshot(
    StoreScope scope,
    int orderId,
  ) async {
    final itemRecords = await _getOrderItemRecords(scope, orderId);
    final itemDetails = <StoreOrderItemDetails>[];
    final evaluationItems = <StoreOfferEvaluationItem>[];
    final addonsByItemId = <int, List<StoreOrderItemAddonRecord>>{};

    final orderRow = await _ordersRepo.getOrderById(scope, orderId);
    final orderPricingMode = StoreOrderPricingMode.normalize(
      orderRow?['pricing_mode'],
    );
    final skipOffers = orderPricingMode == StoreOrderPricingMode.buying;

    // Buying never evaluates offers. Return its totals directly instead of
    // loading every product/category and running the sell offer engine. This
    // removes most of the checkout-time SQLite round trips for buy orders.
    if (skipOffers) {
      final addonLists = await Future.wait(
        itemRecords.map((item) => _getOrderItemAddonRecords(scope, item.id)),
      );
      for (var index = 0; index < itemRecords.length; index++) {
        final item = itemRecords[index];
        itemDetails.add(
          StoreOrderItemDetails(
            item: item,
            addons: addonLists[index],
            discountAmount: 0,
            totalAfterDiscount: _roundCurrency(item.finalPrice),
            appliedOfferLocalIds: const [],
          ),
        );
      }
      final itemsGross = itemRecords.fold<double>(
        0,
        (sum, item) => sum + item.finalPrice,
      );
      return {
        'subtotal': _roundCurrency(itemsGross),
        'totalDiscount': 0.0,
        'total': _roundCurrency(itemsGross),
        'items': itemDetails,
        'appliedOffers': const <StoreAppliedOfferRecord>[],
      };
    }

    final offersFuture = _offersRepo.listOffers(scope, activeOnly: true);
    final itemContexts = await Future.wait(
      itemRecords.map((item) async {
        final addons = await _getOrderItemAddonRecords(scope, item.id);
        if (skipOffers) {
          return (
            item: item,
            addons: addons,
            variant: null as Map<String, dynamic>?,
            product: null as Map<String, dynamic>?,
            categoryLocalId: null as String?,
            categoryId: null as int?,
            category: null as Map<String, dynamic>?,
          );
        }
        final variant = await _productRepo.getProductVariantById(
          scope,
          item.productVariantId,
        );
        final product = await _productRepo.getProductByVariantId(
          scope,
          item.productVariantId,
        );
        final categoryLocalId = variant?['categoryLocalId'] as String?;
        final categoryId = _parseCategoryId(categoryLocalId);
        final category = categoryLocalId == null || categoryLocalId.isEmpty
            ? null
            : await _productRepo.getCategoryById(scope, categoryLocalId);
        return (
          item: item,
          addons: addons,
          variant: variant,
          product: product,
          categoryLocalId: categoryLocalId,
          categoryId: categoryId,
          category: category,
        );
      }),
    );

    for (final ctx in itemContexts) {
      addonsByItemId[ctx.item.id] = ctx.addons;
      if (skipOffers) continue;
      final enteredQuantity = ctx.item.quantity.toDouble();
      final baseQty = (ctx.variant?['sell_unit_base_qty'] as num?)?.toDouble();
      var billableQuantity = enteredQuantity <= 0 ? 1.0 : enteredQuantity;
      if (baseQty != null && baseQty > 0 && enteredQuantity > 0) {
        // Package pricing: £110 / 6kg → 1 billable package, not 6 kg units.
        billableQuantity = (enteredQuantity / baseQty).ceilToDouble();
      }
      final billableInt = billableQuantity.round().clamp(1, 999999);
      // Offers apply to the product variant package price only — never add-ons.
      final packagePrice = ctx.item.sellPrice > 0
          ? ctx.item.sellPrice
          : ctx.item.baseUnitPrice;
      evaluationItems.add(
        StoreOfferEvaluationItem(
          orderItemId: ctx.item.id,
          productTargetIds: _buildUniqueTargetIds([
            ctx.product?['unique_id'],
            ctx.item.productId,
            ctx.product?['localId'],
            ctx.product?['productId'],
            ctx.item.productVariantId,
            ctx.variant?['unique_id'],
            ctx.variant?['localId'],
            ctx.variant?['variantId'],
          ]),
          categoryTargetIds: _buildUniqueTargetIds([
            ctx.category?['unique_id'],
            ctx.categoryId,
            ctx.categoryLocalId,
          ]),
          quantity: billableInt,
          unitPrice: packagePrice,
        ),
      );
    }

    final pricing = StoreOfferEngine.calculate(
      offers: await offersFuture,
      items: evaluationItems,
    );

    // Gross line totals already include add-ons; subtract product offers only.
    final itemsGross = itemRecords.fold<double>(
      0,
      (sum, item) => sum + item.finalPrice,
    );
    final offerDiscount = pricing.totalDiscount;

    for (final item in itemRecords) {
      final discountAmount = _roundCurrency(
        pricing.itemDiscounts[item.id] ?? 0,
      );
      itemDetails.add(
        StoreOrderItemDetails(
          item: item,
          addons: addonsByItemId[item.id] ?? const [],
          discountAmount: discountAmount,
          totalAfterDiscount: _roundCurrency(item.finalPrice - discountAmount),
          appliedOfferLocalIds:
              pricing.itemAppliedOfferIds[item.id] ?? const [],
        ),
      );
    }

    return {
      'subtotal': _roundCurrency(itemsGross),
      'totalDiscount': _roundCurrency(offerDiscount),
      'total': _roundCurrency(
        (itemsGross - offerDiscount).clamp(0, double.infinity),
      ),
      'items': itemDetails,
      'appliedOffers': pricing.appliedOffers,
    };
  }

  Future<void> _refreshAllOrderTotals(StoreScope scope) async {
    final orders = await _ordersRepo.listOrders(scope);
    for (final row in orders) {
      final orderId = (row['order_id'] as num?)?.toInt() ?? 0;
      if (orderId != 0) {
        await _refreshOrderTotal(scope, orderId);
      }
    }
  }

  Future<String> _saveOffer(
    StoreScope scope,
    StoreSaveOfferRequest request,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    final localId = await _offersRepo.saveOffer(scope, request);
    await _refreshAllOrderTotals(scope);
    return localId;
  }

  Future<List<StoreOfferRecord>> _listOffers(
    StoreScope scope, {
    bool activeOnly = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _offersRepo.listOffers(scope, activeOnly: activeOnly);
  }

  Future<StoreOfferRecord?> _getOfferByLocalId(
    StoreScope scope,
    String localId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _offersRepo.getOfferByLocalId(scope, localId);
  }

  Future<int> _deleteOffer(StoreScope scope, String localId) async {
    _validateScope(scope);
    await _requireRole('admin');
    final deleted = await _offersRepo.deleteOffer(scope, localId);
    if (deleted > 0) {
      await _refreshAllOrderTotals(scope);
    }
    return deleted;
  }

  Future<int> _setOfferActive(
    StoreScope scope,
    String localId, {
    required bool active,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    final updated = await _offersRepo.setOfferActive(
      scope,
      localId,
      active: active,
    );
    if (updated > 0) {
      await _refreshAllOrderTotals(scope);
    }
    return updated;
  }

  double? _parsePrice(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  double _resolvePriceForMode({
    required String pricingMode,
    required double? sellPrice,
    required double? buyPrice,
    required double? fallbackPrice,
  }) {
    if (pricingMode == StoreOrderPricingMode.buying) {
      // Existing catalogues commonly have buy_price=0 rather than NULL.
      // Treat that as unconfigured so checkout agrees with the tablet cart,
      // which displays the fallback transaction price for those variants.
      if (buyPrice != null && buyPrice > 0) return buyPrice;
      if (fallbackPrice != null && fallbackPrice > 0) return fallbackPrice;
      return sellPrice ?? 0;
    }
    return sellPrice ?? buyPrice ?? fallbackPrice ?? 0;
  }

  bool _addonMatchesGroupRecord(
    StoreAddOrderItemAddonRequest addon,
    StoreProductAddonGroupRecord group,
  ) {
    return addon.addonGroupId == group.addonGroupId ||
        addon.addonGroupName.toLowerCase() ==
            group.addonGroupName.toLowerCase();
  }

  StoreProductAddonItemRecord? _findAddonItemRecord(
    StoreAddOrderItemAddonRequest addon,
    List<StoreProductAddonGroupRecord> groups,
  ) {
    for (final group in groups) {
      if (!_addonMatchesGroupRecord(addon, group)) {
        continue;
      }
      for (final item in group.items) {
        if (addon.addonItemId == item.addonItemId ||
            addon.addonItemName.toLowerCase() ==
                item.addonItemName.toLowerCase()) {
          return item;
        }
      }
    }
    return null;
  }

  Future<List<StoreProductAddonGroupRecord>> _getProductAddonGroupRecords(
    StoreScope scope,
    String productVariantId,
  ) async {
    final rows = await _productRepo.getAddonGroupsForVariant(
      scope,
      productVariantId,
    );
    return rows
        .map((row) {
          final minSelections =
              (row['min_selections'] as num?)?.toInt() ??
              (row['min'] as num?)?.toInt() ??
              0;
          final maxSelections =
              (row['max_selections'] as num?)?.toInt() ??
              (row['max'] as num?)?.toInt();
          final items =
              ((row['addon_item_data'] as List<dynamic>?) ?? const <dynamic>[])
                  .map(
                    (rawItem) => rawItem is Map<String, dynamic>
                        ? rawItem
                        : (rawItem as Map).cast<String, dynamic>(),
                  )
                  .map(
                    (item) => StoreProductAddonItemRecord(
                      addonGroupId:
                          '${row['addon_group_id'] ?? row['id'] ?? ''}',
                      addonGroupName:
                          '${row['addon_group_name'] ?? row['name'] ?? ''}',
                      addonItemId: '${item['id'] ?? ''}',
                      addonItemName: '${item['name'] ?? ''}',
                      minSelections: minSelections,
                      maxSelections: maxSelections,
                      active: item['active'] is bool
                          ? item['active'] as bool
                          : ((item['active'] as num?)?.toInt() ?? 1) == 1,
                      defaultSelected: item['default_selected'] is bool
                          ? item['default_selected'] as bool
                          : item['default'] is bool
                          ? item['default'] as bool
                          : ((item['default_selected'] as num?)?.toInt() ??
                                    (item['default'] as num?)?.toInt() ??
                                    0) ==
                                1,
                      sellPrice:
                          _parsePrice(item['sell_price']) ??
                          _parsePrice(item['price']) ??
                          0,
                      buyPrice:
                          _parsePrice(item['buy_price']) ??
                          _parsePrice(item['price']),
                      mrpPrice:
                          _parsePrice(item['mrp_price']) ??
                          _parsePrice(item['sell_price']) ??
                          _parsePrice(item['price']) ??
                          0,
                    ),
                  )
                  .toList(growable: false);
          return StoreProductAddonGroupRecord(
            addonGroupId: '${row['addon_group_id'] ?? row['id'] ?? ''}',
            addonGroupName: '${row['addon_group_name'] ?? row['name'] ?? ''}',
            minSelections: minSelections,
            maxSelections: maxSelections,
            source: row['source'] as String? ?? '',
            items: items,
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _resolveOrderItemPricing(
    StoreScope scope,
    StoreAddOrderItemRequest request,
  ) async {
    final order = await _ordersRepo.getOrderById(scope, request.orderId);
    if (order == null) {
      throw StoreOrderStateException('Order ${request.orderId} was not found.');
    }

    final orderPricingMode = StoreOrderPricingMode.normalize(
      order['pricing_mode'],
    );
    if (request.pricingMode != null &&
        StoreOrderPricingMode.normalize(request.pricingMode) !=
            orderPricingMode) {
      throw StoreOrderStateException(
        'Order ${request.orderId} uses pricing mode $orderPricingMode.',
      );
    }

    final variant = await _productRepo.getProductVariantById(
      scope,
      request.productVariantId,
    );
    final resolvedSellPrice =
        _parsePrice(variant?['sell_price']) ??
        request.sellPrice ??
        request.unitPrice ??
        0;
    final resolvedBuyPrice =
        _parsePrice(variant?['buy_price']) ?? request.buyPrice;
    final resolvedMrpPrice =
        _parsePrice(variant?['mrp_price']) ??
        request.mrpPrice ??
        resolvedSellPrice;
    final resolvedUnitPrice = _resolvePriceForMode(
      pricingMode: orderPricingMode,
      sellPrice: _parsePrice(variant?['sell_price']) ?? request.sellPrice,
      buyPrice: _parsePrice(variant?['buy_price']) ?? request.buyPrice,
      fallbackPrice: request.unitPrice,
    );

    return {
      'pricing_mode': orderPricingMode,
      'sell_price': resolvedSellPrice,
      'buy_price': resolvedBuyPrice,
      'mrp_price': resolvedMrpPrice,
      'unit_price': resolvedUnitPrice,
    };
  }

  Future<Map<String, dynamic>> _resolveOrderItemAddonPricing(
    StoreScope scope,
    StoreAddOrderItemAddonRequest request,
    Map<String, dynamic> item,
  ) async {
    final itemPricingMode = StoreOrderPricingMode.normalize(
      item['pricing_mode'],
    );
    if (request.pricingMode != null &&
        StoreOrderPricingMode.normalize(request.pricingMode) !=
            itemPricingMode) {
      throw StoreOrderStateException(
        'Order item ${(item['id'] as num?)?.toInt() ?? 0} uses pricing mode $itemPricingMode.',
      );
    }

    final groups = await _getProductAddonGroupRecords(
      scope,
      item['product_variant_id'] as String? ?? '',
    );
    final groupRecord = groups
        .where((group) => _addonMatchesGroupRecord(request, group))
        .firstWhere(
          (_) => true,
          orElse: () => StoreProductAddonGroupRecord(
            addonGroupId: request.addonGroupId,
            addonGroupName: request.addonGroupName,
            minSelections: request.minSelections,
            maxSelections: request.maxSelections,
            source: '',
            items: const [],
          ),
        );
    final addonItem = _findAddonItemRecord(request, groups);
    final resolvedSellPrice =
        addonItem?.sellPrice ?? request.sellPrice ?? request.unitPrice ?? 0;
    final resolvedBuyPrice = addonItem?.buyPrice ?? request.buyPrice;
    final resolvedMrpPrice =
        addonItem?.mrpPrice ?? request.mrpPrice ?? resolvedSellPrice;
    final resolvedUnitPrice = _resolvePriceForMode(
      pricingMode: itemPricingMode,
      sellPrice: addonItem?.sellPrice ?? request.sellPrice,
      buyPrice: addonItem?.buyPrice ?? request.buyPrice,
      fallbackPrice: request.unitPrice,
    );

    return {
      'pricing_mode': itemPricingMode,
      'sell_price': resolvedSellPrice,
      'buy_price': resolvedBuyPrice,
      'mrp_price': resolvedMrpPrice,
      'unit_price': resolvedUnitPrice,
      'min_selections': groupRecord.minSelections,
      'max_selections': groupRecord.maxSelections,
    };
  }

  bool _addonMatchesGroup(
    StoreAddOrderItemAddonRequest addon,
    Map<String, dynamic> group,
  ) {
    final groupId = '${group['addon_group_id'] ?? group['id'] ?? ''}';
    final groupName = '${group['addon_group_name'] ?? group['name'] ?? ''}'
        .toLowerCase();
    return addon.addonGroupId == groupId ||
        addon.addonGroupName.toLowerCase() == groupName;
  }

  bool _addonItemIsAllowed(
    StoreAddOrderItemAddonRequest addon,
    Map<String, dynamic> group,
  ) {
    final rawItems = group['addon_item_data'];
    if (rawItems is! List || rawItems.isEmpty) {
      return true;
    }
    for (final rawItem in rawItems.whereType<Map>()) {
      final item = rawItem.cast<String, dynamic>();
      final itemId = '${item['id'] ?? ''}';
      final itemName = '${item['name'] ?? ''}'.toLowerCase();
      if (addon.addonItemId == itemId ||
          addon.addonItemName.toLowerCase() == itemName) {
        return true;
      }
    }
    return false;
  }

  Future<void> _validateOrderItemAddonsForVariant(
    StoreScope scope,
    String productVariantId,
    List<StoreAddOrderItemAddonRequest> addons, {
    bool enforceAllRequiredGroups = true,
  }) async {
    final groups = await _productRepo.getAddonGroupsForVariant(
      scope,
      productVariantId,
    );
    if (groups.isEmpty) {
      return;
    }

    for (final addon in addons) {
      final matchingGroup = groups
          .where((group) => _addonMatchesGroup(addon, group))
          .toList(growable: false);
      if (matchingGroup.isEmpty) {
        throw StoreOrderStateException(
          'Add-on group ${addon.addonGroupName} is not available for product variant $productVariantId.',
        );
      }
      final isAllowed = matchingGroup.any(
        (group) => _addonItemIsAllowed(addon, group),
      );
      if (!isAllowed) {
        throw StoreOrderStateException(
          'Add-on item ${addon.addonItemName} is not available for product variant $productVariantId.',
        );
      }
    }

    for (final group in groups) {
      final minSelections =
          (group['min_selections'] as num?)?.toInt() ??
          (group['min'] as num?)?.toInt() ??
          0;
      final maxSelections =
          (group['max_selections'] as num?)?.toInt() ??
          (group['max'] as num?)?.toInt();
      final selectedCount = addons
          .where((addon) => _addonMatchesGroup(addon, group))
          .fold<int>(0, (total, addon) => total + addon.quantity);
      final groupName =
          '${group['addon_group_name'] ?? group['name'] ?? 'Add-on group'}';

      if (enforceAllRequiredGroups && selectedCount < minSelections) {
        throw StoreOrderStateException(
          'Cannot add order item for product variant $productVariantId. $groupName requires at least $minSelections selection(s).',
        );
      }
      if (selectedCount > 0 &&
          maxSelections != null &&
          selectedCount > maxSelections) {
        throw StoreOrderStateException(
          'Cannot add order item for product variant $productVariantId. $groupName allows at most $maxSelections selection(s).',
        );
      }
    }
  }

  Future<void> _recalculateOrderItemPricing(
    StoreScope scope,
    int itemId, {
    bool refreshTotals = true,
  }) async {
    final item = await _ordersRepo.getOrderItemById(scope, itemId);
    if (item == null) {
      return;
    }
    final baseUnitPrice =
        (item['base_unit_price'] as num?)?.toDouble() ??
        (item['unit_price'] as num?)?.toDouble() ??
        0;
    final enteredQuantity = (item['qty'] as num?)?.toDouble() ?? 0;
    final addonUnitTotal = await _ordersRepo.getOrderItemAddonUnitTotal(
      scope,
      itemId,
    );
    final resolvedUnitPrice = baseUnitPrice + addonUnitTotal;

    // Package sell units: price is per sell_unit_base_qty (e.g. $110 / 6kg).
    // Billable packages = ceil(enteredQty / baseQty), not enteredQty itself.
    var billableQuantity = enteredQuantity;
    final variantId = '${item['product_variant_id'] ?? ''}';
    if (variantId.isNotEmpty) {
      final variant = await _productRepo.getProductVariantById(
        scope,
        variantId,
      );
      final baseQty = (variant?['sell_unit_base_qty'] as num?)?.toDouble();
      if (baseQty != null && baseQty > 0 && enteredQuantity > 0) {
        billableQuantity = (enteredQuantity / baseQty).ceilToDouble();
      }
    }

    final resolvedFinalPrice = resolvedUnitPrice * billableQuantity;
    await _ordersRepo.updateOrderItemPricing(
      scope,
      itemId,
      unitPrice: resolvedUnitPrice,
      finalPrice: resolvedFinalPrice,
    );
    final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
    if (refreshTotals && orderId != 0) {
      await _refreshOrderTotal(scope, orderId);
    }
  }

  Future<int> _createOrderItemAddon(
    StoreScope scope,
    StoreAddOrderItemAddonRequest request, {
    int? itemId,
    bool refreshTotals = true,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final resolvedItemId = itemId ?? request.orderItemId;
    if (resolvedItemId == null || resolvedItemId <= 0) {
      throw ArgumentError.value(
        resolvedItemId,
        'orderItemId',
        'A valid order item id is required.',
      );
    }
    final item = await _ordersRepo.getOrderItemById(scope, resolvedItemId);
    if (item == null) {
      throw StoreOrderStateException(
        'Order item $resolvedItemId was not found.',
      );
    }

    await _validateOrderItemAddonsForVariant(
      scope,
      item['product_variant_id'] as String? ?? '',
      [request],
      enforceAllRequiredGroups: false,
    );

    final existingAddons = await _ordersRepo.getOrderItemAddons(
      scope,
      resolvedItemId,
    );
    final matchingGroup = existingAddons
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (addon) => addon?['addon_group_id'] == request.addonGroupId,
          orElse: () => null,
        );
    final resolvedPricing = await _resolveOrderItemAddonPricing(
      scope,
      request,
      item,
    );
    final resolvedMinSelections =
        (matchingGroup?['min_selections'] as num?)?.toInt() ??
        (resolvedPricing['min_selections'] as num?)?.toInt() ??
        request.minSelections;
    final resolvedMaxSelections =
        (matchingGroup?['max_selections'] as num?)?.toInt() ??
        (resolvedPricing['max_selections'] as num?)?.toInt() ??
        request.maxSelections;
    final currentSelections = await _ordersRepo.getOrderItemAddonSelectionCount(
      scope,
      resolvedItemId,
      addonGroupId: request.addonGroupId,
    );
    final nextSelections = currentSelections + request.quantity;
    if (resolvedMaxSelections != null &&
        nextSelections > resolvedMaxSelections) {
      throw StoreOrderStateException(
        'Cannot add ${request.quantity} add-on item(s) to group ${request.addonGroupName}. Maximum allowed is $resolvedMaxSelections.',
      );
    }

    final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
    final addonId = await _ordersRepo.addOrderItemAddon(
      scope,
      request.toRow(
        scope,
        orderId: orderId,
        resolvedOrderItemId: resolvedItemId,
        resolvedMinSelections: resolvedMinSelections,
        resolvedMaxSelections: resolvedMaxSelections,
        resolvedPricingMode:
            resolvedPricing['pricing_mode'] as String? ??
            StoreOrderPricingMode.selling,
        resolvedSellPrice:
            (resolvedPricing['sell_price'] as num?)?.toDouble() ?? 0,
        resolvedBuyPrice: (resolvedPricing['buy_price'] as num?)?.toDouble(),
        resolvedMrpPrice:
            (resolvedPricing['mrp_price'] as num?)?.toDouble() ?? 0,
        resolvedUnitPrice:
            (resolvedPricing['unit_price'] as num?)?.toDouble() ?? 0,
      ),
    );
    if (refreshTotals) {
      await _recalculateOrderItemPricing(scope, resolvedItemId);
    }
    return addonId;
  }

  Future<void> _refreshOrderTotal(StoreScope scope, int orderId) async {
    final pricingSnapshot = await _buildOrderPricingSnapshot(scope, orderId);
    await _ordersRepo.updateOrderAmounts(
      scope,
      orderId,
      totalValue: (pricingSnapshot['subtotal'] as num?)?.toDouble() ?? 0,
      offerAppliedValue:
          (pricingSnapshot['totalDiscount'] as num?)?.toDouble() ?? 0,
      finalValue: (pricingSnapshot['total'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Recalculates and persists order money columns from line items + offers.
  Future<Map<String, double>> _refreshOrderTotals(
    StoreScope scope,
    int orderId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final pricingSnapshot = await _buildOrderPricingSnapshot(scope, orderId);
    final totalValue = (pricingSnapshot['subtotal'] as num?)?.toDouble() ?? 0;
    final offerAppliedValue =
        (pricingSnapshot['totalDiscount'] as num?)?.toDouble() ?? 0;
    final finalValue = (pricingSnapshot['total'] as num?)?.toDouble() ?? 0;
    await _ordersRepo.updateOrderAmounts(
      scope,
      orderId,
      totalValue: totalValue,
      offerAppliedValue: offerAppliedValue,
      finalValue: finalValue,
    );
    return {
      'totalValue': totalValue,
      'offerAppliedValue': offerAppliedValue,
      'finalValue': finalValue,
    };
  }

  Future<int> _setOrderAmounts(
    StoreScope scope,
    int orderId, {
    required double totalValue,
    required double offerAppliedValue,
    required double finalValue,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _ordersRepo.updateOrderAmounts(
      scope,
      orderId,
      totalValue: _roundCurrency(totalValue),
      offerAppliedValue: _roundCurrency(offerAppliedValue),
      finalValue: _roundCurrency(finalValue),
    );
  }

  Future<int> _createOrderItem(
    StoreScope scope,
    StoreAddOrderItemRequest request, {
    bool refreshTotals = true,
    bool recalculateItemPricing = true,
  }) async {
    await _validateOrderItemAddonsForVariant(
      scope,
      request.productVariantId,
      request.addons,
    );
    final resolvedPricing = await _resolveOrderItemPricing(scope, request);
    final tableAssignment = await _resolveOrderItemTableAssignment(
      scope,
      request.orderId,
      request.tableId,
    );
    final itemId = await _addOrderItem(
      scope,
      request.toRow(
        scope,
        resolvedPricingMode:
            resolvedPricing['pricing_mode'] as String? ??
            StoreOrderPricingMode.selling,
        resolvedSellPrice:
            (resolvedPricing['sell_price'] as num?)?.toDouble() ?? 0,
        resolvedBuyPrice: (resolvedPricing['buy_price'] as num?)?.toDouble(),
        resolvedMrpPrice:
            (resolvedPricing['mrp_price'] as num?)?.toDouble() ?? 0,
        resolvedUnitPrice:
            (resolvedPricing['unit_price'] as num?)?.toDouble() ?? 0,
        resolvedTableId: tableAssignment?['table_id'],
        resolvedTableName: tableAssignment?['table_name'],
        resolvedFloorId: tableAssignment?['floor_id'],
        resolvedFloorName: tableAssignment?['floor_name'],
      ),
    );
    for (final addon in request.addons) {
      await _createOrderItemAddon(
        scope,
        addon,
        itemId: itemId,
        refreshTotals: false,
      );
    }
    if (recalculateItemPricing) {
      await _recalculateOrderItemPricing(
        scope,
        itemId,
        refreshTotals: refreshTotals,
      );
    }
    return itemId;
  }

  Future<int> _updateOrderItemQuantity(
    StoreScope scope,
    int itemId,
    int quantity,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final item = await _ordersRepo.getOrderItemById(scope, itemId);
    if (item == null) {
      return 0;
    }
    await _trackKitchenCancellationIfNeeded(
      scope,
      item,
      nextQuantity: quantity,
      note: 'Quantity reduced after kitchen send',
    );
    final updated = await _ordersRepo.updateOrderItemQuantity(
      scope,
      itemId,
      quantity: quantity,
    );
    final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
    if (updated > 0 && orderId != 0) {
      await _refreshOrderTotal(scope, orderId);
    }
    return updated;
  }

  Future<int> _deleteOrderItem(StoreScope scope, int itemId) async {
    _validateScope(scope);
    await _requireRole('member');
    final item = await _ordersRepo.getOrderItemById(scope, itemId);
    if (item == null) {
      return 0;
    }
    await _trackKitchenCancellationIfNeeded(
      scope,
      item,
      nextQuantity: 0,
      note: 'Item deleted after kitchen send',
    );
    final deleted = await _ordersRepo.deleteOrderItem(scope, itemId);
    final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
    if (deleted > 0 && orderId != 0) {
      await _refreshOrderTotal(scope, orderId);
    }
    return deleted;
  }

  Future<int> _deleteOrderItemAddon(StoreScope scope, int addonId) async {
    _validateScope(scope);
    await _requireRole('member');
    final addon = await _ordersRepo.getOrderItemAddonById(scope, addonId);
    if (addon == null) {
      return 0;
    }

    final itemId = (addon['order_item_id'] as num?)?.toInt() ?? 0;
    final addonGroupId = addon['addon_group_id'] as String? ?? '';
    final currentSelections = await _ordersRepo.getOrderItemAddonSelectionCount(
      scope,
      itemId,
      addonGroupId: addonGroupId,
    );
    final removedSelections = (addon['qty'] as num?)?.toInt() ?? 0;
    final minSelections = (addon['min_selections'] as num?)?.toInt() ?? 0;
    final nextSelections = currentSelections - removedSelections;
    if (nextSelections < minSelections) {
      throw StoreOrderStateException(
        'Cannot remove add-on ${addon['addon_item_name']}. Minimum required selections for ${addon['addon_group_name']} is $minSelections.',
      );
    }

    final deleted = await _ordersRepo.deleteOrderItemAddon(scope, addonId);
    if (deleted > 0 && itemId != 0) {
      await _recalculateOrderItemPricing(scope, itemId);
    }
    return deleted;
  }

  Future<int> _countPendingExportOrders(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _ordersRepo.countPendingExportOrders(scope);
  }

  Future<List<Map<String, dynamic>>> _listPendingExportOrders(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _ordersRepo.listPendingExportOrders(
      scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _markOrdersExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _ordersRepo.markOrdersExported(scope, localIds, exported: exported);
  }

  Future<int> _scheduleOrderExportBackoff(
    StoreScope scope,
    List<String> localIds,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _ordersRepo.scheduleExportBackoff(scope, localIds);
  }

  // Products
  Future<List<String>> _listProductNames(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.getAllProductNames(scope);
  }

  Future<List<Map<String, dynamic>>> _searchProductVariants({
    required StoreScope scope,
    String? query,
    int? limit,
    int? offset,
    bool activeOnly = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.searchProductVariants(
      scope,
      query: query,
      limit: limit,
      offset: offset,
      activeOnly: activeOnly,
    );
  }

  Future<List<StoreProductVariantRecord>> _searchProductVariantRecords({
    required StoreScope scope,
    String? query,
    int? limit,
    int? offset,
    bool activeOnly = false,
  }) async {
    final rows = await _searchProductVariants(
      scope: scope,
      query: query,
      limit: limit,
      offset: offset,
      activeOnly: activeOnly,
    );
    return rows.map(StoreProductVariantRecord.fromRow).toList();
  }

  Future<void> _importProductsFromJson(
    StoreScope scope,
    Map<String, dynamic> data,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.importProductsFromJson(scope, data);
  }

  Future<void> _importProductVariantsFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool markAsExported = true,
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    final importer = ProductDataImporter(_db);
    await importer.importFromJsonData(
      data,
      scope: scope,
      markAsExported: markAsExported,
    );
  }

  Future<void> _importCustomersFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }

    final organisationRolesByCustomerId = <String, Map<String, dynamic>>{};
    for (final orgRoleRow in _extractRowList(data['org_roles'])) {
      final rowOrgId =
          orgRoleRow['orgId'] as String? ??
          orgRoleRow['org_id'] as String? ??
          scope.orgId;
      if (rowOrgId != scope.orgId) {
        continue;
      }
      final customerId = orgRoleRow['customerId'] as String?;
      if (customerId == null || customerId.isEmpty) {
        continue;
      }
      organisationRolesByCustomerId[customerId] = orgRoleRow;
    }

    for (final customerRow in _extractRowList(data['data'])) {
      final rowOrgId = customerRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = customerRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }
      final rawPassword = customerRow['password'] as String? ?? '';
      final password = rawPassword.isEmpty || rawPassword.length == 64
          ? rawPassword
          : CustomerRepository.hashPassword(rawPassword);
      final orgRoleRow =
          organisationRolesByCustomerId[customerRow['customerId'] as String? ??
              ''];
      final customerId = customerRow['customerId'];
      final normalizedIncoming = password;
      String resolvedPassword = normalizedIncoming;
      if (customerId != null) {
        resolvedPassword = await CustomerRepository.resolveImportedPassword(
          db: _db,
          customerId: '$customerId',
          incomingPassword: normalizedIncoming,
        );
      }
      await _db.insert('customers', {
        'customerId': customerId,
        'remote_id': customerRow['remote_id'] ?? customerRow['customerId'],
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'name': customerRow['name'],
        'email': customerRow['email'],
        'phone': customerRow['phone'],
        'country': customerRow['country'],
        'status': customerRow['status'],
        'role': customerRow['role'] ?? orgRoleRow?['role'],
        'password': resolvedPassword,
        'usr_reg_num':
            '${customerRow['usr_reg_num'] ?? customerRow['reg_num'] ?? ''}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final roleRow in _extractRowList(data['store_roles'])) {
      final rowOrgId = roleRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = roleRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }
      final accessValue = roleRow['access_enabled'];
      final accessEnabled = accessValue is bool
          ? accessValue
          : ((accessValue as num?)?.toInt() ?? 1) == 1;
      await _db.insert('store_roles', {
        'remote_id':
            roleRow['remote_id'] ??
            '$rowOrgId:$rowStoreId:${roleRow['customerId']}:${roleRow['role'] ?? 'guest'}',
        'customerId': roleRow['customerId'],
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'role': roleRow['role'] ?? 'guest',
        'access_enabled': accessEnabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _importCreditsFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }

    // Store-wide defaults travel with credits so tablet config stays current.
    final storeSettings = data['store_settings'];
    if (storeSettings is Map) {
      _lastImportedCreditStoreSettings = storeSettings.cast<String, dynamic>();
    }

    for (final accountRow in _extractRowList(data['accounts'])) {
      final rowOrgId = accountRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = accountRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }
      final customerId = '${accountRow['customerId'] ?? ''}'.trim();
      if (customerId.isEmpty) continue;
      final now = DateTime.now().toIso8601String();
      final remoteId =
          (accountRow['remote_id'] as num?)?.toInt() ??
          (accountRow['id'] as num?)?.toInt();
      final localId = accountRow['local_id'] as String?;
      final existing = await _findExistingCreditAccountBySyncIdentity(
        scope,
        remoteId: remoteId,
        localId: localId,
        customerId: customerId,
      );
      final rawLimit = accountRow['credit_limit_amount'];
      final limit = rawLimit == null || '$rawLimit'.trim().isEmpty
          ? null
          : (rawLimit as num?)?.toDouble() ?? double.tryParse('$rawLimit');
      final values = {
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'local_id': (localId != null && localId.isNotEmpty)
            ? localId
            : existing?['local_id'] ?? _newLocalSyncId('credit-account'),
        'remote_id': remoteId ?? existing?['remote_id'],
        'customerId': customerId,
        'credit_limit_amount': limit,
        'outstanding_balance':
            (accountRow['outstanding_balance'] as num?)?.toDouble() ?? 0,
        'total_credit_so_far':
            (accountRow['total_credit_so_far'] as num?)?.toDouble() ?? 0,
        'total_repaid': (accountRow['total_repaid'] as num?)?.toDouble() ?? 0,
        'updated_on': accountRow['updated_on'] as String? ?? now,
      };
      if (existing == null) {
        await _db.insert(
          'credit_accounts',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'credit_accounts',
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }

    for (final creditRow in _extractRowList(data['data'])) {
      final rowOrgId = creditRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = creditRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }
      final now = DateTime.now().toIso8601String();
      final remoteId =
          (creditRow['remote_id'] as num?)?.toInt() ??
          (creditRow['id'] as num?)?.toInt();
      final localId = creditRow['local_id'] as String?;
      final existing = await _findExistingCreditBySyncIdentity(
        scope,
        remoteId: remoteId,
        localId: localId,
      );
      final values = {
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'local_id': (localId != null && localId.isNotEmpty)
            ? localId
            : existing?['local_id'] ?? _newLocalSyncId('credit'),
        'remote_id': remoteId ?? existing?['remote_id'],
        'customerId': creditRow['customerId'] as String?,
        'order_id': (creditRow['order_id'] as num?)?.toInt() ?? 0,
        'amount': (creditRow['amount'] as num?)?.toDouble() ?? 0,
        'due_date': creditRow['due_date'] as String?,
        'created_on': creditRow['created_on'] as String? ?? now,
        'updated_on':
            creditRow['updated_on'] as String? ??
            creditRow['created_on'] as String? ??
            now,
      };
      if (existing == null) {
        await _db.insert(
          'credits',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'credits',
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }

    for (final repaymentRow in _extractRowList(data['repayments'])) {
      final rowOrgId = repaymentRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = repaymentRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }

      final now = DateTime.now().toIso8601String();
      final remoteId =
          (repaymentRow['remote_id'] as num?)?.toInt() ??
          (repaymentRow['id'] as num?)?.toInt();
      final localId = repaymentRow['local_id'] as String?;
      final existing = await _findExistingCreditRepaymentBySyncIdentity(
        scope,
        remoteId: remoteId,
        localId: localId,
      );
      final values = {
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'local_id': (localId != null && localId.isNotEmpty)
            ? localId
            : existing?['local_id'] ?? _newLocalSyncId('credit-repayment'),
        'remote_id': remoteId ?? existing?['remote_id'],
        'customerId': repaymentRow['customerId'] as String? ?? '',
        'payment_mode': repaymentRow['payment_mode'] as String? ?? '',
        'total_amount': (repaymentRow['total_amount'] as num?)?.toDouble() ?? 0,
        'reference_id': repaymentRow['reference_id'] as String?,
        'paid_on': repaymentRow['paid_on'] as String? ?? now,
        'created_on':
            repaymentRow['created_on'] as String? ??
            repaymentRow['paid_on'] as String? ??
            now,
        'updated_on':
            repaymentRow['updated_on'] as String? ??
            repaymentRow['created_on'] as String? ??
            repaymentRow['paid_on'] as String? ??
            now,
        'deleted_reason': repaymentRow['deleted_reason'] as String?,
        'deleted_by_customer_id':
            repaymentRow['deleted_by_customer_id'] as String?,
        'deleted_on': repaymentRow['deleted_on'] as String?,
      };
      if (existing == null) {
        await _db.insert(
          'credit_repayments',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'credit_repayments',
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }

    for (final allocationRow in _extractRowList(data['allocations'])) {
      final rowOrgId = allocationRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = allocationRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }

      final credit = await _findExistingCreditBySyncIdentity(
        scope,
        remoteId: (allocationRow['credit_remote_id'] as num?)?.toInt(),
        localId: allocationRow['credit_local_id'] as String?,
      );
      final repayment = await _findExistingCreditRepaymentBySyncIdentity(
        scope,
        remoteId: (allocationRow['repayment_remote_id'] as num?)?.toInt(),
        localId: allocationRow['repayment_local_id'] as String?,
      );

      final resolvedCreditId = (credit?['id'] as num?)?.toInt();
      final resolvedRepaymentId = (repayment?['id'] as num?)?.toInt();
      if (resolvedCreditId == null || resolvedRepaymentId == null) {
        continue;
      }

      final existingAllocation = await _findExistingCreditRepaymentAllocation(
        resolvedRepaymentId,
        resolvedCreditId,
      );
      final values = {
        'repayment_id': resolvedRepaymentId,
        'credit_id': resolvedCreditId,
        'allocated_amount':
            (allocationRow['allocated_amount'] as num?)?.toDouble() ?? 0,
      };
      if (existingAllocation == null) {
        await _db.insert(
          'credit_repayment_allocations',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'credit_repayment_allocations',
          values,
          where: 'id = ?',
          whereArgs: [existingAllocation['id']],
        );
      }
    }

    for (final installmentRow in _extractRowList(data['installments'])) {
      final rowOrgId = installmentRow['orgId'] as String? ?? scope.orgId;
      final rowStoreId = installmentRow['storeId'] as String? ?? scope.storeId;
      if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
        continue;
      }
      final credit = await _findExistingCreditBySyncIdentity(
        scope,
        remoteId: (installmentRow['credit_remote_id'] as num?)?.toInt(),
        localId: installmentRow['credit_local_id'] as String?,
      );
      final creditId = (credit?['id'] as num?)?.toInt();
      if (creditId == null) continue;

      final now = DateTime.now().toIso8601String();
      final remoteId =
          (installmentRow['remote_id'] as num?)?.toInt() ??
          (installmentRow['id'] as num?)?.toInt();
      final localId = installmentRow['local_id'] as String?;
      final existing = await _findExistingCreditInstallmentBySyncIdentity(
        scope,
        remoteId: remoteId,
        localId: localId,
      );
      final values = {
        'orgId': rowOrgId,
        'storeId': rowStoreId,
        'local_id': (localId != null && localId.isNotEmpty)
            ? localId
            : existing?['local_id'] ?? _newLocalSyncId('credit-installment'),
        'remote_id': remoteId ?? existing?['remote_id'],
        'credit_id': creditId,
        'credit_local_id':
            installmentRow['credit_local_id'] as String? ??
            credit?['local_id'] as String?,
        'sequence': (installmentRow['sequence'] as num?)?.toInt() ?? 1,
        'amount': (installmentRow['amount'] as num?)?.toDouble() ?? 0,
        'paid_amount': (installmentRow['paid_amount'] as num?)?.toDouble() ?? 0,
        'due_date': installmentRow['due_date'] as String?,
        'status': installmentRow['status'] as String? ?? 'open',
        'created_on': installmentRow['created_on'] as String? ?? now,
        'updated_on':
            installmentRow['updated_on'] as String? ??
            installmentRow['created_on'] as String? ??
            now,
      };
      if (existing == null) {
        await _db.insert(
          'credit_installments',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'credit_installments',
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
      await _refreshCreditInstallmentPaidAmounts(scope, creditId);
    }
  }

  Future<List<Map<String, dynamic>>> _getProductVariantsByCategory(
    StoreScope scope,
    int categoryId, {
    bool activeOnly = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.getProductVariantsByCategory(
      scope,
      categoryId,
      activeOnly: activeOnly,
    );
  }

  Future<List<StoreProductVariantRecord>> _getProductVariantRecordsByCategory(
    StoreScope scope,
    int categoryId, {
    bool activeOnly = false,
  }) async {
    final rows = await _getProductVariantsByCategory(
      scope,
      categoryId,
      activeOnly: activeOnly,
    );
    return rows.map(StoreProductVariantRecord.fromRow).toList();
  }

  Future<List<StoreProductVariantRecord>>
  _getProductVariantRecordsByCategoryLocalId(
    StoreScope scope,
    String categoryLocalId, {
    bool activeOnly = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = await _productRepo.getProductVariantsByCategoryLocalId(
      scope,
      categoryLocalId,
      activeOnly: activeOnly,
    );
    return rows.map(StoreProductVariantRecord.fromRow).toList();
  }

  Future<StoreProductVariantRecord?> _findProductVariantRecordById(
    StoreScope scope,
    String productVariantId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final key = productVariantId.trim();
    if (key.isEmpty) return null;
    final row = await _productRepo.getProductVariantById(scope, key);
    if (row == null) return null;
    return StoreProductVariantRecord.fromRow(row);
  }

  Future<StoreProductCategoryRecord?> _findProductCategoryRecordById(
    StoreScope scope,
    String categoryId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final key = categoryId.trim();
    if (key.isEmpty) return null;
    final row = await _productRepo.getCategoryById(scope, key);
    if (row == null) return null;
    return StoreProductCategoryRecord.fromRow(row);
  }

  Future<List<int>> _listCategoryIdsWithVariants(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.listCategoryIdsWithVariants(scope);
  }

  Future<List<StoreProductCategoryRecord>> _listProductCategories(
    StoreScope scope,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = await _productRepo.listCategories(scope);
    return rows.map(StoreProductCategoryRecord.fromRow).toList();
  }

  Future<int> _countPendingExportProductVariants(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.countPendingExportProductVariants(scope);
  }

  Future<List<Map<String, dynamic>>> _listPendingExportProductVariants(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.listPendingExportProductVariants(
      scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> _listPendingExportCatalogRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.listPendingExportCatalogRows(
      scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _countPendingExportOffers(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.countPendingExportOffers(scope);
  }

  Future<List<Map<String, dynamic>>> _listPendingExportOffers(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.listPendingExportOffers(
      scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _markOffersExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.markOffersExported(scope, localIds, exported: exported);
  }

  Future<void> _markCatalogRelatedExported(
    StoreScope scope,
    List<String> variantLocalIds,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.markAddonGroupsExportedForVariants(
      scope,
      variantLocalIds,
    );
    await _productRepo.markCatalogMastersExportedFromVariants(
      scope,
      variantLocalIds,
    );
  }

  Future<void> _applyProductExportMappings(
    StoreScope scope,
    List<Map<String, dynamic>> mappings,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.applyProductExportMappings(scope, mappings);
  }

  Future<List<Map<String, dynamic>>> _listMasterCategories() async {
    await _requireRole('member');
    return _productRepo.listMasterCategories(orgId);
  }

  Future<Map<String, dynamic>> _upsertMasterCategory({
    String? localId,
    required String name,
    String? shortCode,
  }) async {
    await _requireRole('admin');
    return _productRepo.upsertMasterCategory(
      orgId: orgId,
      localId: localId,
      name: name,
      shortCode: shortCode,
      serviceVariantType: serviceVariantType,
    );
  }

  Future<Map<String, dynamic>> _linkMasterCategoryToStore({
    required StoreScope scope,
    required String masterLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.linkMasterCategoryToStore(
      scope: scope,
      masterLocalId: masterLocalId,
    );
  }

  Future<Map<String, dynamic>> _createLocalSellableItem({
    required StoreScope scope,
    required String categoryLocalId,
    required String productName,
    required String packageName,
    required double sellPrice,
    required String unitLabel,
    required double unitQty,
    String? taxLabel,
    String? description,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.createLocalSellableItem(
      scope: scope,
      categoryLocalId: categoryLocalId,
      productName: productName,
      packageName: packageName,
      sellPrice: sellPrice,
      unitLabel: unitLabel,
      unitQty: unitQty,
      taxLabel: taxLabel,
      description: description,
    );
  }

  Future<void> _updateLocalVariant({
    required StoreScope scope,
    required String variantLocalId,
    String? packageName,
    String? productName,
    double? sellPrice,
    String? unitLabel,
    double? unitQty,
    String? taxLabel,
    String? description,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.updateLocalVariant(
      scope: scope,
      variantLocalId: variantLocalId,
      packageName: packageName,
      productName: productName,
      sellPrice: sellPrice,
      unitLabel: unitLabel,
      unitQty: unitQty,
      taxLabel: taxLabel,
      description: description,
    );
  }

  Future<void> _setVariantActive({
    required StoreScope scope,
    required String variantLocalId,
    required bool active,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.setVariantActive(scope, variantLocalId, active: active);
  }

  Future<void> _softDeleteVariant({
    required StoreScope scope,
    required String variantLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.softDeleteVariant(scope, variantLocalId);
  }

  Future<void> _softDeleteCategory({
    required StoreScope scope,
    required String categoryLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.softDeleteCategory(scope, categoryLocalId);
  }

  Future<void> _softDeleteOffer({
    required StoreScope scope,
    required String offerLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.softDeleteOffer(scope, offerLocalId);
  }

  Future<void> _softDeleteAddonGroup({
    required StoreScope scope,
    required String groupLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.softDeleteAddonGroup(scope, groupLocalId);
  }

  Future<void> _renameCategory({
    required StoreScope scope,
    required String categoryLocalId,
    required String name,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.renameCategory(scope, categoryLocalId, name: name);
  }

  Future<List<Map<String, dynamic>>> _listMasterProducts() async {
    await _requireRole('member');
    return _productRepo.listMasterProducts(orgId);
  }

  Future<Map<String, dynamic>> _linkMasterProductToStore({
    required StoreScope scope,
    required String masterLocalId,
    required String categoryLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.linkMasterProductToStore(
      scope: scope,
      masterLocalId: masterLocalId,
      categoryLocalId: categoryLocalId,
    );
  }

  Future<Map<String, dynamic>> _upsertLocalOffer({
    required StoreScope scope,
    String? localId,
    required String name,
    required String offerType,
    double? percentageValue,
    double? flatValue,
    double? minimumBillAmount,
    String? description,
    List<String> targetVariantLocalIds = const [],
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.upsertLocalOffer(
      scope: scope,
      localId: localId,
      name: name,
      offerType: offerType,
      percentageValue: percentageValue,
      flatValue: flatValue,
      minimumBillAmount: minimumBillAmount,
      description: description,
      targetVariantLocalIds: targetVariantLocalIds,
    );
  }

  Future<List<Map<String, dynamic>>> _listLocalOffers(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.listLocalOffers(scope);
  }

  Future<List<String>> _listOfferTargetVariantIds(
    StoreScope scope,
    String offerLocalId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.listOfferTargetVariantIds(scope, offerLocalId);
  }

  Future<void> _setVariantOfferLinks({
    required StoreScope scope,
    required String variantLocalId,
    required Set<String> selectedOfferLocalIds,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    final variantId = variantLocalId.trim();
    if (variantId.isEmpty) return;

    final offers = await _productRepo.listLocalOffers(scope);
    for (final offer in offers) {
      final offerId = '${offer['local_id'] ?? offer['localId'] ?? ''}'.trim();
      if (offerId.isEmpty) continue;
      final targets = await _productRepo.listOfferTargetVariantIds(
        scope,
        offerId,
      );
      final currentlyLinked = targets.contains(variantId);
      final shouldLink = selectedOfferLocalIds.contains(offerId);
      if (currentlyLinked == shouldLink) continue;

      final next = <String>[
        for (final t in targets)
          if (t != variantId) t,
      ];
      if (shouldLink) next.add(variantId);

      await _productRepo.upsertLocalOffer(
        scope: scope,
        localId: offerId,
        name: '${offer['name'] ?? ''}'.trim().isEmpty
            ? 'Offer'
            : '${offer['name']}'.trim(),
        offerType: '${offer['offer_type'] ?? 'percentage'}',
        percentageValue: (offer['percentage_value'] as num?)?.toDouble(),
        flatValue: (offer['flat_value'] as num?)?.toDouble(),
        minimumBillAmount: (offer['minimum_bill_amount'] as num?)?.toDouble(),
        description: '${offer['description'] ?? ''}',
        targetVariantLocalIds: next,
      );
    }
  }

  Future<Map<String, dynamic>> _upsertAddonGroup({
    required StoreScope scope,
    String? localId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    List<({String name, double price})> items = const [],
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.upsertAddonGroup(
      scope: scope,
      localId: localId,
      name: name,
      minSelect: minSelect,
      maxSelect: maxSelect,
      items: items,
    );
  }

  Future<void> _linkAddonGroupToVariant({
    required StoreScope scope,
    required String variantLocalId,
    required String groupLocalId,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    await _productRepo.linkAddonGroupToVariant(
      scope: scope,
      variantLocalId: variantLocalId,
      groupLocalId: groupLocalId,
    );
  }

  Future<List<Map<String, dynamic>>> _listAddonGroups(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.listAddonGroups(scope);
  }

  Future<List<Map<String, dynamic>>> _listAddonItemsForGroup(
    StoreScope scope,
    String groupLocalId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _productRepo.listAddonItemsForGroup(scope, groupLocalId);
  }

  Future<int> _markProductVariantsExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _productRepo.markProductVariantsExported(
      scope,
      localIds,
      exported: exported,
    );
  }

  Future<int> _recordSyncAttempt(StoreSyncOperationResult result) async {
    await _requireValidSession();
    final id = await _saveSyncAttempt(_db, result);
    unawaited(StoreSyncDiagnosticsLog.append(result, dbFilePath: _db.path));
    return id;
  }

  Future<String?> _getSyncWatermark(StoreScope scope, String entity) async {
    final rows = await _db.query(
      'sync_watermarks',
      where: 'orgId = ? AND storeId = ? AND entity = ?',
      whereArgs: [scope.orgId, scope.storeId, entity],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = '${rows.first['watermark'] ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _setSyncWatermark(
    StoreScope scope,
    String entity,
    String watermark,
  ) async {
    final value = watermark.trim();
    if (value.isEmpty) return;
    await _db.insert('sync_watermarks', {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'entity': entity,
      'watermark': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StoreSyncAttemptRecord>> _listSyncAttempts(
    StoreScope scope, {
    int limit = 500,
  }) async {
    _validateScope(scope);
    await _requireValidSession();
    final rows = await _loadSyncAttempts(_db, limit: limit);
    return rows.map(StoreSyncAttemptRecord.fromRow).toList();
  }

  // Customers
  Future<List<Map<String, dynamic>>> _listCustomers({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
    List<String>? roles,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _customerRepo.listCustomers(
      scope: scope,
      limit: limit,
      offset: offset,
      roles: roles,
    );
  }

  Future<List<StoreCustomerRecord>> _listCustomerRecords({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) async {
    final rows = await _listCustomers(
      scope: scope,
      limit: limit,
      offset: offset,
    );
    return rows.map(StoreCustomerRecord.fromRow).toList();
  }

  Future<List<StoreCustomer>> _listCustomerDetails({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
    List<String>? roles,
  }) async {
    final rows = await _listCustomers(
      scope: scope,
      limit: limit,
      offset: offset,
      roles: roles,
    );
    return rows.map(StoreCustomer.fromRow).toList();
  }

  Future<List<StoreCustomer>> _listDirectoryCustomerDetails({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) {
    return _listCustomerDetails(
      scope: scope,
      limit: limit,
      offset: offset,
      roles: CustomerRepository.directoryCustomerRoles,
    );
  }

  /// Operators for staff unlock — branch-scoped via store_roles, no session.
  Future<List<StoreCustomer>> _listStoreOperatorsForUnlock({
    required StoreScope scope,
    int limit = 500,
    int offset = 0,
  }) async {
    _validateScope(scope);
    final rows = await _customerRepo.listStoreOperators(
      scope: scope,
      limit: limit,
      offset: offset,
    );
    return rows.map(StoreCustomer.fromRow).toList(growable: false);
  }

  Future<String?> _recordDirectoryCustomer({
    required StoreScope scope,
    required String name,
    required String phone,
    String? email,
    String? uniqueId,
    String role = 'retail_customer',
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.isEmpty || trimmedPhone.isEmpty) {
      return null;
    }
    return _customerRepo.upsertDirectoryCustomer(
      scope: scope,
      name: trimmedName,
      phone: trimmedPhone,
      email: email,
      uniqueId: uniqueId,
      role: role,
    );
  }

  Future<String?> _recordOfflineDirectoryCustomer({
    required StoreScope scope,
    required String name,
    required String phone,
    String? email,
    String role = 'retail_customer',
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.isEmpty || trimmedPhone.isEmpty) {
      return null;
    }
    return _customerRepo.upsertOfflineDirectoryCustomer(
      scope: scope,
      name: trimmedName,
      phone: trimmedPhone,
      email: email,
      role: role,
    );
  }

  /// Applies the gateway's ``localCustomerId → customerId`` results.
  Future<int> _adoptExportedCustomerIds(
    StoreScope scope,
    Map<String, dynamic>? responseJson,
  ) async {
    final results = responseJson?['results'];
    if (results is! List) return 0;
    var adopted = 0;
    for (final raw in results) {
      if (raw is! Map) continue;
      final localId = '${raw['localCustomerId'] ?? ''}';
      final backendId = '${raw['customerId'] ?? ''}';
      if (await _customerRepo.adoptBackendCustomerId(
        scope: scope,
        localId: localId,
        backendId: backendId,
      )) {
        adopted++;
      }
    }
    return adopted;
  }

  Future<List<Map<String, dynamic>>> _searchCustomers({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
    List<String>? roles,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _customerRepo.searchCustomers(
      scope: scope,
      nameQuery: nameQuery,
      phoneQuery: phoneQuery,
      limit: limit,
      offset: offset,
      roles: roles,
    );
  }

  Future<List<StoreCustomerRecord>> _searchCustomerRecords({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
  }) async {
    final rows = await _searchCustomers(
      scope: scope,
      nameQuery: nameQuery,
      phoneQuery: phoneQuery,
      limit: limit,
      offset: offset,
    );
    return rows.map(StoreCustomerRecord.fromRow).toList();
  }

  Future<List<StoreCustomerRecord>> _listCustomerRecordsByQuery(
    StoreCustomerQuery query,
  ) {
    return _listCustomerRecords(
      scope: query.scope,
      limit: query.limit ?? 10,
      offset: query.offset ?? 0,
    );
  }

  Future<List<StoreCustomer>> _listCustomerDetailsByQuery(
    StoreCustomerQuery query,
  ) {
    return _listCustomerDetails(
      scope: query.scope,
      limit: query.limit ?? 10,
      offset: query.offset ?? 0,
    );
  }

  Future<List<StoreCustomerRecord>> _searchCustomerRecordsByQuery(
    StoreCustomerQuery query,
  ) {
    return _searchCustomerRecords(
      scope: query.scope,
      nameQuery: query.nameQuery,
      phoneQuery: query.phoneQuery,
      limit: query.limit,
      offset: query.offset,
    );
  }

  Future<List<StoreCustomer>> _searchCustomerDetailsByQuery(
    StoreCustomerQuery query,
  ) async {
    final rows = await _searchCustomers(
      scope: query.scope,
      nameQuery: query.nameQuery,
      phoneQuery: query.phoneQuery,
      limit: query.limit,
      offset: query.offset,
    );
    return rows.map(StoreCustomer.fromRow).toList();
  }

  Future<List<StoreCustomer>> _listOrganisationCustomerDetails({
    required String orgId,
    int limit = 20,
    int offset = 0,
  }) async {
    await _requireRole('member');
    final rows = await _customerRepo.listOrganisationCustomers(
      orgId: orgId,
      limit: limit,
      offset: offset,
    );
    return rows.map(StoreCustomer.fromRow).toList(growable: false);
  }

  Future<int> _countCustomerExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT c.customerId) AS total
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.customerId = c.customerId
       AND sr.orgId = c.orgId
       AND sr.storeId = c.storeId
      WHERE c.orgId = ? AND c.storeId = ?
        AND sr.role IN ('retail_customer', 'business_customer')
        AND COALESCE(sr.access_enabled, 1) = 1
      ''',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listCustomerExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    // Only trade customers — never push POS operators (admin/member).
    final sql = StringBuffer('''
      SELECT c.*
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.customerId = c.customerId
       AND sr.orgId = c.orgId
       AND sr.storeId = c.storeId
      WHERE c.orgId = ? AND c.storeId = ?
        AND sr.role IN ('retail_customer', 'business_customer')
        AND COALESCE(sr.access_enabled, 1) = 1
      GROUP BY c.customerId
      ORDER BY c.customerId ASC
    ''');
    final args = <Object?>[scope.orgId, scope.storeId];
    if (limit != null) {
      sql.write(' LIMIT ?');
      args.add(limit);
      if (offset != null) {
        sql.write(' OFFSET ?');
        args.add(offset);
      }
    }
    return _db.rawQuery(sql.toString(), args);
  }

  Future<int> _countStoreRoleExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM store_roles WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listStoreRoleExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _db.query(
      'store_roles',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'customerId ASC, storeId ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _countOrganisationRoleExportRows(StoreScope scope) {
    return _countCustomerExportRows(scope);
  }

  Future<List<Map<String, dynamic>>> _listOrganisationRoleExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    final customers = await _listCustomerExportRows(
      scope,
      limit: limit,
      offset: offset,
    );
    return customers
        .map(
          (row) => <String, dynamic>{
            'remote_id':
                row['remote_id'] ??
                '${row['orgId']}:${row['customerId']}:${row['role']}',
            'customerId': row['customerId'],
            'orgId': row['orgId'],
            'customer_name': row['name'],
            'email': row['email'],
            'role': row['role'],
          },
        )
        .toList(growable: false);
  }

  Future<StoreCustomer?> _getCustomer(String customerId) async {
    final row = await _customerRepo.getCustomerById(customerId);
    if (row == null) {
      return null;
    }
    await _requireRole('member');
    return StoreCustomer.fromRow(row);
  }

  Future<String> _createCustomer(StoreCreateCustomerRequest request) async {
    await _requireRole('admin');
    final resolvedOrgId =
        (request.orgId == null || request.orgId!.trim().isEmpty)
        ? orgId
        : request.orgId!.trim();
    if (resolvedOrgId != orgId) {
      throw ArgumentError.value(
        request.orgId,
        'orgId',
        'Customer orgId must match the current store organisation.',
      );
    }
    final resolvedStoreId = request.storeId?.trim() ?? '';
    if (resolvedStoreId.isNotEmpty && resolvedStoreId != storeId) {
      throw ArgumentError.value(
        request.storeId,
        'storeId',
        'Customer storeId must be empty or match the current store.',
      );
    }
    final resolvedCustomerId =
        (request.customerId == null || request.customerId!.trim().isEmpty)
        ? _newCustomerId()
        : request.customerId!.trim();
    final hashedPassword = CustomerRepository.hashPassword(request.password);
    await _customerRepo.createCustomer(
      request.toRow(
        hashedPassword,
        resolvedCustomerId: resolvedCustomerId,
        resolvedOrgId: resolvedOrgId,
        resolvedStoreId: resolvedStoreId,
      ),
    );
    return resolvedCustomerId;
  }

  Future<int> _updateCustomer(
    String customerId,
    StoreUpdateCustomerRequest request,
  ) async {
    await _requireRole('admin');
    final updates = <String, dynamic>{};
    if (request.remoteId != null) updates['remote_id'] = request.remoteId;
    if (request.name != null) updates['name'] = request.name;
    if (request.email != null) updates['email'] = request.email;
    if (request.phone != null) updates['phone'] = request.phone;
    if (request.country != null) updates['country'] = request.country;
    if (request.status != null) updates['status'] = request.status;
    if (request.role != null) updates['role'] = request.role;
    if (request.password != null) {
      updates['password'] = CustomerRepository.hashPassword(request.password!);
    }
    if (updates.isEmpty) {
      return 0;
    }
    return _customerRepo.updateCustomer(customerId, updates);
  }

  Future<int> _deleteCustomer(String customerId) async {
    await _requireRole('admin');
    return _customerRepo.deleteCustomer(customerId);
  }

  Future<String> _saveFloor(
    StoreScope scope,
    StoreSaveFloorRequest request, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    final floorId = request.floorId.trim();
    final name = request.name.trim();
    if (floorId.isEmpty) {
      throw ArgumentError.value(
        request.floorId,
        'floorId',
        'floorId is required.',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        request.name,
        'name',
        'Floor name is required.',
      );
    }

    final values = request.toRow(scope)
      ..['floor_id'] = floorId
      ..['name'] = name;
    final existing = await _db.query(
      'floors',
      where: 'orgId = ? AND storeId = ? AND floor_id = ?',
      whereArgs: [scope.orgId, scope.storeId, floorId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert(
        'floors',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.update(
        'floors',
        values,
        where: 'orgId = ? AND storeId = ? AND floor_id = ?',
        whereArgs: [scope.orgId, scope.storeId, floorId],
      );
    }
    return floorId;
  }

  Future<List<StoreFloorRecord>> _listFloorRecords(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = await _db.query(
      'floors',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'sorting_order ASC, name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(StoreFloorRecord.fromRow).toList(growable: false);
  }

  Future<Map<String, dynamic>?> _getFloorRow(
    StoreScope scope,
    String floorId,
  ) async {
    final rows = await _db.query(
      'floors',
      where: 'orgId = ? AND storeId = ? AND floor_id = ?',
      whereArgs: [scope.orgId, scope.storeId, floorId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> _saveTable(
    StoreScope scope,
    StoreSaveTableRequest request, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    final tableId = request.tableId.trim();
    final floorId = request.floorId.trim();
    final name = request.name.trim();
    if (tableId.isEmpty) {
      throw ArgumentError.value(
        request.tableId,
        'tableId',
        'tableId is required.',
      );
    }
    if (floorId.isEmpty) {
      throw ArgumentError.value(
        request.floorId,
        'floorId',
        'floorId is required.',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        request.name,
        'name',
        'Table name is required.',
      );
    }

    final floor = await _getFloorRow(scope, floorId);
    if (floor == null) {
      throw StoreOrderStateException('Floor $floorId was not found.');
    }

    final values = request.toRow(scope)
      ..['table_id'] = tableId
      ..['floor_id'] = floorId
      ..['name'] = name;
    final existing = await _db.query(
      'tables',
      where: 'orgId = ? AND storeId = ? AND table_id = ?',
      whereArgs: [scope.orgId, scope.storeId, tableId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert(
        'tables',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.update(
        'tables',
        values,
        where: 'orgId = ? AND storeId = ? AND table_id = ?',
        whereArgs: [scope.orgId, scope.storeId, tableId],
      );
    }
    return tableId;
  }

  Future<void> _importTablesFromJsonFile(
    StoreScope scope,
    String filePath, {
    bool skipAuth = false,
  }) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    await _importTablesFromData(scope, data, skipAuth: skipAuth);
  }

  Future<void> _importTablesFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }

    final rawFloors = data['floors'] ?? data['floor_data'] ?? const <dynamic>[];
    if (rawFloors is List) {
      for (final rawFloor in rawFloors.whereType<Map>()) {
        final floor = rawFloor.cast<String, dynamic>();
        await _saveFloor(
          scope,
          StoreSaveFloorRequest(
            floorId:
                floor['floor_id'] as String? ??
                floor['floorId'] as String? ??
                '',
            name: floor['name'] as String? ?? '',
            sortingOrder:
                (floor['sorting_order'] as num?)?.toInt() ??
                (floor['sortingOrder'] as num?)?.toInt() ??
                0,
            active: floor['active'] is bool
                ? floor['active'] as bool
                : ((floor['active'] as num?)?.toInt() ?? 1) == 1,
          ),
          skipAuth: true,
        );
      }
    }

    final rawTables = data['tables'] ?? data['table_data'] ?? const <dynamic>[];
    if (rawTables is List) {
      for (final rawTable in rawTables.whereType<Map>()) {
        final table = rawTable.cast<String, dynamic>();
        await _saveTable(
          scope,
          StoreSaveTableRequest(
            tableId:
                table['table_id'] as String? ??
                table['tableId'] as String? ??
                '',
            floorId:
                table['floor_id'] as String? ??
                table['floorId'] as String? ??
                '',
            name: table['name'] as String? ?? '',
            capacity: (table['capacity'] as num?)?.toInt(),
            sortingOrder:
                (table['sorting_order'] as num?)?.toInt() ??
                (table['sortingOrder'] as num?)?.toInt() ??
                0,
            active: table['active'] is bool
                ? table['active'] as bool
                : ((table['active'] as num?)?.toInt() ?? 1) == 1,
          ),
          skipAuth: true,
        );
      }
    }
  }

  Future<List<StoreWalletRecord>> _listWalletRecords(
    StoreScope scope, {
    bool includeInactive = false,
    bool skipAuth = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('member');
    }
    final where = StringBuffer('orgId = ? AND storeId = ?');
    final args = <Object?>[scope.orgId, scope.storeId];
    if (!includeInactive) {
      where.write(' AND active = 1');
    }
    final rows = await _db.query(
      'wallets',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'sorting_order ASC, id ASC',
    );
    return rows.map(StoreWalletRecord.fromRow).toList(growable: false);
  }

  Future<void> _importWalletsFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool skipAuth = false,
    bool replaceScope = false,
  }) async {
    _validateScope(scope);
    if (!skipAuth) {
      await _requireRole('admin');
    }
    if (replaceScope) {
      await _db.delete(
        'wallets',
        where: 'orgId = ? AND storeId = ?',
        whereArgs: [scope.orgId, scope.storeId],
      );
    }

    final rawWallets = data['data'] ?? data['wallets'] ?? const <dynamic>[];
    if (rawWallets is! List) {
      return;
    }
    for (final raw in rawWallets.whereType<Map>()) {
      final row = raw.cast<String, dynamic>();
      final remoteId =
          (row['remote_id'] as num?)?.toInt() ?? (row['id'] as num?)?.toInt();
      final localId = (row['local_id'] as String?)?.trim().isNotEmpty == true
          ? (row['local_id'] as String).trim()
          : (remoteId != null ? 'wallet-$remoteId' : _newLocalSyncId('wallet'));
      final label = (row['label'] as String?)?.trim().isNotEmpty == true
          ? (row['label'] as String).trim()
          : (row['wallet_variant_name'] as String?)?.trim().isNotEmpty == true
          ? (row['wallet_variant_name'] as String).trim()
          : 'Wallet';
      final paymentModeRaw =
          (row['payment_mode'] as String?)?.trim().toLowerCase() ?? '';
      final paymentMode =
          StoreOrderPaymentMode.supported.contains(paymentModeRaw)
          ? paymentModeRaw
          : StoreOrderPaymentMode.cash;
      final values = <String, Object?>{
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'local_id': localId,
        'remote_id': remoteId,
        'wallet_variant_id': (row['wallet_variant_id'] as num?)?.toInt(),
        'wallet_variant_type': (row['wallet_variant_type'] as num?)?.toInt(),
        'wallet_variant_pg_type': (row['wallet_variant_pg_type'] as num?)
            ?.toInt(),
        'wallet_variant_name': row['wallet_variant_name'] as String?,
        'acc_name': row['acc_name'] as String?,
        'label': label,
        'payment_mode': paymentMode,
        'currency': row['currency'] as String?,
        'sorting_order': (row['sorting_order'] as num?)?.toInt() ?? 0,
        'active': row['active'] is bool
            ? ((row['active'] as bool) ? 1 : 0)
            : ((row['active'] as num?)?.toInt() ?? 1),
      };

      final existing = remoteId == null
          ? await _db.query(
              'wallets',
              columns: ['id'],
              where: 'orgId = ? AND storeId = ? AND local_id = ?',
              whereArgs: [scope.orgId, scope.storeId, localId],
              limit: 1,
            )
          : await _db.query(
              'wallets',
              columns: ['id'],
              where: 'orgId = ? AND storeId = ? AND remote_id = ?',
              whereArgs: [scope.orgId, scope.storeId, remoteId],
              limit: 1,
            );
      if (existing.isEmpty) {
        await _db.insert(
          'wallets',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          'wallets',
          values,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    }

    final rawVariants = data['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      await _saveWalletVariantCatalogue(scope, [
        for (final row in rawVariants.whereType<Map>())
          Map<String, dynamic>.from(row),
      ]);
    }
  }

  Future<List<Map<String, dynamic>>> _listWalletVariantCatalogue(
    StoreScope scope,
  ) async {
    _validateScope(scope);
    await BackendSetup.ensureSchemaRepairs(_db);
    final rows = await _db.query(
      'wallet_variants',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'sorting_order ASC, variant_id ASC',
    );
    return [
      for (final row in rows)
        {
          'id': row['variant_id'],
          'key': row['key'],
          'name': row['name'],
          'type': row['type'],
          'type_name': row['type_name'],
          'pg_type': row['pg_type'],
          'pg_name': row['pg_name'],
          'logo': row['logo'],
          'locked': ((row['locked'] as num?)?.toInt() ?? 1) == 1,
        },
    ];
  }

  Future<void> _saveWalletVariantCatalogue(
    StoreScope scope,
    List<Map<String, dynamic>> variants,
  ) async {
    _validateScope(scope);
    if (variants.isEmpty) return;
    await BackendSetup.ensureSchemaRepairs(_db);
    final now = DateTime.now().toIso8601String();
    await _db.delete(
      'wallet_variants',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
    );
    var order = 0;
    for (final raw in variants) {
      final variantId = (raw['id'] as num?)?.toInt();
      if (variantId == null) continue;
      final name = '${raw['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      order += 1;
      await _db.insert('wallet_variants', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'variant_id': variantId,
        'key': '${raw['key'] ?? ''}'.trim().isEmpty
            ? null
            : '${raw['key']}'.trim(),
        'name': name,
        'type': (raw['type'] as num?)?.toInt(),
        'type_name': '${raw['type_name'] ?? ''}'.trim().isEmpty
            ? null
            : '${raw['type_name']}'.trim(),
        'pg_type': (raw['pg_type'] as num?)?.toInt(),
        'pg_name': '${raw['pg_name'] ?? ''}'.trim().isEmpty
            ? null
            : '${raw['pg_name']}'.trim(),
        'logo': '${raw['logo'] ?? ''}'.trim().isEmpty
            ? null
            : '${raw['logo']}'.trim(),
        'locked': raw['locked'] == false ? 0 : 1,
        'sorting_order': (raw['sorting_order'] as num?)?.toInt() ?? order,
        'synced_on': now,
      });
    }
  }

  Future<StoreWalletRecord> _addLocalWalletVariant(
    StoreScope scope, {
    required int variantId,
    required String label,
    String? variantName,
    int? variantType,
    int? variantPgType,
    String? paymentMode,
  }) async {
    _validateScope(scope);
    final trimmed = label.trim().isEmpty
        ? (variantName ?? 'Wallet').trim()
        : label.trim();
    final modeRaw = (paymentMode ?? '').trim().toLowerCase();
    final mode = StoreOrderPaymentMode.supported.contains(modeRaw)
        ? modeRaw
        : _paymentModeForWalletVariant(
            variantType: variantType,
            variantName: variantName ?? trimmed,
          );

    final existing = await _db.query(
      'wallets',
      where:
          'orgId = ? AND storeId = ? AND wallet_variant_id = ? AND active = 1',
      whereArgs: [scope.orgId, scope.storeId, variantId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await _db.update(
        'wallets',
        {
          'label': trimmed,
          'acc_name': trimmed,
          'wallet_variant_name': variantName ?? trimmed,
          'wallet_variant_type': variantType,
          'wallet_variant_pg_type': variantPgType,
          'payment_mode': mode,
          'active': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final rows = await _db.query('wallets', where: 'id = ?', whereArgs: [id]);
      return StoreWalletRecord.fromRow(rows.first);
    }

    final sortRows = await _db.rawQuery(
      'SELECT MAX(sorting_order) AS m FROM wallets WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    final nextSort = ((sortRows.first['m'] as num?)?.toInt() ?? 0) + 1;
    final localId = _newLocalSyncId('wallet');
    final id = await _db.insert('wallets', {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'local_id': localId,
      'remote_id': null,
      'wallet_variant_id': variantId,
      'wallet_variant_type': variantType,
      'wallet_variant_pg_type': variantPgType,
      'wallet_variant_name': variantName ?? trimmed,
      'acc_name': trimmed,
      'label': trimmed,
      'payment_mode': mode,
      'currency': null,
      'sorting_order': nextSort,
      'active': 1,
    });
    final rows = await _db.query('wallets', where: 'id = ?', whereArgs: [id]);
    return StoreWalletRecord.fromRow(rows.first);
  }

  String _paymentModeForWalletVariant({
    int? variantType,
    required String variantName,
  }) {
    final name = variantName.trim().toLowerCase();
    if (name.contains('card') || name.contains('bank')) {
      return StoreOrderPaymentMode.card;
    }
    if (name.contains('credit') ||
        name.contains('pay later') ||
        name.contains('paylater')) {
      return StoreOrderPaymentMode.credit;
    }
    if (name.contains('upi') ||
        name.contains('g-pay') ||
        name.contains('gpay') ||
        name.contains('wallet') ||
        name.contains('online')) {
      return StoreOrderPaymentMode.online;
    }
    // WalletTypeChoices: Cash=1, Gateway=2, Bank=3, EWallet=4, UPI=5
    switch (variantType) {
      case 3:
        return StoreOrderPaymentMode.card;
      case 2:
      case 4:
      case 5:
      case 6:
        return StoreOrderPaymentMode.online;
      default:
        return StoreOrderPaymentMode.cash;
    }
  }

  Future<Map<String, dynamic>> _exportTablesToJsonData(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');

    final floors = await _listFloorRecords(scope);
    final tables = await _listTableRecords(
      scope,
      includeInactive: true,
      includeOccupied: true,
    );

    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'floors': floors
          .map(
            (floor) => {
              'floor_id': floor.floorId,
              'name': floor.name,
              'sorting_order': floor.sortingOrder,
              'active': floor.active,
            },
          )
          .toList(growable: false),
      'tables': tables
          .map(
            (table) => {
              'table_id': table.tableId,
              'floor_id': table.floorId,
              'name': table.name,
              'capacity': table.capacity,
              'sorting_order': table.sortingOrder,
              'active': table.active,
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> _exportTablesToJsonFile(
    StoreScope scope,
    String filePath,
  ) async {
    final data = await _exportTablesToJsonData(scope);
    final file = File(filePath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<int> _countFloorExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM floors WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listFloorExportRows(
    StoreScope scope, {
    required int limit,
    required int offset,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _db.query(
      'floors',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'sorting_order ASC, name COLLATE NOCASE ASC, id ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _countTableExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('member');
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM tables WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listTableExportRows(
    StoreScope scope, {
    required int limit,
    required int offset,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    return _db.query(
      'tables',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'sorting_order ASC, name COLLATE NOCASE ASC, id ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> _listTables(
    StoreScope scope, {
    String? floorId,
    String? tableId,
    bool includeInactive = true,
    bool includeOccupied = true,
  }) async {
    _validateScope(scope);
    await _requireRole('member');

    final whereClauses = <String>['t.orgId = ?', 't.storeId = ?'];
    final whereArgs = <Object?>[
      scope.orgId,
      scope.storeId,
      scope.orgId,
      scope.storeId,
    ];
    if (floorId != null && floorId.trim().isNotEmpty) {
      whereClauses.add('t.floor_id = ?');
      whereArgs.add(floorId.trim());
    }
    if (tableId != null && tableId.trim().isNotEmpty) {
      whereClauses.add('t.table_id = ?');
      whereArgs.add(tableId.trim());
    }
    if (!includeInactive) {
      whereClauses.add('t.active = 1');
    }
    if (!includeOccupied) {
      whereClauses.add('occ.occupied_order_id IS NULL');
    }

    return _db.rawQuery('''
      SELECT
        t.*, 
        COALESCE(f.name, '') AS floor_name,
        CASE WHEN occ.occupied_order_id IS NULL THEN 0 ELSE 1 END AS occupied,
        occ.occupied_order_id,
        occ.occupied_order_status
      FROM tables t
      LEFT JOIN floors f
        ON f.orgId = t.orgId AND f.storeId = t.storeId AND f.floor_id = t.floor_id
      LEFT JOIN (
        SELECT
          oi.table_id,
          MIN(oi.order_id) AS occupied_order_id,
          MAX(o.status_name) AS occupied_order_status
        FROM order_items oi
        INNER JOIN orders o
          ON o.orgId = oi.orgId AND o.storeId = oi.storeId AND o.order_id = oi.order_id
        WHERE oi.orgId = ?
          AND oi.storeId = ?
          AND COALESCE(oi.table_id, '') != ''
          AND LOWER(TRIM(COALESCE(o.status_name, ''))) != 'closed'
          AND LOWER(COALESCE(o.status_name, '')) NOT LIKE '%complet%'
          AND LOWER(COALESCE(o.status_name, '')) NOT LIKE '%cancel%'
        GROUP BY oi.table_id
      ) occ ON occ.table_id = t.table_id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY COALESCE(f.sorting_order, 0) ASC,
               f.name COLLATE NOCASE ASC,
               t.sorting_order ASC,
               t.name COLLATE NOCASE ASC,
               t.id ASC
      ''', whereArgs);
  }

  Future<List<StoreTableRecord>> _listTableRecords(
    StoreScope scope, {
    String? floorId,
    bool includeInactive = true,
    bool includeOccupied = true,
  }) async {
    final rows = await _listTables(
      scope,
      floorId: floorId,
      includeInactive: includeInactive,
      includeOccupied: includeOccupied,
    );
    return rows.map(StoreTableRecord.fromRow).toList(growable: false);
  }

  Future<Map<String, dynamic>?> _getTableRow(
    StoreScope scope,
    String tableId,
  ) async {
    final rows = await _listTables(scope, tableId: tableId);
    return rows.isEmpty ? null : rows.first;
  }

  /// Orders can reference a table the local floor plan does not have yet
  /// (e.g. before floors/tables sync). Create it on the first floor, or a
  /// default "Main" floor, so checkout is not blocked.
  Future<Map<String, dynamic>?> _createMissingTable(
    StoreScope scope,
    String tableId,
  ) async {
    final floors = await _db.query(
      'floors',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'active DESC, sorting_order ASC, id ASC',
      limit: 1,
    );
    final floorId = floors.isNotEmpty
        ? '${floors.first['floor_id']}'
        : await _saveFloor(
            scope,
            const StoreSaveFloorRequest(floorId: 'main', name: 'Main'),
            skipAuth: true,
          );
    await _saveTable(
      scope,
      StoreSaveTableRequest(tableId: tableId, floorId: floorId, name: tableId),
      skipAuth: true,
    );
    return _getTableRow(scope, tableId);
  }

  Future<Map<String, String>?> _resolveOrderItemTableAssignment(
    StoreScope scope,
    int orderId,
    String? tableId,
  ) async {
    final normalizedTableId = tableId?.trim() ?? '';
    if (normalizedTableId.isEmpty) {
      return null;
    }

    final tableRow =
        await _getTableRow(scope, normalizedTableId) ??
        await _createMissingTable(scope, normalizedTableId);
    if (tableRow == null) {
      throw StoreOrderStateException('Table $normalizedTableId was not found.');
    }
    final table = StoreTableRecord.fromRow(tableRow);
    if (!table.active) {
      throw StoreOrderStateException(
        'Table ${table.displayLabel} is inactive.',
      );
    }
    if (table.occupied && table.occupiedOrderId != orderId) {
      throw StoreOrderStateException(
        'Table ${table.displayLabel} is occupied by order ${table.occupiedOrderId}.',
      );
    }
    return {
      'table_id': table.tableId,
      'table_name': table.name,
      'floor_id': table.floorId,
      'floor_name': table.floorName,
    };
  }

  List<StoreOrderTableRecord> _extractOrderTables(
    List<StoreOrderItemDetails> itemDetails,
  ) {
    final distinct = <String, StoreOrderTableRecord>{};
    for (final itemDetailsEntry in itemDetails) {
      final item = itemDetailsEntry.item;
      final tableId = item.tableId?.trim() ?? '';
      final tableName = item.tableName?.trim() ?? '';
      if (tableId.isEmpty || tableName.isEmpty) {
        continue;
      }
      distinct[tableId] = StoreOrderTableRecord(
        tableId: tableId,
        tableName: tableName,
        floorId: item.floorId?.trim() ?? '',
        floorName: item.floorName?.trim() ?? '',
      );
    }
    final values = distinct.values.toList(growable: false)
      ..sort(
        (left, right) => left.displayLabel.toLowerCase().compareTo(
          right.displayLabel.toLowerCase(),
        ),
      );
    return values;
  }

  // Credits
  Future<List<Map<String, dynamic>>> _listCredits(
    StoreScope scope, {
    String? customerId,
    String? createdOnStart,
    String? createdOnEnd,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final whereClauses = <String>['c.orgId = ?', 'c.storeId = ?'];
    final whereArgs = <Object?>[scope.orgId, scope.storeId];
    if (customerId != null && customerId.isNotEmpty) {
      whereClauses.add('c.customerId = ?');
      whereArgs.add(customerId);
    }
    if (createdOnStart != null && createdOnStart.isNotEmpty) {
      whereClauses.add('c.created_on >= ?');
      whereArgs.add(createdOnStart);
    }
    if (createdOnEnd != null && createdOnEnd.isNotEmpty) {
      whereClauses.add('c.created_on < ?');
      whereArgs.add(createdOnEnd);
    }
    return _db.rawQuery('''
      SELECT
        c.*,
        COALESCE(
          NULLIF(MAX(cu.name), ''),
          NULLIF(MAX(cu2.name), ''),
          ''
        ) AS customer_name,
        COALESCE(SUM(a.allocated_amount), 0) AS paid_amount,
        MAX(c.amount - COALESCE(SUM(a.allocated_amount), 0), 0) AS outstanding_amount,
        CASE WHEN COALESCE(SUM(a.allocated_amount), 0) >= c.amount THEN 1 ELSE 0 END AS settled
      FROM credits c
      LEFT JOIN customers cu ON cu.customerId = c.customerId
      LEFT JOIN customers cu2 ON (
        (c.customerId LIKE 'user_%' AND cu2.customerId = SUBSTR(c.customerId, 6))
        OR (c.customerId NOT LIKE 'user_%' AND cu2.customerId = 'user_' || c.customerId)
      )
      LEFT JOIN (
        SELECT a.*
        FROM credit_repayment_allocations a
        INNER JOIN credit_repayments r ON r.id = a.repayment_id
        WHERE r.deleted_on IS NULL
      ) a ON a.credit_id = c.id
      WHERE ${whereClauses.join(' AND ')}
      GROUP BY c.id
      ORDER BY c.updated_on DESC, c.id DESC
      ''', whereArgs);
  }

  Future<int> _createCreditRecord(
    StoreScope scope,
    StoreCreateCreditRequest request,
  ) async {
    _validateScope(scope);
    // Cashiers (member) must be able to record credit sales at checkout.
    await _requireRole('member');
    if (request.orgId.isEmpty) {
      throw ArgumentError.value(request.orgId, 'orgId', 'orgId is required.');
    }
    final localId = request.localId ?? _newLocalSyncId('credit');
    final row = request.toRow(scope);
    row['local_id'] = localId;

    var dueDate = request.dueDate;
    final installmentCount = request.installmentCount ?? 0;
    final plan = installmentCount >= 2
        ? buildCreditInstallmentPlan(
            totalAmount: request.amount,
            count: installmentCount,
            cadence: request.installmentCadence ?? 'weekly',
          )
        : const <StoreCreditInstallmentPlanItem>[];
    if (plan.isNotEmpty) {
      dueDate = plan.last.dueDate;
      row['due_date'] = dueDate;
    }

    final creditId = await _db.insert(
      'credits',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (plan.isNotEmpty) {
      final now = request.updatedOn ?? request.createdOn;
      for (final item in plan) {
        await _db.insert('credit_installments', {
          'orgId': request.orgId,
          'storeId': scope.storeId,
          'local_id': '$localId-inst-${item.sequence}',
          'remote_id': null,
          'credit_id': creditId,
          'credit_local_id': localId,
          'sequence': item.sequence,
          'amount': item.amount,
          'paid_amount': 0,
          'due_date': item.dueDate,
          'status': 'open',
          'created_on': now,
          'updated_on': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await _allocateAvailableCustomerAdvance(
      scope,
      customerId: request.customerId,
      creditId: creditId,
      amount: request.amount,
    );
    if (plan.isNotEmpty) {
      await _refreshCreditInstallmentPaidAmounts(scope, creditId);
    }
    return creditId;
  }

  Future<void> _allocateAvailableCustomerAdvance(
    StoreScope scope, {
    required String customerId,
    required int creditId,
    required double amount,
  }) async {
    var remaining = amount;
    if (remaining <= 0.0001 || customerId.trim().isEmpty) return;
    await _db.transaction((txn) async {
      final repayments = await txn.rawQuery(
        '''
        SELECT
          r.id,
          MAX(r.total_amount - COALESCE(SUM(a.allocated_amount), 0), 0)
            AS available_amount
        FROM credit_repayments r
        LEFT JOIN credit_repayment_allocations a ON a.repayment_id = r.id
        WHERE r.orgId = ? AND r.storeId = ? AND r.customerId = ?
          AND r.deleted_on IS NULL
        GROUP BY r.id
        HAVING available_amount > 0.0001
        ORDER BY r.paid_on ASC, r.id ASC
        ''',
        [scope.orgId, scope.storeId, customerId.trim()],
      );
      for (final repayment in repayments) {
        if (remaining <= 0.0001) break;
        final available =
            (repayment['available_amount'] as num?)?.toDouble() ?? 0;
        final apply = available < remaining ? available : remaining;
        if (apply <= 0.0001) continue;
        await txn.insert(
          'credit_repayment_allocations',
          {
            'repayment_id': (repayment['id'] as num).toInt(),
            'credit_id': creditId,
            'allocated_amount': double.parse(apply.toStringAsFixed(2)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        remaining = double.parse((remaining - apply).toStringAsFixed(2));
      }
    });
  }

  Future<List<StoreCreditRecord>> _listCreditRecords(
    StoreScope scope, {
    String? customerId,
  }) async {
    final rows = await _listCredits(scope, customerId: customerId);
    return rows.map(StoreCreditRecord.fromRow).toList(growable: false);
  }

  Future<List<StoreCreditRecord>> _listCreditRecordsByDate(
    StoreScope scope, {
    required StoreCreditDateFilter filter,
    String? customerId,
  }) async {
    final range = _resolveCreditDateFilterRange(filter);
    final rows = await _listCredits(
      scope,
      customerId: customerId,
      createdOnStart: range.start.toIso8601String(),
      createdOnEnd: range.end.toIso8601String(),
    );
    return rows.map(StoreCreditRecord.fromRow).toList(growable: false);
  }

  Future<List<StoreCustomerCreditSummary>> _listCustomerCreditSummaries(
    StoreScope scope, {
    String sortBy = StoreCreditCustomerSortBy.amount,
    bool descending = true,
  }) async {
    if (!StoreCreditCustomerSortBy.supported.contains(sortBy)) {
      throw ArgumentError.value(
        sortBy,
        'sortBy',
        'Unsupported customer credit sort field.',
      );
    }

    final credits = await _listCreditRecords(scope);
    final summariesByCustomer = <String, StoreCustomerCreditSummary>{};

    String? creditPendingAnchor(StoreCreditRecord credit) {
      if (credit.settled || credit.outstandingAmount <= 0.0001) return null;
      final due = credit.dueDate?.trim();
      if (due != null && due.isNotEmpty) return due;
      return credit.createdOn;
    }

    String? earlierAnchor(String? left, String? right) {
      if (left == null || left.isEmpty) return right;
      if (right == null || right.isEmpty) return left;
      return left.compareTo(right) <= 0 ? left : right;
    }

    for (final credit in credits) {
      final existing = summariesByCustomer[credit.customerId];
      final pendingAnchor = creditPendingAnchor(credit);
      if (existing == null) {
        summariesByCustomer[credit.customerId] = StoreCustomerCreditSummary(
          customerId: credit.customerId,
          customerName: credit.customerName,
          totalCreditAmount: credit.amount,
          totalPaidAmount: credit.paidAmount,
          totalOutstandingAmount: credit.outstandingAmount,
          creditCount: 1,
          latestCreditOn: credit.createdOn,
          oldestOutstandingOn: pendingAnchor,
        );
        continue;
      }

      final latestCreditOn =
          existing.latestCreditOn.compareTo(credit.createdOn) >= 0
          ? existing.latestCreditOn
          : credit.createdOn;
      summariesByCustomer[credit.customerId] = StoreCustomerCreditSummary(
        customerId: existing.customerId,
        customerName: existing.customerName.isNotEmpty
            ? existing.customerName
            : credit.customerName,
        totalCreditAmount: existing.totalCreditAmount + credit.amount,
        totalPaidAmount: existing.totalPaidAmount + credit.paidAmount,
        totalOutstandingAmount:
            existing.totalOutstandingAmount + credit.outstandingAmount,
        creditCount: existing.creditCount + 1,
        latestCreditOn: latestCreditOn,
        oldestOutstandingOn: earlierAnchor(
          existing.oldestOutstandingOn,
          pendingAnchor,
        ),
      );
    }

    final accountRows = await _db.rawQuery(
      '''
      SELECT
        a.customerId,
        a.total_credit_so_far,
        a.total_repaid,
        a.outstanding_balance,
        a.updated_on,
        COALESCE(
          NULLIF(MAX(cu.name), ''),
          NULLIF(MAX(cu2.name), ''),
          ''
        ) AS customer_name
      FROM credit_accounts a
      LEFT JOIN customers cu ON cu.customerId = a.customerId
      LEFT JOIN customers cu2 ON (
        (a.customerId LIKE 'user_%' AND cu2.customerId = SUBSTR(a.customerId, 6))
        OR (a.customerId NOT LIKE 'user_%' AND cu2.customerId = 'user_' || a.customerId)
      )
      WHERE a.orgId = ? AND a.storeId = ?
      GROUP BY a.customerId, a.total_credit_so_far, a.total_repaid, a.outstanding_balance, a.updated_on
      ''',
      [scope.orgId, scope.storeId],
    );

    for (final row in accountRows) {
      final customerId = '${row['customerId'] ?? ''}'.trim();
      if (customerId.isEmpty) continue;
      final existing = summariesByCustomer[customerId];
      final customerName = '${row['customer_name'] ?? ''}'.trim();
      if (existing == null) {
        summariesByCustomer[customerId] = StoreCustomerCreditSummary(
          customerId: customerId,
          customerName: customerName,
          totalCreditAmount:
              (row['total_credit_so_far'] as num?)?.toDouble() ?? 0,
          totalPaidAmount: (row['total_repaid'] as num?)?.toDouble() ?? 0,
          totalOutstandingAmount:
              (row['outstanding_balance'] as num?)?.toDouble() ?? 0,
          creditCount: 0,
          latestCreditOn: '${row['updated_on'] ?? ''}',
          oldestOutstandingOn: null,
        );
        continue;
      }
      if (existing.customerName.isEmpty && customerName.isNotEmpty) {
        summariesByCustomer[customerId] = StoreCustomerCreditSummary(
          customerId: existing.customerId,
          customerName: customerName,
          totalCreditAmount: existing.totalCreditAmount,
          totalPaidAmount: existing.totalPaidAmount,
          totalOutstandingAmount: existing.totalOutstandingAmount,
          creditCount: existing.creditCount,
          latestCreditOn: existing.latestCreditOn,
          oldestOutstandingOn: existing.oldestOutstandingOn,
        );
      }
    }

    final summaries = summariesByCustomer.values.toList(growable: false);

    final sorted = summaries.toList(growable: false)
      ..sort((left, right) {
        switch (sortBy) {
          case StoreCreditCustomerSortBy.name:
            final nameResult = left.customerName.toLowerCase().compareTo(
              right.customerName.toLowerCase(),
            );
            if (nameResult != 0) {
              return descending ? -nameResult : nameResult;
            }
            return right.totalOutstandingAmount.compareTo(
              left.totalOutstandingAmount,
            );
          case StoreCreditCustomerSortBy.pending:
            final leftAnchor = left.oldestOutstandingOn ?? '';
            final rightAnchor = right.oldestOutstandingOn ?? '';
            // Oldest unpaid first when descending=false for pending;
            // UI "Long pending" wants oldest first → ascending by date.
            final pendingResult = leftAnchor.compareTo(rightAnchor);
            if (pendingResult != 0) {
              return descending ? -pendingResult : pendingResult;
            }
            return right.totalOutstandingAmount.compareTo(
              left.totalOutstandingAmount,
            );
          case StoreCreditCustomerSortBy.amount:
          default:
            final amountResult = descending
                ? right.totalOutstandingAmount.compareTo(
                    left.totalOutstandingAmount,
                  )
                : left.totalOutstandingAmount.compareTo(
                    right.totalOutstandingAmount,
                  );
            if (amountResult != 0) {
              return amountResult;
            }
            return left.customerName.toLowerCase().compareTo(
              right.customerName.toLowerCase(),
            );
        }
      });

    return sorted;
  }

  _StoreCreditDateRange _resolveCreditDateFilterRange(
    StoreCreditDateFilter filter,
  ) {
    if (!StoreCreditDateFilterType.supported.contains(filter.type)) {
      throw ArgumentError.value(
        filter.type,
        'filter.type',
        'Unsupported credit date filter type.',
      );
    }

    final now = DateTime.now().toUtc();
    DateTime baseDate;
    switch (filter.type) {
      case StoreCreditDateFilterType.today:
        baseDate = now;
        break;
      case StoreCreditDateFilterType.yesterday:
        baseDate = now.subtract(const Duration(days: 1));
        break;
      case StoreCreditDateFilterType.custom:
        if (filter.date == null) {
          throw ArgumentError('Custom credit date filter requires a date.');
        }
        baseDate = filter.date!.toUtc();
        break;
      default:
        throw ArgumentError.value(
          filter.type,
          'filter.type',
          'Unsupported credit date filter type.',
        );
    }

    final start = DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
    return _StoreCreditDateRange(
      start: start,
      end: start.add(const Duration(days: 1)),
    );
  }

  Future<int> _countCreditExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM credits WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listCreditExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    final limitClause = limit == null ? '' : 'LIMIT $limit';
    final offsetClause = offset == null ? '' : 'OFFSET $offset';
    final rows = await _db.rawQuery(
      '''
      SELECT
        c.*,
        o.pricing_mode AS order_pricing_mode
      FROM credits c
      LEFT JOIN orders o
        ON o.order_id = c.order_id
       AND o.orgId = c.orgId
       AND o.storeId = c.storeId
      WHERE c.orgId = ? AND c.storeId = ?
      ORDER BY c.updated_on DESC, c.id DESC
      $limitClause $offsetClause
      ''',
      [scope.orgId, scope.storeId],
    );
    return rows.map(_creditRowToSyncJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _listCreditRepayments(
    StoreScope scope, {
    String? customerId,
    bool includeDeleted = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final whereClauses = <String>['orgId = ?', 'storeId = ?'];
    final whereArgs = <Object?>[scope.orgId, scope.storeId];
    if (customerId != null && customerId.isNotEmpty) {
      whereClauses.add('customerId = ?');
      whereArgs.add(customerId);
    }
    if (!includeDeleted) {
      whereClauses.add('deleted_on IS NULL');
    }
    return _db.rawQuery('''
      SELECT
        r.*,
        COALESCE(SUM(a.allocated_amount), 0) AS allocated_amount,
        MAX(r.total_amount - COALESCE(SUM(a.allocated_amount), 0), 0)
          AS advance_amount
      FROM credit_repayments r
      LEFT JOIN credit_repayment_allocations a ON a.repayment_id = r.id
      WHERE ${whereClauses.map((clause) => 'r.$clause').join(' AND ')}
      GROUP BY r.id
      ORDER BY r.paid_on DESC, r.id DESC
      ''', whereArgs);
  }

  Future<List<StoreCreditRepaymentRecord>> _listCreditRepaymentRecords(
    StoreScope scope, {
    String? customerId,
    bool includeDeleted = false,
  }) async {
    final rows = await _listCreditRepayments(
      scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );
    return rows.map(StoreCreditRepaymentRecord.fromRow).toList(growable: false);
  }

  Future<int> _countCreditRepaymentExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM credit_repayments WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listCreditRepaymentExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.query(
      'credit_repayments',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'paid_on DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_creditRepaymentRowToSyncJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _listCreditRepaymentAllocations(
    StoreScope scope,
    int repaymentId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    return _db.rawQuery(
      '''
      SELECT a.*
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      WHERE r.orgId = ? AND r.storeId = ? AND a.repayment_id = ?
      ORDER BY a.id ASC
      ''',
      [scope.orgId, scope.storeId, repaymentId],
    );
  }

  Future<List<StoreCreditRepaymentAllocationRecord>>
  _listCreditRepaymentAllocationRecords(
    StoreScope scope,
    int repaymentId,
  ) async {
    final rows = await _listCreditRepaymentAllocations(scope, repaymentId);
    return rows
        .map(StoreCreditRepaymentAllocationRecord.fromRow)
        .toList(growable: false);
  }

  Future<int> _countCreditRepaymentAllocationExportRows(
    StoreScope scope,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      WHERE r.orgId = ? AND r.storeId = ?
      ''',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listCreditRepaymentAllocationExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    return _db.rawQuery(
      '''
      SELECT
        a.*,
        r.orgId AS orgId,
        r.storeId AS storeId,
        r.local_id AS repayment_local_id,
        r.remote_id AS repayment_remote_id,
        c.local_id AS credit_local_id,
        c.remote_id AS credit_remote_id
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      INNER JOIN credits c ON c.id = a.credit_id
      WHERE r.orgId = ? AND r.storeId = ?
      ORDER BY a.id ASC
      LIMIT ? OFFSET ?
      ''',
      [scope.orgId, scope.storeId, limit ?? -1, offset ?? 0],
    );
  }

  Future<Map<String, dynamic>?> _getCreditById(
    StoreScope scope,
    int creditId,
  ) async {
    final rows = await _db.query(
      'credits',
      where: 'orgId = ? AND storeId = ? AND id = ?',
      whereArgs: [scope.orgId, scope.storeId, creditId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Map<String, dynamic> _creditRowToSyncJson(Map<String, dynamic> row) {
    final pricingMode = StoreOrderPricingMode.normalize(
      row['order_pricing_mode'] ?? row['pricing_mode'],
    );
    final accountType = pricingMode == StoreOrderPricingMode.buying
        ? 'supplier_payable'
        : 'customer_receivable';
    return {
      'orgId': row['orgId'],
      'storeId': row['storeId'],
      'local_id': row['local_id'],
      'remote_id': row['remote_id'],
      'customerId': row['customerId'],
      'order_id': row['order_id'],
      'amount': row['amount'],
      'due_date': row['due_date'],
      'created_on': row['created_on'],
      'updated_on': row['updated_on'],
      'account_type': accountType,
      'pricing_mode': pricingMode,
    };
  }

  Map<String, dynamic> _creditRepaymentRowToSyncJson(Map<String, dynamic> row) {
    return {
      'orgId': row['orgId'],
      'storeId': row['storeId'],
      'local_id': row['local_id'],
      'remote_id': row['remote_id'],
      'customerId': row['customerId'],
      'account_type': 'customer_receivable',
      'payment_mode': row['payment_mode'],
      'total_amount': row['total_amount'],
      'reference_id': row['reference_id'],
      'paid_on': row['paid_on'],
      'created_on': row['created_on'],
      'updated_on': row['updated_on'],
      'deleted_reason': row['deleted_reason'],
      'deleted_by_customer_id': row['deleted_by_customer_id'],
      'deleted_on': row['deleted_on'],
    };
  }

  Future<Map<String, dynamic>?> _findExistingCreditInstallmentBySyncIdentity(
    StoreScope scope, {
    int? remoteId,
    String? localId,
  }) async {
    if (remoteId != null) {
      final rows = await _db.query(
        'credit_installments',
        where: 'orgId = ? AND storeId = ? AND remote_id = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    if (localId != null && localId.isNotEmpty) {
      final rows = await _db.query(
        'credit_installments',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    return null;
  }

  Future<void> _refreshCreditInstallmentPaidAmounts(
    StoreScope scope,
    int creditId,
  ) async {
    final creditRows = await _db.query(
      'credits',
      where: 'id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [creditId, scope.orgId, scope.storeId],
      limit: 1,
    );
    if (creditRows.isEmpty) return;
    final creditAmount = (creditRows.first['amount'] as num?)?.toDouble() ?? 0;
    final allocRows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(a.allocated_amount), 0) AS paid
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      WHERE a.credit_id = ? AND r.deleted_on IS NULL
      ''',
      [creditId],
    );
    var remaining = (allocRows.first['paid'] as num?)?.toDouble() ?? 0;
    if (remaining > creditAmount) remaining = creditAmount;

    final installments = await _db.query(
      'credit_installments',
      where: 'credit_id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [creditId, scope.orgId, scope.storeId],
      orderBy: 'sequence ASC, id ASC',
    );
    final now = DateTime.now().toIso8601String();
    for (final row in installments) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final apply = remaining < amount ? remaining : amount;
      remaining -= apply;
      final status = apply >= amount - 0.0001
          ? 'paid'
          : (apply > 0.0001 ? 'partial' : 'open');
      await _db.update(
        'credit_installments',
        {'paid_amount': apply, 'status': status, 'updated_on': now},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<int> _countCreditInstallmentExportRows(StoreScope scope) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM credit_installments WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> _listCreditInstallmentExportRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    _validateScope(scope);
    await _requireRole('admin');
    final rows = await _db.query(
      'credit_installments',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'credit_id ASC, sequence ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map((row) {
          return {
            'orgId': row['orgId'],
            'storeId': row['storeId'],
            'local_id': row['local_id'],
            'remote_id': row['remote_id'],
            'credit_local_id': row['credit_local_id'],
            'credit_remote_id': null,
            'sequence': row['sequence'],
            'amount': row['amount'],
            'paid_amount': row['paid_amount'],
            'due_date': row['due_date'],
            'status': row['status'],
            'created_on': row['created_on'],
            'updated_on': row['updated_on'],
          };
        })
        .toList(growable: false);
  }

  Future<List<StoreCreditInstallmentRecord>> _listCreditInstallments(
    StoreScope scope, {
    int? creditId,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final where = <String>['orgId = ?', 'storeId = ?'];
    final args = <Object?>[scope.orgId, scope.storeId];
    if (creditId != null) {
      where.add('credit_id = ?');
      args.add(creditId);
    }
    final rows = await _db.query(
      'credit_installments',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'credit_id ASC, sequence ASC, id ASC',
    );
    return rows
        .map(StoreCreditInstallmentRecord.fromRow)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> _findExistingCreditBySyncIdentity(
    StoreScope scope, {
    int? remoteId,
    String? localId,
  }) async {
    if (remoteId != null) {
      final rows = await _db.query(
        'credits',
        where: 'orgId = ? AND storeId = ? AND remote_id = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    if (localId != null && localId.isNotEmpty) {
      final rows = await _db.query(
        'credits',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findExistingCreditAccountBySyncIdentity(
    StoreScope scope, {
    int? remoteId,
    String? localId,
    String? customerId,
  }) async {
    if (remoteId != null) {
      final rows = await _db.query(
        'credit_accounts',
        where: 'orgId = ? AND storeId = ? AND remote_id = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    if (localId != null && localId.isNotEmpty) {
      final rows = await _db.query(
        'credit_accounts',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    final customer = (customerId ?? '').trim();
    if (customer.isNotEmpty) {
      final rows = await _db.query(
        'credit_accounts',
        where: 'orgId = ? AND storeId = ? AND customerId = ?',
        whereArgs: [scope.orgId, scope.storeId, customer],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    return null;
  }

  Future<StoreCreditAccountRecord?> _getCreditAccountByCustomer(
    StoreScope scope,
    String customerId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final id = customerId.trim();
    if (id.isEmpty) return null;
    final rows = await _db.query(
      'credit_accounts',
      where: 'orgId = ? AND storeId = ? AND customerId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreCreditAccountRecord.fromRow(rows.first);
  }

  /// Store-wide credit defaults from the latest credits import, if any.
  Map<String, dynamic>? takeImportedCreditStoreSettings() {
    final value = _lastImportedCreditStoreSettings;
    _lastImportedCreditStoreSettings = null;
    return value;
  }

  Future<Map<String, dynamic>?> _findExistingCreditRepaymentBySyncIdentity(
    StoreScope scope, {
    int? remoteId,
    String? localId,
  }) async {
    if (remoteId != null) {
      final rows = await _db.query(
        'credit_repayments',
        where: 'orgId = ? AND storeId = ? AND remote_id = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    if (localId != null && localId.isNotEmpty) {
      final rows = await _db.query(
        'credit_repayments',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findExistingCreditRepaymentAllocation(
    int repaymentId,
    int creditId,
  ) async {
    final rows = await _db.query(
      'credit_repayment_allocations',
      where: 'repayment_id = ? AND credit_id = ?',
      whereArgs: [repaymentId, creditId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<double> _getAllocatedAmountForCredit(
    StoreScope scope,
    int creditId,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(a.allocated_amount), 0) AS total
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      WHERE r.orgId = ? AND r.storeId = ? AND a.credit_id = ? AND r.deleted_on IS NULL
      ''',
      [scope.orgId, scope.storeId, creditId],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, dynamic>?> _getCreditRepaymentById(
    StoreScope scope,
    int repaymentId,
  ) async {
    final rows = await _db.query(
      'credit_repayments',
      where: 'orgId = ? AND storeId = ? AND id = ?',
      whereArgs: [scope.orgId, scope.storeId, repaymentId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<double> _getCustomerAdvanceBalance(
    StoreScope scope,
    String customerId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final normalizedCustomerId = customerId.trim();
    if (normalizedCustomerId.isEmpty) return 0;
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        MAX(r.total_amount - COALESCE(a.allocated_amount, 0), 0)
      ), 0) AS advance_balance
      FROM credit_repayments r
      LEFT JOIN (
        SELECT repayment_id, SUM(allocated_amount) AS allocated_amount
        FROM credit_repayment_allocations
        GROUP BY repayment_id
      ) a ON a.repayment_id = r.id
      WHERE r.orgId = ? AND r.storeId = ? AND r.customerId = ?
        AND r.deleted_on IS NULL
      ''',
      [scope.orgId, scope.storeId, normalizedCustomerId],
    );
    return double.parse(
      ((rows.first['advance_balance'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
  }

  Future<int> _recordCustomerAdvance(
    StoreScope scope, {
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? paidOn,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final normalizedCustomerId = customerId.trim();
    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError.value(customerId, 'customerId', 'Required.');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero.');
    }
    final normalizedMode = paymentMode.trim().toLowerCase();
    if (!StoreCreditRepaymentMode.supported.contains(normalizedMode)) {
      throw ArgumentError.value(
        paymentMode,
        'paymentMode',
        'Unsupported advance payment mode.',
      );
    }
    final customer = await _customerRepo.getCustomerById(normalizedCustomerId);
    final storeRole = await _customerRepo.getStoreRole(
      orgId: scope.orgId,
      customerId: normalizedCustomerId,
      storeId: scope.storeId,
    );
    final isStoreOwned = customer?['storeId'] == scope.storeId;
    if (customer == null ||
        customer['orgId'] != scope.orgId ||
        (!isStoreOwned && storeRole == null)) {
      throw ArgumentError(
        'Customer $normalizedCustomerId was not found in this store.',
      );
    }
    final storedCustomerId =
        '${storeRole?['customerId'] ?? customer['customerId']}';
    final paidAt = paidOn ?? DateTime.now().toIso8601String();
    final allocations = await _buildFifoCreditAllocations(
      scope,
      customerId: storedCustomerId,
      amount: amount,
      allowRemainder: true,
    );
    final repaymentId = await _db.transaction((txn) async {
      final id = await txn.insert('credit_repayments', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'local_id': _newLocalSyncId('customer-advance'),
        'remote_id': null,
        'customerId': storedCustomerId,
        'payment_mode': normalizedMode,
        'total_amount': double.parse(amount.toStringAsFixed(2)),
        'reference_id': referenceId?.trim().isEmpty == true
            ? null
            : referenceId?.trim(),
        'paid_on': paidAt,
        'created_on': paidAt,
        'updated_on': paidAt,
      });
      for (final allocation in allocations) {
        await txn.insert('credit_repayment_allocations', {
          'repayment_id': id,
          'credit_id': allocation.creditId,
          'allocated_amount': allocation.allocatedAmount,
        });
      }
      return id;
    });
    for (final creditId in allocations.map((row) => row.creditId).toSet()) {
      await _refreshCreditInstallmentPaidAmounts(scope, creditId);
    }
    return repaymentId;
  }

  Future<int> _recordCreditRepayment(
    StoreScope scope,
    StoreCreateCreditRepaymentRequest request,
  ) async {
    _validateScope(scope);
    // Cashiers collect repayments; void/delete stays admin-only.
    await _requireRole('member');

    final paymentMode = request.paymentMode.trim().toLowerCase();
    if (!StoreCreditRepaymentMode.supported.contains(paymentMode)) {
      throw ArgumentError.value(
        request.paymentMode,
        'paymentMode',
        'Unsupported credit repayment mode.',
      );
    }
    if (request.customerId.isEmpty) {
      throw ArgumentError.value(
        request.customerId,
        'customerId',
        'customerId is required.',
      );
    }
    if (request.totalAmount <= 0) {
      throw ArgumentError.value(
        request.totalAmount,
        'totalAmount',
        'totalAmount must be greater than 0.',
      );
    }

    var allocations = request.allocations;
    if (allocations.isEmpty) {
      allocations = await _buildFifoCreditAllocations(
        scope,
        customerId: request.customerId,
        amount: request.totalAmount,
      );
    }
    if (allocations.isEmpty) {
      throw ArgumentError(
        'No open credit balance to allocate for customer ${request.customerId}.',
      );
    }

    final allocatedTotal = allocations.fold<double>(
      0,
      (sum, item) => sum + item.allocatedAmount,
    );
    if ((allocatedTotal - request.totalAmount).abs() > 0.0001) {
      throw ArgumentError('Allocated total must equal repayment total amount.');
    }

    final allocationTotalsByCredit = <int, double>{};
    for (final allocation in allocations) {
      if (allocation.allocatedAmount <= 0) {
        throw ArgumentError.value(
          allocation.allocatedAmount,
          'allocatedAmount',
          'Allocation amount must be greater than 0.',
        );
      }
      allocationTotalsByCredit.update(
        allocation.creditId,
        (value) => value + allocation.allocatedAmount,
        ifAbsent: () => allocation.allocatedAmount,
      );
    }

    for (final entry in allocationTotalsByCredit.entries) {
      final credit = await _getCreditById(scope, entry.key);
      if (credit == null) {
        throw ArgumentError('Credit ${entry.key} was not found.');
      }
      final creditCustomerId = credit['customerId'] as String? ?? '';
      if (creditCustomerId != request.customerId) {
        throw ArgumentError(
          'Credit ${entry.key} does not belong to customer ${request.customerId}.',
        );
      }
      final originalAmount = (credit['amount'] as num?)?.toDouble() ?? 0;
      final allocatedSoFar = await _getAllocatedAmountForCredit(
        scope,
        entry.key,
      );
      final outstanding = originalAmount - allocatedSoFar;
      if (entry.value - outstanding > 0.0001) {
        throw ArgumentError(
          'Allocation for credit ${entry.key} exceeds outstanding amount $outstanding.',
        );
      }
    }

    final createdOn = request.createdOn ?? request.paidOn;
    final updatedOn = request.updatedOn ?? createdOn;
    final allocatedCreditIds = allocations.map((a) => a.creditId).toSet();

    final repaymentId = await _db.transaction((txn) async {
      final repaymentId = await txn.insert('credit_repayments', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'local_id': request.localId ?? _newLocalSyncId('credit-repayment'),
        'remote_id': request.remoteId,
        'customerId': request.customerId,
        'payment_mode': paymentMode,
        'total_amount': request.totalAmount,
        'reference_id': request.referenceId,
        'paid_on': request.paidOn,
        'created_on': createdOn,
        'updated_on': updatedOn,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final allocation in allocations) {
        await txn.insert(
          'credit_repayment_allocations',
          {
            'repayment_id': repaymentId,
            'credit_id': allocation.creditId,
            'allocated_amount': allocation.allocatedAmount,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return repaymentId;
    });
    for (final creditId in allocatedCreditIds) {
      await _refreshCreditInstallmentPaidAmounts(scope, creditId);
    }
    return repaymentId;
  }

  Future<List<StoreCreateCreditRepaymentAllocationRequest>>
  _buildFifoCreditAllocations(
    StoreScope scope, {
    required String customerId,
    required double amount,
    int? preferCreditId,
    bool allowRemainder = false,
  }) async {
    if (amount <= 0) {
      return const [];
    }
    final openCredits = await _listCreditRecords(scope, customerId: customerId);
    final open = openCredits
        .where((credit) => !credit.settled && credit.outstandingAmount > 0.0001)
        .toList(growable: true);
    open.sort((a, b) {
      if (preferCreditId != null) {
        if (a.id == preferCreditId && b.id != preferCreditId) return -1;
        if (b.id == preferCreditId && a.id != preferCreditId) return 1;
      }
      final byDate = a.createdOn.compareTo(b.createdOn);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });

    var remaining = amount;
    final allocations = <StoreCreateCreditRepaymentAllocationRequest>[];
    for (final credit in open) {
      if (remaining <= 0.0001) break;
      final apply = remaining < credit.outstandingAmount
          ? remaining
          : credit.outstandingAmount;
      if (apply <= 0.0001) continue;
      allocations.add(
        StoreCreateCreditRepaymentAllocationRequest(
          creditId: credit.id,
          allocatedAmount: double.parse(apply.toStringAsFixed(2)),
        ),
      );
      remaining = double.parse((remaining - apply).toStringAsFixed(2));
    }
    if (remaining > 0.0001 && !allowRemainder) {
      throw ArgumentError(
        'Payment exceeds outstanding balance by ${remaining.toStringAsFixed(2)}.',
      );
    }
    return allocations;
  }

  Future<int> _recordCreditRepaymentFifo(
    StoreScope scope, {
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? paidOn,
    int? preferCreditId,
  }) async {
    final paidAt = paidOn ?? DateTime.now().toIso8601String();
    final allocations = await _buildFifoCreditAllocations(
      scope,
      customerId: customerId,
      amount: amount,
      preferCreditId: preferCreditId,
    );
    return _recordCreditRepayment(
      scope,
      StoreCreateCreditRepaymentRequest(
        customerId: customerId,
        paymentMode: paymentMode,
        totalAmount: amount,
        paidOn: paidAt,
        referenceId: referenceId,
        allocations: allocations,
      ),
    );
  }

  Future<int> _deleteCreditRepayment(
    StoreScope scope,
    int repaymentId,
    StoreDeleteCreditRepaymentRequest request,
  ) async {
    _validateScope(scope);
    await _requireRole('admin');

    final deletedByCustomerId = request.deletedByCustomerId.trim();
    final reason = request.reason.trim();
    if (deletedByCustomerId.isEmpty) {
      throw ArgumentError.value(
        request.deletedByCustomerId,
        'deletedByCustomerId',
        'deletedByCustomerId is required.',
      );
    }
    if (reason.isEmpty) {
      throw ArgumentError.value(
        request.reason,
        'reason',
        'reason is required.',
      );
    }

    final deletedByCustomer = await _customerRepo.getCustomerById(
      deletedByCustomerId,
    );
    if (deletedByCustomer == null) {
      throw ArgumentError('Customer $deletedByCustomerId was not found.');
    }
    final deletedByOrgId = deletedByCustomer['orgId'] as String? ?? '';
    if (deletedByOrgId != scope.orgId) {
      throw ArgumentError(
        'Customer $deletedByCustomerId does not belong to organisation ${scope.orgId}.',
      );
    }

    final repayment = await _getCreditRepaymentById(scope, repaymentId);
    if (repayment == null) {
      throw StoreCreditRepaymentStateException(
        'Repayment $repaymentId was not found.',
      );
    }
    if ((repayment['deleted_on'] as String?) != null) {
      throw StoreCreditRepaymentStateException(
        'Repayment $repaymentId is already deleted.',
      );
    }

    final deletedOn = request.deletedOn ?? DateTime.now().toIso8601String();
    final allocationRows = await _listCreditRepaymentAllocations(
      scope,
      repaymentId,
    );
    final creditIds = allocationRows
        .map((row) => (row['credit_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final updated = await _db.update(
      'credit_repayments',
      {
        'deleted_reason': reason,
        'deleted_by_customer_id': deletedByCustomerId,
        'deleted_on': deletedOn,
        'updated_on': deletedOn,
      },
      where: 'orgId = ? AND storeId = ? AND id = ? AND deleted_on IS NULL',
      whereArgs: [scope.orgId, scope.storeId, repaymentId],
    );
    for (final creditId in creditIds) {
      await _refreshCreditInstallmentPaidAmounts(scope, creditId);
    }
    return updated;
  }

  Future<List<StoreScheduledCreditRepayment>> _listScheduledCreditRepayments(
    StoreScope scope, {
    String? customerId,
    bool includeClosed = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final where = StringBuffer('orgId = ? AND storeId = ?');
    final args = <Object?>[scope.orgId, scope.storeId];
    if (customerId != null && customerId.isNotEmpty) {
      where.write(' AND customerId = ?');
      args.add(customerId);
    }
    if (!includeClosed) {
      where.write(' AND status = ?');
      args.add(StoreScheduledCreditRepaymentStatus.scheduled);
    }
    final rows = await _db.query(
      'credit_scheduled_repayments',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'due_date ASC, id ASC',
    );
    return rows
        .map(StoreScheduledCreditRepayment.fromRow)
        .toList(growable: false);
  }

  Future<int> _createScheduledCreditRepayment(
    StoreScope scope,
    StoreCreateScheduledCreditRepaymentRequest request,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final customerId = request.customerId.trim();
    if (customerId.isEmpty) {
      throw ArgumentError.value(
        request.customerId,
        'customerId',
        'customerId is required.',
      );
    }
    if (request.amount <= 0) {
      throw ArgumentError.value(
        request.amount,
        'amount',
        'Amount must be greater than zero.',
      );
    }
    final dueDate = request.dueDate.trim();
    if (dueDate.isEmpty || DateTime.tryParse(dueDate) == null) {
      throw ArgumentError.value(
        request.dueDate,
        'dueDate',
        'dueDate must be a valid YYYY-MM-DD date.',
      );
    }
    final now = request.createdOn ?? DateTime.now().toIso8601String();
    final localId = request.localId ?? _newLocalSyncId('credit-schedule');
    return _db.insert('credit_scheduled_repayments', {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'local_id': localId,
      'customerId': customerId,
      'amount': double.parse(request.amount.toStringAsFixed(2)),
      'due_date': dueDate.length >= 10 ? dueDate.substring(0, 10) : dueDate,
      'status': StoreScheduledCreditRepaymentStatus.scheduled,
      'collected_repayment_id': null,
      'created_on': now,
      'updated_on': now,
    });
  }

  Future<int> _cancelScheduledCreditRepayment(
    StoreScope scope,
    int scheduleId,
  ) async {
    _validateScope(scope);
    await _requireRole('member');
    final now = DateTime.now().toIso8601String();
    return _db.update(
      'credit_scheduled_repayments',
      {
        'status': StoreScheduledCreditRepaymentStatus.cancelled,
        'updated_on': now,
      },
      where: 'orgId = ? AND storeId = ? AND id = ? AND status = ?',
      whereArgs: [
        scope.orgId,
        scope.storeId,
        scheduleId,
        StoreScheduledCreditRepaymentStatus.scheduled,
      ],
    );
  }

  Future<int> _collectScheduledCreditRepayment(
    StoreScope scope, {
    required int scheduleId,
    required String paymentMode,
    String? referenceId,
    String? paidOn,
    double? amountOverride,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    final rows = await _db.query(
      'credit_scheduled_repayments',
      where: 'orgId = ? AND storeId = ? AND id = ?',
      whereArgs: [scope.orgId, scope.storeId, scheduleId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Scheduled repayment $scheduleId was not found.');
    }
    final schedule = StoreScheduledCreditRepayment.fromRow(rows.first);
    if (!schedule.isOpen) {
      throw StateError('Scheduled repayment $scheduleId is not open.');
    }
    final collectAmount = amountOverride != null && amountOverride > 0
        ? double.parse(amountOverride.toStringAsFixed(2))
        : schedule.amount;
    final repaymentId = await _recordCreditRepaymentFifo(
      scope,
      customerId: schedule.customerId,
      amount: collectAmount,
      paymentMode: paymentMode,
      referenceId: referenceId,
      paidOn: paidOn,
    );
    final now = DateTime.now().toIso8601String();
    await _db.update(
      'credit_scheduled_repayments',
      {
        'status': StoreScheduledCreditRepaymentStatus.collected,
        'collected_repayment_id': repaymentId,
        'updated_on': now,
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
    return repaymentId;
  }

  String _newLocalSyncId(String prefix) => '$prefix-${_uuid.v4()}';

  Future<List<StoreCustomerLedgerEntry>> _listCustomerLedgerEntries(
    StoreScope scope, {
    required String customerId,
    bool includeDeleted = false,
  }) async {
    _validateScope(scope);
    await _requireRole('member');
    if (customerId.isEmpty) {
      throw ArgumentError.value(
        customerId,
        'customerId',
        'customerId is required.',
      );
    }

    final credits = await _listCreditRecords(scope, customerId: customerId);
    final repayments = await _listCreditRepaymentRecords(
      scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );

    final entries = <StoreCustomerLedgerEntry>[
      ...credits.map(StoreCustomerLedgerEntry.credit),
    ];

    for (final repayment in repayments) {
      final allocations = await _listCreditRepaymentAllocationRecords(
        scope,
        repayment.id,
      );
      entries.add(
        StoreCustomerLedgerEntry.repayment(repayment, allocations: allocations),
      );
    }

    entries.sort((left, right) {
      final timeCompare = right.timestamp.compareTo(left.timestamp);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return right.entryId.compareTo(left.entryId);
    });
    return entries;
  }

  Future<Store> switchAccessibleStore({
    required StoreOrganisationLoginResult login,
    required String storeId,
    StoreDeviceRegistrationRequest? deviceRegistration,
    String? orderJson,
    String? productJson,
    String? customerJson,
  }) async {
    if (login.organisation.orgId != orgId) {
      throw ArgumentError.value(
        login.organisation.orgId,
        'login',
        'Switching stores requires a login result for the same organisation.',
      );
    }
    if (storeId == this.storeId) {
      // Same branch after org login / staff logout: restore session on the
      // already-open DB instead of returning a store with no login session.
      await _rebindOrganisationLogin(login);
      return this;
    }

    final dbRoot = await _resolveCurrentDatabaseRootPath();
    if (dbRoot == null) {
      throw StateError(
        'Switching stores requires a persistent organisation database. In-memory stores are not supported.',
      );
    }

    final resumeAutoSync = sync.isAutoSyncRunning;
    sync.stopAutoSync();
    try {
      final nextStore = await Store.openAccessibleStore(
        login: login,
        storeId: storeId,
        deviceRegistration: deviceRegistration,
        orderJson: orderJson,
        productJson: productJson,
        customerJson: customerJson,
        databasePath: dbRoot,
        sessionDuration: _sessionDuration,
        config: _config,
      );
      // Organisation DB is shared across branches. Closing the previous Store
      // handle after openAccessibleStore would close the new store's connection
      // under sqflite single-instance. Drop the old handle without close().
      sync.stopAutoSync();
      if (resumeAutoSync) {
        nextStore.sync.startAutoSync(nextStore.scope);
      }
      return nextStore;
    } catch (error) {
      if (resumeAutoSync) {
        sync.startAutoSync(scope);
      }
      rethrow;
    }
  }

  /// Persist the signed-in operator + session onto this open store DB.
  Future<void> _rebindOrganisationLogin(
    StoreOrganisationLoginResult login,
  ) async {
    StoreAccessibleStore? accessibleStore;
    for (final entry in login.accessibleStores) {
      if (entry.store.storeId == storeId) {
        accessibleStore = entry;
        break;
      }
    }
    if (accessibleStore == null) {
      throw StoreAuthorizationException(
        'Customer does not have access to storeId=$storeId.',
      );
    }

    await _ensureLoggedInCustomerPersisted(_db, login: login, storeId: storeId);
    for (final entry in login.accessibleStores.where(
      (entry) => entry.access.orgId == orgId,
    )) {
      await _saveStoreRoleAccess(_db, entry.access);
    }

    final session = StoreSession(
      customerId: login.customerId,
      email: login.email,
      loginAt: DateTime.now().toIso8601String(),
      organisationRole: login.organisationRole,
      storeRole: accessibleStore.access.storeRole,
    );
    await _saveSession(_db, session);
    _sessionCache = session;
    _sessionCacheAt = DateTime.now();
    _localAccessCheckedAt = null;
    await _ensureLocalAccessAllowed(clearSessionOnFailure: true);
  }

  Future<String?> _resolveCurrentDatabaseRootPath() async {
    final rows = await _db.rawQuery('PRAGMA database_list');
    for (final row in rows) {
      final filePath = row['file'] as String?;
      if (filePath != null && filePath.isNotEmpty) {
        return p.dirname(filePath);
      }
    }
    return null;
  }

  Future<void> close() async {
    sync.stopAutoSync();
    await _db.close();
  }
}

class _StoreCreditDateRange {
  final DateTime start;
  final DateTime end;

  const _StoreCreditDateRange({required this.start, required this.end});
}
