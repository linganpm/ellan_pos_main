import 'dart:convert';
import 'sqflite_ffi_io.dart';
import 'package:crypto/crypto.dart';

import 'dart:io';
import 'backend_setup.dart';
import 'store_models.dart';

class CustomerRepository {
  final Database db;
  CustomerRepository(this.db);

  static const List<String> directoryCustomerRoles = [
    'retail_customer',
    'business_customer',
  ];

  static const List<String> directorySupplierRoles = [
    'supplier',
  ];

  static const List<String> directoryPartyRoles = [
    ...directoryCustomerRoles,
    ...directorySupplierRoles,
  ];

  /// Common customer reference is the backend user id: ``user_{id}``.
  static bool isUserCustomerId(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return false;
    if (raw.startsWith('user_')) {
      return int.tryParse(raw.substring(5)) != null;
    }
    return int.tryParse(raw) != null;
  }

  /// Prefix for customers captured offline before the gateway assigned a
  /// backend user id. Replaced by ``user_{id}`` after customer export.
  static const String provisionalCustomerIdPrefix = 'local_cust_';

  static bool isProvisionalCustomerId(String? value) =>
      (value ?? '').trim().startsWith(provisionalCustomerIdPrefix);

  static String normalizeUserCustomerId(String value) {
    final raw = value.trim();
    if (raw.startsWith('user_')) return raw;
    final asInt = int.tryParse(raw);
    if (asInt != null) return 'user_$asInt';
    return raw;
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Default offline bootstrap password hash (`pos123`) — must not overwrite a
  /// verified operator hash on catalogue sync.
  static String get defaultOfflinePasswordHash => hashPassword('pos123');

  /// Keep a verified local password when sync sends an empty / default hash.
  static Future<String> resolveImportedPassword({
    required Database db,
    required String customerId,
    required String incomingPassword,
  }) async {
    final incoming = incomingPassword.trim();
    if (customerId.isEmpty) return incoming;
    final existing = await db.query(
      'customers',
      columns: ['password'],
      where: 'customerId = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (existing.isEmpty) return incoming;
    final existingPw = '${existing.first['password'] ?? ''}'.trim();
    if (existingPw.isEmpty) return incoming;
    if (incoming.isEmpty) return existingPw;
    if (incoming == defaultOfflinePasswordHash &&
        existingPw != defaultOfflinePasswordHash) {
      return existingPw;
    }
    return incoming;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String _normalizeEmail(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// Finds a directory customer for this store by phone or email.
  /// Identity is the backend user id (``user_{id}``).
  Future<Map<String, dynamic>?> findDirectoryCustomer({
    required StoreScope scope,
    String? phone,
    String? email,
  }) async {
    final normalizedPhone = _digitsOnly(phone ?? '');
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedPhone.isEmpty && normalizedEmail.isEmpty) {
      return null;
    }

    final placeholders =
        List.filled(directoryCustomerRoles.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT c.*, sr.role AS role
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.customerId = c.customerId
       AND sr.orgId = c.orgId
       AND sr.storeId = ?
       AND sr.access_enabled = 1
       AND sr.role IN ($placeholders)
      WHERE c.orgId = ?
      ''',
      [scope.storeId, ...directoryCustomerRoles, scope.orgId],
    );

    for (final row in rows) {
      final rowPhone = _digitsOnly(row['phone'] as String? ?? '');
      final rowEmail = _normalizeEmail(row['email'] as String?);
      if (normalizedPhone.isNotEmpty &&
          rowPhone.isNotEmpty &&
          rowPhone == normalizedPhone) {
        return row;
      }
      if (normalizedEmail.isNotEmpty &&
          rowEmail.isNotEmpty &&
          rowEmail == normalizedEmail) {
        return row;
      }
    }
    return null;
  }

  /// Records a Retail/Business customer using the backend user id as
  /// ``customerId`` (``user_{id}``). Never invents a local PK / UUID.
  Future<String> upsertDirectoryCustomer({
    required StoreScope scope,
    required String name,
    required String phone,
    String? email,
    String? uniqueId,
    String role = 'retail_customer',
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email?.trim() ?? '';

    final existing = await findDirectoryCustomer(
      scope: scope,
      phone: trimmedPhone,
      email: trimmedEmail,
    );
    if (existing != null) {
      final id = existing['customerId'] as String;
      final updates = <String, dynamic>{};
      if (trimmedName.isNotEmpty &&
          trimmedName != (existing['name'] as String? ?? '')) {
        updates['name'] = trimmedName;
      }
      if (trimmedPhone.isNotEmpty &&
          trimmedPhone != (existing['phone'] as String? ?? '')) {
        updates['phone'] = trimmedPhone;
      }
      if (trimmedEmail.isNotEmpty &&
          trimmedEmail != (existing['email'] as String? ?? '')) {
        updates['email'] = trimmedEmail;
      }
      // If caller supplied the real user id, prefer it as the common reference.
      if (uniqueId != null &&
          isUserCustomerId(uniqueId) &&
          normalizeUserCustomerId(uniqueId) != id) {
        // Remap is handled by insert/replace with the authoritative user id below.
      } else if (updates.isNotEmpty) {
        await db.update(
          'customers',
          updates,
          where: 'customerId = ?',
          whereArgs: [id],
        );
        await _ensureStoreRole(scope, id, role);
        return id;
      } else {
        await _ensureStoreRole(scope, id, role);
        return id;
      }
    }

    if (uniqueId == null || !isUserCustomerId(uniqueId)) {
      throw StateError(
        'Customer must be created with a backend user id (user_{id}).',
      );
    }
    final customerId = normalizeUserCustomerId(uniqueId);

    // Drop any legacy non-user-id row for the same phone so we keep one identity.
    if (existing != null) {
      final oldId = existing['customerId'] as String?;
      if (oldId != null && oldId != customerId) {
        await db.delete(
          'store_roles',
          where: 'orgId = ? AND customerId = ?',
          whereArgs: [scope.orgId, oldId],
        );
        await db.delete(
          'customers',
          where: 'customerId = ?',
          whereArgs: [oldId],
        );
        await _remapCustomerReferences(
          scope: scope,
          oldId: oldId,
          newId: customerId,
        );
      }
    }

    await db.insert(
      'customers',
      {
        'customerId': customerId,
        'remote_id': customerId,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'name': trimmedName,
        'email': trimmedEmail,
        'phone': trimmedPhone,
        'country': '',
        'status': 'active',
        'role': role,
        'password': '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _ensureStoreRole(scope, customerId, role);
    return customerId;
  }

  /// Records a customer while offline under a provisional id. Reuses an
  /// existing directory customer with the same phone/email when present.
  Future<String> upsertOfflineDirectoryCustomer({
    required StoreScope scope,
    required String name,
    required String phone,
    String? email,
    String role = 'retail_customer',
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email?.trim() ?? '';
    final existing = await findDirectoryCustomer(
      scope: scope,
      phone: trimmedPhone,
      email: trimmedEmail,
    );
    if (existing != null) {
      final id = existing['customerId'] as String;
      await _ensureStoreRole(scope, id, role);
      return id;
    }
    final customerId =
        '$provisionalCustomerIdPrefix${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('customers', {
      'customerId': customerId,
      'remote_id': null,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'name': trimmedName,
      'email': trimmedEmail,
      'phone': trimmedPhone,
      'country': '',
      'status': 'active',
      'role': role,
      'password': '',
    });
    await _ensureStoreRole(scope, customerId, role);
    return customerId;
  }

  /// Replaces a provisional customer id with the backend ``user_{id}`` and
  /// moves orders, payments and credit rows onto it. Returns true on change.
  Future<bool> adoptBackendCustomerId({
    required StoreScope scope,
    required String localId,
    required String backendId,
  }) async {
    final oldId = localId.trim();
    if (!isProvisionalCustomerId(oldId) || !isUserCustomerId(backendId)) {
      return false;
    }
    final newId = normalizeUserCustomerId(backendId);
    final oldRows = await db.query(
      'customers',
      where: 'customerId = ?',
      whereArgs: [oldId],
      limit: 1,
    );
    if (oldRows.isEmpty) return false;
    await db.transaction((txn) async {
      final target = await txn.query(
        'customers',
        where: 'customerId = ?',
        whereArgs: [newId],
        limit: 1,
      );
      if (target.isEmpty) {
        await txn.update(
          'customers',
          {'customerId': newId, 'remote_id': newId},
          where: 'customerId = ?',
          whereArgs: [oldId],
        );
      } else {
        await txn.delete(
          'customers',
          where: 'customerId = ?',
          whereArgs: [oldId],
        );
      }
      final roles = await txn.query(
        'store_roles',
        where: 'orgId = ? AND customerId = ?',
        whereArgs: [scope.orgId, oldId],
      );
      await txn.delete(
        'store_roles',
        where: 'orgId = ? AND customerId = ?',
        whereArgs: [scope.orgId, oldId],
      );
      for (final role in roles) {
        await txn.insert('store_roles', {
          ...role,
          'remote_id':
              '${role['orgId']}:${role['storeId']}:$newId:${role['role']}',
          'customerId': newId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await _remapCustomerReferences(scope: scope, oldId: oldId, newId: newId);
    return true;
  }

  Future<void> _ensureStoreRole(
    StoreScope scope,
    String customerId,
    String role,
  ) async {
    await db.insert(
      'store_roles',
      {
        'remote_id': '${scope.orgId}:${scope.storeId}:$customerId:$role',
        'customerId': customerId,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'role': role,
        'access_enabled': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// When a backend customer arrives, replace any local non-user-id row for the
  /// same phone/email so orders keep the common ``user_{id}`` reference.
  Future<void> _replaceLocalNonUserIdByPhone({
    required StoreScope scope,
    required Map<String, dynamic> backendRow,
  }) async {
    final backendId = backendRow['customerId']?.toString() ?? '';
    if (!isUserCustomerId(backendId)) return;
    final canonical = normalizeUserCustomerId(backendId);
    final local = await findDirectoryCustomer(
      scope: scope,
      phone: backendRow['phone']?.toString(),
      email: backendRow['email']?.toString(),
    );
    if (local == null) return;
    final localId = local['customerId'] as String?;
    if (localId == null || localId == canonical) return;
    if (isUserCustomerId(localId)) return;

    await db.delete(
      'store_roles',
      where: 'orgId = ? AND customerId = ?',
      whereArgs: [scope.orgId, localId],
    );
    await db.delete(
      'customers',
      where: 'customerId = ?',
      whereArgs: [localId],
    );
    await _remapCustomerReferences(
      scope: scope,
      oldId: localId,
      newId: canonical,
    );
  }

  /// Moves every row that points at [oldId] over to [newId] so orders, credit
  /// ledger and credit payments stay attached to the same customer.
  Future<void> _remapCustomerReferences({
    required StoreScope scope,
    required String oldId,
    required String newId,
  }) async {
    if (oldId == newId) return;
    await db.update(
      'orders',
      {'customer_unique_id': newId},
      where: 'orgId = ? AND storeId = ? AND customer_unique_id = ?',
      whereArgs: [scope.orgId, scope.storeId, oldId],
    );
    for (final table in const ['order_payments', 'credits',
        'credit_repayments', 'credit_scheduled_repayments']) {
      await db.update(
        table,
        {'customerId': newId},
        where: 'orgId = ? AND storeId = ? AND customerId = ?',
        whereArgs: [scope.orgId, scope.storeId, oldId],
      );
    }
    // One credit account per customer: keep the existing one if present.
    await db.update(
      'credit_accounts',
      {'customerId': newId},
      where: 'orgId = ? AND storeId = ? AND customerId = ?',
      whereArgs: [scope.orgId, scope.storeId, oldId],
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.delete(
      'credit_accounts',
      where: 'orgId = ? AND storeId = ? AND customerId = ?',
      whereArgs: [scope.orgId, scope.storeId, oldId],
    );
  }

  static Future<CustomerRepository> createInMemory() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: BackendSetup.schemaVersion,
        onCreate: (db, version) async {
          await BackendSetup.createTablesForTest(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await BackendSetup.upgradeTablesForTest(db, oldVersion, newVersion);
        },
      ),
    );
    return CustomerRepository(db);
  }

  Future<void> importCustomersFromJsonFile(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);
    await importCustomersFromJsonData(data as Map<String, dynamic>);
  }

  Future<void> importCustomersFromJsonData(Map<String, dynamic> data) async {
    final customers = data['data'] as List<dynamic>;
    // Maps legacy local ids → backend user_{id} when we remapped by phone.
    final idRemap = <String, String>{};

    for (final customer in customers) {
      final customerRow = Map<String, dynamic>.from(customer as Map);
      final rawPassword = customerRow['password'] as String? ?? '';
      final normalizedPassword = rawPassword.isEmpty || rawPassword.length == 64
          ? rawPassword
          : hashPassword(rawPassword);
      final orgId = customerRow['orgId']?.toString() ?? '';
      final storeId = customerRow['storeId']?.toString() ?? '';
      final backendCustomerId = customerRow['customerId']?.toString() ?? '';
      final canonicalId = isUserCustomerId(backendCustomerId)
          ? normalizeUserCustomerId(backendCustomerId)
          : backendCustomerId;

      if (orgId.isNotEmpty && storeId.isNotEmpty) {
        final before = await findDirectoryCustomer(
          scope: StoreScope(orgId: orgId, storeId: storeId),
          phone: customerRow['phone']?.toString(),
          email: customerRow['email']?.toString(),
        );
        await _replaceLocalNonUserIdByPhone(
          scope: StoreScope(orgId: orgId, storeId: storeId),
          backendRow: {
            ...customerRow,
            'customerId': canonicalId,
          },
        );
        if (before != null) {
          final oldId = before['customerId']?.toString();
          if (oldId != null &&
              oldId != canonicalId &&
              !isUserCustomerId(oldId)) {
            idRemap[oldId] = canonicalId;
          }
        }
      }

      final insertRow = <String, dynamic>{
        'customerId': canonicalId,
        'remote_id': customerRow['remote_id'] ?? canonicalId,
        'orgId': orgId,
        'storeId': storeId,
        'name': customerRow['name'],
        'email': customerRow['email'],
        'phone': customerRow['phone'],
        'country': customerRow['country'],
        'status': customerRow['status'],
        'role': customerRow['role'],
        'password': await resolveImportedPassword(
          db: db,
          customerId: canonicalId,
          incomingPassword: normalizedPassword,
        ),
        'usr_reg_num':
            '${customerRow['usr_reg_num'] ?? customerRow['reg_num'] ?? ''}',
      };
      await db.insert(
        'customers',
        insertRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final storeRoles = data['store_roles'] as List<dynamic>?;
    if (storeRoles != null) {
      for (final roleEntry in storeRoles) {
        final roleRow = Map<String, dynamic>.from(roleEntry as Map);
        final accessValue = roleRow['access_enabled'];
        final accessEnabled = accessValue is bool
            ? accessValue
            : ((accessValue as num?)?.toInt() ?? 1) == 1;
        final backendCustomerId = roleRow['customerId']?.toString() ?? '';
        final localCustomerId = idRemap[backendCustomerId] ??
            (isUserCustomerId(backendCustomerId)
                ? normalizeUserCustomerId(backendCustomerId)
                : backendCustomerId);
        await db.insert(
          'store_roles',
          {
            'remote_id': roleRow['remote_id'] ??
                '${roleRow['orgId']}:${roleRow['storeId']}:$localCustomerId:${roleRow['role'] ?? 'guest'}',
            'customerId': localCustomerId,
            'orgId': roleRow['orgId'],
            'storeId': roleRow['storeId'],
            'role': roleRow['role'] ?? 'guest',
            'access_enabled': accessEnabled ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> listCustomers({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
    List<String>? roles,
  }) async {
    final roleFilter = roles ?? const <String>[];
    if (roleFilter.isEmpty) {
      return db.query(
        'customers',
        where: 'orgId = ? AND storeId = ?',
        whereArgs: [scope.orgId, scope.storeId],
        limit: limit,
        offset: offset,
        orderBy: 'name ASC',
      );
    }

    final placeholders = List.filled(roleFilter.length, '?').join(', ');
    return db.rawQuery(
      '''
      SELECT DISTINCT c.*, sr.role AS role
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.customerId = c.customerId
       AND sr.orgId = c.orgId
       AND sr.storeId = ?
       AND sr.access_enabled = 1
       AND sr.role IN ($placeholders)
      WHERE c.orgId = ?
      ORDER BY c.name ASC
      LIMIT ? OFFSET ?
      ''',
      [scope.storeId, ...roleFilter, scope.orgId, limit, offset],
    );
  }

  /// Retail / Business Customers for the open store (not POS operators).
  Future<List<Map<String, dynamic>>> listDirectoryCustomers({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) {
    return listCustomers(
      scope: scope,
      limit: limit,
      offset: offset,
      roles: directoryCustomerRoles,
    );
  }

  /// POS operators with enabled access on this store (staff unlock).
  ///
  /// Uses ``store_roles`` for the branch — not org-wide customers, and not
  /// retail/business directory customers.
  Future<List<Map<String, dynamic>>> listStoreOperators({
    required StoreScope scope,
    int limit = 500,
    int offset = 0,
  }) async {
    final placeholders =
        List.filled(directoryCustomerRoles.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT c.*, sr.role AS role
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.orgId = c.orgId
       AND sr.storeId = ?
       AND COALESCE(sr.access_enabled, 1) = 1
       AND LOWER(COALESCE(sr.role, '')) NOT IN ($placeholders)
       AND (
         sr.customerId = c.customerId
         OR sr.customerId = REPLACE(c.customerId, 'user_', '')
         OR ('user_' || sr.customerId) = c.customerId
       )
      WHERE c.orgId = ?
      ORDER BY c.name COLLATE NOCASE ASC
      LIMIT ? OFFSET ?
      ''',
      [
        scope.storeId,
        ...directoryCustomerRoles,
        scope.orgId,
        limit,
        offset,
      ],
    );
    if (rows.isNotEmpty) return rows;

    // Fallback when store_roles were not imported yet: operators whose
    // customer.storeId matches this branch (exclude directory customers).
    return db.rawQuery(
      '''
      SELECT c.*
      FROM customers c
      WHERE c.orgId = ?
        AND c.storeId = ?
        AND LOWER(COALESCE(c.role, '')) NOT IN ($placeholders)
      ORDER BY c.name COLLATE NOCASE ASC
      LIMIT ? OFFSET ?
      ''',
      [
        scope.orgId,
        scope.storeId,
        ...directoryCustomerRoles,
        limit,
        offset,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> listOrganisationCustomers({
    required String orgId,
    int limit = 20,
    int offset = 0,
  }) {
    return db.query(
      'customers',
      where: 'orgId = ?',
      whereArgs: [orgId],
      limit: limit,
      offset: offset,
      orderBy: 'name ASC',
    );
  }

  Future<int> createCustomer(Map<String, dynamic> row) {
    return db.insert(
      'customers',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCustomer(String customerId, Map<String, dynamic> updates) {
    return db.update(
      'customers',
      updates,
      where: 'customerId = ?',
      whereArgs: [customerId],
    );
  }

  Future<int> deleteCustomer(String customerId) {
    return db.delete(
      'customers',
      where: 'customerId = ?',
      whereArgs: [customerId],
    );
  }

  Future<List<Map<String, dynamic>>> searchCustomers({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
    List<String>? roles,
  }) async {
    final roleFilter = roles ?? const <String>[];
    final query = (nameQuery ?? phoneQuery ?? '').trim();
    if (roleFilter.isEmpty) {
      final where = <String>[];
      final whereArgs = <dynamic>[];
      where.add('orgId = ?');
      whereArgs.add(scope.orgId);
      where.add('storeId = ?');
      whereArgs.add(scope.storeId);
      if (query.isNotEmpty) {
        where.add('(name LIKE ? OR phone LIKE ? OR email LIKE ?)');
        whereArgs.add('%$query%');
        whereArgs.add('%$query%');
        whereArgs.add('%$query%');
      }
      return db.query(
        'customers',
        where: where.isNotEmpty ? where.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        limit: limit,
        offset: offset,
        orderBy: 'name ASC',
      );
    }

    final placeholders = List.filled(roleFilter.length, '?').join(', ');
    final where = <String>[
      'c.orgId = ?',
      'sr.storeId = ?',
      'sr.access_enabled = 1',
      'sr.role IN ($placeholders)',
    ];
    final whereArgs = <dynamic>[
      scope.orgId,
      scope.storeId,
      ...roleFilter,
    ];
    if (query.isNotEmpty) {
      where.add('(c.name LIKE ? OR c.phone LIKE ? OR c.email LIKE ?)');
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
    }
    whereArgs.addAll([limit ?? 50, offset ?? 0]);
    return db.rawQuery(
      '''
      SELECT DISTINCT c.*, sr.role AS role
      FROM customers c
      INNER JOIN store_roles sr
        ON sr.customerId = c.customerId
       AND sr.orgId = c.orgId
      WHERE ${where.join(' AND ')}
      ORDER BY c.name ASC
      LIMIT ? OFFSET ?
      ''',
      whereArgs,
    );
  }

  Future<List<Map<String, dynamic>>> searchDirectoryCustomers({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
  }) {
    return searchCustomers(
      scope: scope,
      nameQuery: nameQuery,
      phoneQuery: phoneQuery,
      limit: limit,
      offset: offset,
      roles: directoryCustomerRoles,
    );
  }

  Future<Map<String, dynamic>?> authenticateCustomer({
    required StoreScope scope,
    required String email,
    required String password,
  }) {
    return authenticateCustomerByIdentifier(
      orgId: scope.orgId,
      storeId: scope.storeId,
      identifier: email,
      password: password,
    );
  }

  /// Authenticate an operator by staff id (reg number), email, or phone.
  Future<Map<String, dynamic>?> authenticateCustomerByIdentifier({
    required String orgId,
    required String password,
    required String identifier,
    String? storeId,
  }) async {
    final hashedPassword = hashPassword(password);
    final key = identifier.trim();
    if (key.isEmpty) return null;

    // Operators may have empty/legacy status; treat those as active.
    final where = storeId == null || storeId.isEmpty
        ? "orgId = ? AND COALESCE(status, '') IN ('', 'active', 'approved', '1')"
        : "orgId = ? AND storeId = ? AND COALESCE(status, '') IN ('', 'active', 'approved', '1')";
    final whereArgs = storeId == null || storeId.isEmpty
        ? <Object?>[orgId]
        : <Object?>[orgId, storeId];

    final rows = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: "CASE role WHEN 'admin' THEN 0 ELSE 1 END, customerId ASC",
    );

    final keyLower = key.toLowerCase();
    final digits = _digitsOnly(key);
    for (final customer in rows) {
      if (!_identifierMatchesCustomer(customer, keyLower, digits)) {
        continue;
      }
      final storedPassword = customer['password'] as String? ?? '';
      if (storedPassword == hashedPassword) {
        return customer;
      }
      if (storedPassword == password) {
        await db.update(
          'customers',
          {'password': hashedPassword},
          where: 'customerId = ?',
          whereArgs: [customer['customerId']],
        );
        return {
          ...customer,
          'password': hashedPassword,
        };
      }
    }
    return null;
  }

  bool _identifierMatchesCustomer(
    Map<String, Object?> customer,
    String keyLower,
    String digits,
  ) {
    final email = _normalizeEmail(customer['email'] as String?);
    if (email.isNotEmpty && email == keyLower) return true;

    final phone = _digitsOnly(customer['phone'] as String? ?? '');
    if (_phonesMatch(digits, phone)) return true;

    final reg = '${customer['usr_reg_num'] ?? ''}'.trim().toLowerCase();
    if (reg.isNotEmpty &&
        (reg == keyLower || (digits.isNotEmpty && reg == digits))) {
      return true;
    }
    return false;
  }

  /// Match phone numbers allowing country-code / leading-zero differences.
  static bool _phonesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a.length < 7 || b.length < 7) return false;
    return a.endsWith(b) || b.endsWith(a);
  }

  Future<Map<String, dynamic>?> authenticateCustomerForOrganisation({
    required String orgId,
    required String email,
    required String password,
  }) {
    return authenticateCustomerByIdentifier(
      orgId: orgId,
      identifier: email,
      password: password,
    );
  }

  Future<List<Map<String, dynamic>>> listStoreRolesForCustomer({
    required String orgId,
    required String customerId,
  }) {
    return db.query(
      'store_roles',
      where: 'orgId = ? AND customerId = ? AND access_enabled = ?',
      whereArgs: [orgId, customerId, 1],
      orderBy: 'storeId ASC',
    );
  }

  Future<Map<String, dynamic>?> getStoreRole({
    required String orgId,
    required String customerId,
    required String storeId,
  }) async {
    final raw = customerId.trim();
    if (raw.isEmpty || storeId.trim().isEmpty) return null;
    final candidates = <String>{
      raw,
      if (raw.startsWith('user_')) raw.substring(5),
      if (!raw.startsWith('user_') && int.tryParse(raw) != null) 'user_$raw',
    };
    for (final id in candidates) {
      if (id.isEmpty) continue;
      final rows = await db.query(
        'store_roles',
        where:
            'orgId = ? AND customerId = ? AND storeId = ? AND COALESCE(access_enabled, 1) = 1',
        whereArgs: [orgId, id, storeId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    final raw = customerId.trim();
    if (raw.isEmpty) return null;
    final candidates = <String>{
      raw,
      if (raw.startsWith('user_')) raw.substring(5),
      if (!raw.startsWith('user_') && int.tryParse(raw) != null) 'user_$raw',
    };
    for (final id in candidates) {
      if (id.isEmpty) continue;
      final rows = await db.query(
        'customers',
        where: 'customerId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    return null;
  }

  Future<int> updateCustomerPasswordById({
    required String customerId,
    required String newPassword,
  }) async {
    return db.update(
      'customers',
      {'password': hashPassword(newPassword)},
      where: 'customerId = ?',
      whereArgs: [customerId],
    );
  }

  Future<int> updateCustomerPasswordByEmail({
    required String email,
    required String newPassword,
  }) async {
    return db.update(
      'customers',
      {'password': hashPassword(newPassword)},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<void> close() async {
    await db.close();
  }
}
