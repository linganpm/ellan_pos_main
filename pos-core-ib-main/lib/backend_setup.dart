import 'dart:io';
import 'dart:convert';
import 'sqflite_ffi_io.dart';
import 'package:path/path.dart' as p;
import 'product_data_importer.dart';
import 'store_models.dart';

/// Backend setup for persistent SQLite database.
/// Call [setupDatabase] with a dbName to initialize and get the database instance.

class BackendSetup {
  static const int schemaVersion = 40;

  /// Public method to create all tables for testing or custom DB setups.
  static Future<void> createTablesForTest(Database db) async {
    await _createTables(db);
  }

  static Future<void> upgradeTablesForTest(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _upgradeTables(db, oldVersion, newVersion);
  }

  static const String fixedDbName = 'pos_orders.db';

   /// Call this on app start. It opens the DB, creates tables if needed, and syncs product data if available.
   static Future<Database> syncAndInit({String? productDataPath}) async {
     sqfliteFfiInit();
     var dbPath = await databaseFactoryFfi.getDatabasesPath();
     
     // Fallback to temp directory if default path is invalid (e.g., read-only system path)
     if (dbPath.startsWith('/') && !dbPath.startsWith(Directory.systemTemp.path)) {
       try {
         // Check if we can write to this directory
         final testFile = File(p.join(dbPath, '.write_test'));
         await testFile.create();
         await testFile.delete();
       } catch (e) {
         // If we can't write, use system temp directory instead
         dbPath = Directory.systemTemp.path;
       }
     }
     
     final fullPath = p.join(dbPath, fixedDbName);
     // Ensure directory exists before opening database
     await Directory(dbPath).create(recursive: true);
    final db = await databaseFactoryFfi.openDatabase(
      fullPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeTables(db, oldVersion, newVersion);
        },
      ),
    );
    // If productDataPath is provided and file exists, sync data
    if (productDataPath != null && File(productDataPath).existsSync()) {
      await dataSync(db, productDataPath);
    }
    return db;
  }

  /// Sync product data from a JSON file using the existing importer.
  /// If a row with the same id exists, it will be updated.
  static Future<void> dataSync(Database db, String jsonFilePath) async {
    // Product data import
    if (jsonFilePath.contains('product_data.json')) {
      final importer = ProductDataImporter(db);
      await importer.importFromJsonFile(
        jsonFilePath,
        scope: const StoreScope(orgId: 'org_default', storeId: 'store_default'),
      );
    }
    // Customer data import
    if (jsonFilePath.contains('customer_data.json')) {
      final file = File(jsonFilePath);
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final data = jsonString.isNotEmpty ? jsonDecode(jsonString) : {};
        final customers = data['customers'] as List<dynamic>?;
        if (customers != null) {
          for (final cust in customers) {
            await db.insert('customers', {
              'customerId': cust['customerId'],
              'remote_id': cust['remote_id'] ?? cust['customerId'],
              'orgId': cust['orgId'],
              'storeId': cust['storeId'],
              'name': cust['name'],
              'email': cust['email'],
              'phone': cust['phone'],
              'country': cust['country'],
              'status': cust['status'],
              'role': cust['role'],
              'password': cust['password'] ?? '',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    }
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organisation (
        orgId TEXT PRIMARY KEY,
        remote_id TEXT,
        org_name TEXT NOT NULL,
        org_code TEXT NOT NULL UNIQUE CHECK (length(org_code) = 6),
        logo TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_info (
        uniqueId TEXT PRIMARY KEY,
        storeId TEXT NOT NULL UNIQUE,
        remote_id TEXT,
        orgId TEXT NOT NULL,
        serviceInstanceId INTEGER NOT NULL,
        storeName TEXT NOT NULL,
        logo TEXT NOT NULL,
        contactEmail TEXT NOT NULL,
        phone TEXT NOT NULL,
        contactPerson TEXT NOT NULL,
        status TEXT NOT NULL,
        serviceVariantType TEXT NOT NULL,
        FOREIGN KEY(orgId) REFERENCES organisation(orgId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        customerId TEXT NOT NULL,
        email TEXT NOT NULL,
        loginAt TEXT NOT NULL,
        role TEXT NOT NULL,
        org_role TEXT NOT NULL DEFAULT '',
        store_role TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_access_cache (
        orgId TEXT PRIMARY KEY,
        deviceId TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        lat REAL,
        lan REAL,
        status TEXT NOT NULL,
        message TEXT,
        registered_at TEXT,
        updated_at TEXT,
        last_checked_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orgId TEXT NOT NULL,
            storeId TEXT NOT NULL,
            unique_id TEXT,
            order_id INTEGER NOT NULL,
            product_variant_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            item_name TEXT,
            table_id TEXT,
            table_name TEXT,
            floor_id TEXT,
            floor_name TEXT,
            qty INTEGER NOT NULL,
            pricing_mode TEXT NOT NULL DEFAULT 'selling',
            sell_price REAL NOT NULL DEFAULT 0,
            buy_price REAL,
            mrp_price REAL NOT NULL DEFAULT 0,
              base_unit_price REAL NOT NULL DEFAULT 0,
            unit_price REAL NOT NULL,
            final_price REAL NOT NULL,
            kitchen_sent_quantity INTEGER NOT NULL DEFAULT 0,
            kitchen_sent_batch INTEGER,
            kitchen_sent_at TEXT,
            created_by TEXT NOT NULL,
            created_on TEXT NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(order_id)
          )
        ''');
    await db.execute('''
        CREATE TABLE IF NOT EXISTS order_item_kitchen_cancellations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          order_item_id INTEGER NOT NULL,
          product_variant_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          cancelled_qty INTEGER NOT NULL,
          cancelled_by TEXT,
          source_kitchen_batch INTEGER,
          created_on TEXT NOT NULL,
          note TEXT
        )
      ''');
    await db.execute('''
        CREATE TABLE IF NOT EXISTS order_item_addons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          order_item_id INTEGER NOT NULL,
          addon_group_id TEXT NOT NULL,
          addon_group_name TEXT NOT NULL,
          min_selections INTEGER NOT NULL DEFAULT 0,
          max_selections INTEGER,
          addon_item_id TEXT NOT NULL,
          addon_item_name TEXT NOT NULL,
          qty INTEGER NOT NULL DEFAULT 1,
          pricing_mode TEXT NOT NULL DEFAULT 'selling',
          sell_price REAL NOT NULL DEFAULT 0,
          buy_price REAL,
          mrp_price REAL NOT NULL DEFAULT 0,
          unit_price REAL NOT NULL DEFAULT 0,
          total_price REAL NOT NULL DEFAULT 0,
          created_on TEXT NOT NULL,
          FOREIGN KEY(order_item_id) REFERENCES order_items(id)
        )
      ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        order_id INTEGER,
        restaurant_name TEXT,
        name TEXT,
        mobile TEXT,
        customer_unique_id TEXT,
        status_name TEXT,
        total REAL,
        total_value REAL NOT NULL DEFAULT 0,
        offer_applied_value REAL NOT NULL DEFAULT 0,
        final_value REAL NOT NULL DEFAULT 0,
        service_instance INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        order_type TEXT NOT NULL,
        pricing_mode TEXT NOT NULL DEFAULT 'selling',
        exported INTEGER NOT NULL DEFAULT 0,
        last_imported_at TEXT,
        last_exported_at TEXT,
        export_fail_count INTEGER NOT NULL DEFAULT 0,
        next_export_at TEXT,
        serve_number INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_counters (
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        value INTEGER NOT NULL,
        PRIMARY KEY (orgId, storeId, name)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_watermarks (
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        entity TEXT NOT NULL,
        watermark TEXT NOT NULL,
        PRIMARY KEY (orgId, storeId, entity)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        order_id INTEGER NOT NULL,
        payment_mode TEXT NOT NULL,
        amount REAL NOT NULL,
        customerId TEXT,
        reference_id TEXT,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        order_id INTEGER NOT NULL,
        payment_id INTEGER NOT NULL,
        payment_local_id TEXT,
        payment_reference_id TEXT,
        amount REAL NOT NULL,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'success',
        created_on TEXT NOT NULL,
        exported INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        local_id TEXT NOT NULL,
        name TEXT NOT NULL,
        target_type TEXT NOT NULL,
        offer_type TEXT NOT NULL,
        percentage_value REAL,
        flat_value REAL,
        minimum_bill_amount REAL,
        buy_quantity INTEGER,
        get_quantity INTEGER,
        active INTEGER NOT NULL DEFAULT 1,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offer_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        offer_local_id TEXT NOT NULL,
        target_value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        customerId TEXT PRIMARY KEY,
        remote_id TEXT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        name TEXT,
        email TEXT,
        phone TEXT,
        country TEXT,
        status TEXT,
        role TEXT,
        password TEXT,
        usr_reg_num TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        customerId TEXT NOT NULL,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        role TEXT NOT NULL,
        access_enabled INTEGER NOT NULL DEFAULT 1,
        UNIQUE(customerId, orgId, storeId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS floors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        floor_id TEXT NOT NULL,
        name TEXT NOT NULL,
        sorting_order INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        table_id TEXT NOT NULL,
        floor_id TEXT NOT NULL,
        name TEXT NOT NULL,
        capacity INTEGER,
        sorting_order INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        wallet_variant_id INTEGER,
        wallet_variant_type INTEGER,
        wallet_variant_pg_type INTEGER,
        wallet_variant_name TEXT,
        acc_name TEXT,
        label TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        currency TEXT,
        sorting_order INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        categoryId INTEGER,
        name TEXT,
        slug TEXT,
        logo TEXT,
        sorting_order INTEGER,
        description TEXT,
        parent_id INTEGER,
        short_code TEXT,
        depth INTEGER,
        path TEXT,
        id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_variants (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        variantId INTEGER,
        categoryLocalId TEXT,
        barcode TEXT,
        product_variant_name TEXT,
        product_name TEXT,
        preorder_product INTEGER,
        product_variant_description TEXT,
        product_variant_quantity INTEGER,
        product_variant_logo TEXT,
        sell_price TEXT,
        buy_price TEXT,
        mrp_price TEXT,
        sell_unit_code INTEGER,
        sell_unit_short TEXT,
        sell_unit_label TEXT,
        sell_unit_base_qty REAL,
        review_max_data REAL,
        review_avg_max_data REAL,
        review_value_data REAL,
        review_max_value_data REAL,
        review_count INTEGER,
        exported INTEGER NOT NULL DEFAULT 0,
        last_imported_at TEXT,
        last_exported_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        direction TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        processed_count INTEGER NOT NULL,
        success_count INTEGER NOT NULL,
        failure_count INTEGER NOT NULL,
        skipped INTEGER NOT NULL DEFAULT 0,
        success INTEGER NOT NULL DEFAULT 0,
        message TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        productId INTEGER,
        variantLocalId TEXT,
        logo TEXT,
        name TEXT,
        type INTEGER,
        description TEXT,
        is_preorder INTEGER,
        is_allergens INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        customerId TEXT,
        order_id INTEGER NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        customerId TEXT NOT NULL,
        credit_limit_amount REAL,
        outstanding_balance REAL NOT NULL DEFAULT 0,
        total_credit_so_far REAL NOT NULL DEFAULT 0,
        total_repaid REAL NOT NULL DEFAULT 0,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        credit_id INTEGER NOT NULL,
        credit_local_id TEXT,
        sequence INTEGER NOT NULL DEFAULT 1,
        amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_repayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        customerId TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        reference_id TEXT,
        paid_on TEXT NOT NULL,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL,
        deleted_reason TEXT,
        deleted_by_customer_id TEXT,
        deleted_on TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_scheduled_repayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        customerId TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled',
        collected_repayment_id INTEGER,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await _createUniqueIndexes(db);
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_floors_scope_floor_id ON floors(orgId, storeId, floor_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tables_scope_table_id ON tables(orgId, storeId, table_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tables_scope_floor_id ON tables(orgId, storeId, floor_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_repayment_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repayment_id INTEGER NOT NULL,
        credit_id INTEGER NOT NULL,
        allocated_amount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(repayment_id) REFERENCES credit_repayments(id),
        FOREIGN KEY(credit_id) REFERENCES credits(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proportions (
        proportionId INTEGER PRIMARY KEY,
        localId TEXT,
        active INTEGER,
        proportion_data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_data (
        id INTEGER PRIMARY KEY,
        name TEXT,
        slug TEXT,
        active INTEGER,
        parent_id INTEGER,
        is_preorder INTEGER,
        parent_slug TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_variant_addon_group_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_addon_group_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_variant_addon_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variantLocalId TEXT NOT NULL,
        variantId INTEGER,
        source TEXT NOT NULL,
        addon_group_id TEXT NOT NULL,
        addon_group_name TEXT NOT NULL,
        min_selections INTEGER NOT NULL DEFAULT 0,
        max_selections INTEGER,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offer_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favourite_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gallery_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_slot_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endTime TEXT,
        startTime TEXT,
        scheduleDeliveryDate TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proportion_data (
        id INTEGER PRIMARY KEY,
        unit INTEGER,
        label TEXT,
        value TEXT,
        active INTEGER,
        default_ INTEGER,
        quantity TEXT,
        proportion_group_data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proportion_group_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_offers_scope_local ON offers(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_offer_targets_scope_value ON offer_targets(orgId, storeId, offer_local_id, target_value)',
    );
  }

  static Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'orders',
        'exported',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'product_variants',
        'exported',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'orders', 'last_imported_at', 'TEXT');
      await _addColumnIfMissing(db, 'orders', 'last_exported_at', 'TEXT');
      await _addColumnIfMissing(
        db,
        'product_variants',
        'last_imported_at',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        'product_variants',
        'last_exported_at',
        'TEXT',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity TEXT NOT NULL,
          direction TEXT NOT NULL,
          started_at TEXT NOT NULL,
          completed_at TEXT NOT NULL,
          processed_count INTEGER NOT NULL,
          success_count INTEGER NOT NULL,
          failure_count INTEGER NOT NULL,
          skipped INTEGER NOT NULL DEFAULT 0,
          success INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS organisation (
          orgId TEXT PRIMARY KEY,
          remote_id TEXT,
          org_name TEXT NOT NULL,
          org_code TEXT NOT NULL UNIQUE CHECK (length(org_code) = 6),
          logo TEXT NOT NULL DEFAULT ''
        )
      ''');
      await _addColumnIfMissing(db, 'store_info', 'remote_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'store_info',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'order_items',
        'orgId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'order_items',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          payment_mode TEXT NOT NULL,
          amount REAL NOT NULL,
          customerId TEXT,
          reference_id TEXT,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
      await _addColumnIfMissing(
        db,
        'orders',
        'orgId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'categories',
        'orgId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'categories',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'product_variants',
        'orgId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'product_variants',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'products',
        'orgId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'products',
        'storeId',
        "TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          customerId TEXT,
          amount REAL NOT NULL DEFAULT 0,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
      await _backfillScopedData(db);
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_roles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT,
          customerId TEXT NOT NULL,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          role TEXT NOT NULL,
          access_enabled INTEGER NOT NULL DEFAULT 1,
          UNIQUE(customerId, orgId, storeId)
        )
      ''');
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        'store_session',
        'org_role',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'store_session',
        'store_role',
        "TEXT NOT NULL DEFAULT ''",
      );
      await db.rawUpdate(
        "UPDATE store_session SET org_role = role WHERE org_role = ''",
      );
      await db.rawUpdate(
        "UPDATE store_session SET store_role = role WHERE store_role = ''",
      );
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          payment_mode TEXT NOT NULL,
          amount REAL NOT NULL,
          customerId TEXT,
          reference_id TEXT,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(
        db,
        'organisation',
        'logo',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(db, 'product_variants', 'barcode', 'TEXT');
    }
    if (oldVersion < 10) {
      await _addColumnIfMissing(
        db,
        'credits',
        'order_id',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_repayments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          customerId TEXT NOT NULL,
          payment_mode TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          reference_id TEXT,
          paid_on TEXT NOT NULL,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL,
          deleted_reason TEXT,
          deleted_by_customer_id TEXT,
          deleted_on TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_repayment_allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          repayment_id INTEGER NOT NULL,
          credit_id INTEGER NOT NULL,
          allocated_amount REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(repayment_id) REFERENCES credit_repayments(id),
          FOREIGN KEY(credit_id) REFERENCES credits(id)
        )
      ''');
    }
    if (oldVersion < 12) {
      await _addColumnIfMissing(
        db,
        'credit_repayments',
        'deleted_reason',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        'credit_repayments',
        'deleted_by_customer_id',
        'TEXT',
      );
      await _addColumnIfMissing(db, 'credit_repayments', 'deleted_on', 'TEXT');
    }
    if (oldVersion < 13) {
      await _addColumnIfMissing(db, 'orders', 'local_id', 'TEXT');
      await _addColumnIfMissing(db, 'orders', 'remote_id', 'INTEGER');
      await _addColumnIfMissing(db, 'order_payments', 'local_id', 'TEXT');
      await _addColumnIfMissing(db, 'order_payments', 'remote_id', 'INTEGER');
      await _addColumnIfMissing(db, 'credits', 'local_id', 'TEXT');
      await _addColumnIfMissing(db, 'credits', 'remote_id', 'INTEGER');
      await _addColumnIfMissing(db, 'credit_repayments', 'local_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'credit_repayments',
        'remote_id',
        'INTEGER',
      );
      await _backfillSyncIdentityColumns(db);
      await _createUniqueIndexes(db);
    }
    if (oldVersion < 14) {
      await _addColumnIfMissing(db, 'organisation', 'remote_id', 'TEXT');
      await _addColumnIfMissing(db, 'store_info', 'remote_id', 'TEXT');
      await _addColumnIfMissing(db, 'customers', 'remote_id', 'TEXT');
      await _addColumnIfMissing(db, 'store_roles', 'remote_id', 'TEXT');
      await _backfillRemoteMetadataColumns(db);
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS device_access_cache (
          orgId TEXT PRIMARY KEY,
          deviceId TEXT NOT NULL,
          make TEXT NOT NULL,
          model TEXT NOT NULL,
          lat REAL,
          lan REAL,
          status TEXT NOT NULL,
          message TEXT,
          registered_at TEXT,
          updated_at TEXT,
          last_checked_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 16) {
      await _addColumnIfMissing(
        db,
        'order_items',
        'base_unit_price',
        'REAL NOT NULL DEFAULT 0',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_item_addons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          order_item_id INTEGER NOT NULL,
          addon_group_id TEXT NOT NULL,
          addon_group_name TEXT NOT NULL,
          min_selections INTEGER NOT NULL DEFAULT 0,
          max_selections INTEGER,
          addon_item_id TEXT NOT NULL,
          addon_item_name TEXT NOT NULL,
          qty INTEGER NOT NULL DEFAULT 1,
          pricing_mode TEXT NOT NULL DEFAULT 'selling',
          sell_price REAL NOT NULL DEFAULT 0,
          buy_price REAL,
          mrp_price REAL NOT NULL DEFAULT 0,
          unit_price REAL NOT NULL DEFAULT 0,
          total_price REAL NOT NULL DEFAULT 0,
          created_on TEXT NOT NULL,
          FOREIGN KEY(order_item_id) REFERENCES order_items(id)
        )
      ''');
      await db.execute('''
        UPDATE order_items
        SET base_unit_price = COALESCE(NULLIF(base_unit_price, 0), unit_price)
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_variant_addon_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          variantLocalId TEXT NOT NULL,
          variantId INTEGER,
          source TEXT NOT NULL,
          addon_group_id TEXT NOT NULL,
          addon_group_name TEXT NOT NULL,
          min_selections INTEGER NOT NULL DEFAULT 0,
          max_selections INTEGER,
          data TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 18) {
      await _addColumnIfMissing(
        db,
        'orders',
        'pricing_mode',
        "TEXT NOT NULL DEFAULT 'selling'",
      );
      await _addColumnIfMissing(
        db,
        'order_items',
        'pricing_mode',
        "TEXT NOT NULL DEFAULT 'selling'",
      );
      await _addColumnIfMissing(
        db,
        'order_items',
        'sell_price',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'order_items', 'buy_price', 'REAL');
      await _addColumnIfMissing(
        db,
        'order_items',
        'mrp_price',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'order_item_addons',
        'pricing_mode',
        "TEXT NOT NULL DEFAULT 'selling'",
      );
      await _addColumnIfMissing(
        db,
        'order_item_addons',
        'sell_price',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'order_item_addons', 'buy_price', 'REAL');
      await _addColumnIfMissing(
        db,
        'order_item_addons',
        'mrp_price',
        'REAL NOT NULL DEFAULT 0',
      );
      await db.execute('''
        UPDATE order_items
        SET sell_price = COALESCE(NULLIF(sell_price, 0), unit_price),
            mrp_price = COALESCE(NULLIF(mrp_price, 0), sell_price, unit_price)
      ''');
      await db.execute('''
        UPDATE order_item_addons
        SET sell_price = COALESCE(NULLIF(sell_price, 0), unit_price),
            mrp_price = COALESCE(NULLIF(mrp_price, 0), sell_price, unit_price)
      ''');
    }
    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          name TEXT NOT NULL,
          target_type TEXT NOT NULL,
          offer_type TEXT NOT NULL,
          percentage_value REAL,
          flat_value REAL,
          buy_quantity INTEGER,
          get_quantity INTEGER,
          active INTEGER NOT NULL DEFAULT 1,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offer_targets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          offer_local_id TEXT NOT NULL,
          target_value TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_offers_scope_local ON offers(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_offer_targets_scope_value ON offer_targets(orgId, storeId, offer_local_id, target_value)',
      );
    }
    if (oldVersion < 20) {
      await _addColumnIfMissing(db, 'orders', 'unique_id', 'TEXT');
      await _addColumnIfMissing(db, 'order_items', 'unique_id', 'TEXT');
      await _addColumnIfMissing(db, 'offers', 'unique_id', 'TEXT');
      await _addColumnIfMissing(db, 'categories', 'unique_id', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'unique_id', 'TEXT');
      await _backfillUniqueIds(db);
      await _createUniqueIndexes(db);
    }
    if (oldVersion < 21) {
      await _addColumnIfMissing(db, 'product_variants', 'unique_id', 'TEXT');
      await _backfillUniqueIds(db);
      await _createUniqueIndexes(db);
    }
    if (oldVersion < 22) {
      await _addColumnIfMissing(
        db,
        'order_items',
        'kitchen_sent_batch',
        'INTEGER',
      );
      await _addColumnIfMissing(db, 'order_items', 'kitchen_sent_at', 'TEXT');
    }
    if (oldVersion < 23) {
      await _addColumnIfMissing(
        db,
        'order_items',
        'kitchen_sent_quantity',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_item_kitchen_cancellations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          order_id INTEGER NOT NULL,
          order_item_id INTEGER NOT NULL,
          product_variant_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          cancelled_qty INTEGER NOT NULL,
          cancelled_by TEXT,
          source_kitchen_batch INTEGER,
          created_on TEXT NOT NULL,
          note TEXT
        )
      ''');
      await db.execute('''
        UPDATE order_items
        SET kitchen_sent_quantity = CASE
          WHEN kitchen_sent_batch IS NOT NULL AND COALESCE(kitchen_sent_quantity, 0) = 0 THEN qty
          ELSE COALESCE(kitchen_sent_quantity, 0)
        END
      ''');
    }
    if (oldVersion < 24) {
      await _addColumnIfMissing(
        db,
        'order_item_kitchen_cancellations',
        'cancelled_by',
        'TEXT',
      );
    }
    if (oldVersion < 25) {
      await _addColumnIfMissing(db, 'offers', 'minimum_bill_amount', 'REAL');
      await _addColumnIfMissing(
        db,
        'orders',
        'total_value',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'offer_applied_value',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'final_value',
        'REAL NOT NULL DEFAULT 0',
      );
      await db.execute('''
        UPDATE orders
        SET total_value = COALESCE(total_value, total, 0),
            offer_applied_value = COALESCE(offer_applied_value, 0),
            final_value = COALESCE(final_value, total, 0),
            total = COALESCE(final_value, total, 0)
      ''');
    }
    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS floors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          floor_id TEXT NOT NULL,
          name TEXT NOT NULL,
          sorting_order INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          table_id TEXT NOT NULL,
          floor_id TEXT NOT NULL,
          name TEXT NOT NULL,
          capacity INTEGER,
          sorting_order INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await _addColumnIfMissing(db, 'order_items', 'table_id', 'TEXT');
      await _addColumnIfMissing(db, 'order_items', 'table_name', 'TEXT');
      await _addColumnIfMissing(db, 'order_items', 'floor_id', 'TEXT');
      await _addColumnIfMissing(db, 'order_items', 'floor_name', 'TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_floors_scope_floor_id ON floors(orgId, storeId, floor_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_tables_scope_table_id ON tables(orgId, storeId, table_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tables_scope_floor_id ON tables(orgId, storeId, floor_id)',
      );
    }
    if (oldVersion < 27) {
      // Stable customer sync key on orders — never use SQLite autoincrement PKs.
      await _addColumnIfMissing(db, 'orders', 'customer_unique_id', 'TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_customer_unique_id ON orders(orgId, storeId, customer_unique_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(orgId, phone)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(orgId, email)',
      );
    }
    if (oldVersion < 28) {
      await _addColumnIfMissing(db, 'product_variants', 'sell_unit_code', 'INTEGER');
      await _addColumnIfMissing(db, 'product_variants', 'sell_unit_short', 'TEXT');
      await _addColumnIfMissing(db, 'product_variants', 'sell_unit_label', 'TEXT');
      await _addColumnIfMissing(db, 'product_variants', 'sell_unit_base_qty', 'REAL');
    }
    if (oldVersion < 29) {
      await _addColumnIfMissing(db, 'credits', 'due_date', 'TEXT');
    }
    if (oldVersion < 30) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_installments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          remote_id INTEGER,
          credit_id INTEGER NOT NULL,
          credit_local_id TEXT,
          sequence INTEGER NOT NULL DEFAULT 1,
          amount REAL NOT NULL DEFAULT 0,
          paid_amount REAL NOT NULL DEFAULT 0,
          due_date TEXT,
          status TEXT NOT NULL DEFAULT 'open',
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_local_id ON credit_installments(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_remote_id ON credit_installments(orgId, storeId, remote_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_credit_installments_credit_id ON credit_installments(credit_id, sequence)',
      );
    }
    if (oldVersion < 31) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          remote_id INTEGER,
          wallet_variant_id INTEGER,
          wallet_variant_type INTEGER,
          wallet_variant_pg_type INTEGER,
          wallet_variant_name TEXT,
          acc_name TEXT,
          label TEXT NOT NULL,
          payment_mode TEXT NOT NULL,
          currency TEXT,
          sorting_order INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_local_id ON wallets(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_remote_id ON wallets(orgId, storeId, remote_id)',
      );
    }
    if (oldVersion < 32) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_scheduled_repayments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          customerId TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0,
          due_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'scheduled',
          collected_repayment_id INTEGER,
          created_on TEXT NOT NULL,
          updated_on TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_scheduled_repayments_scope_local_id ON credit_scheduled_repayments(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_credit_scheduled_repayments_customer ON credit_scheduled_repayments(orgId, storeId, customerId, due_date)',
      );
    }
    if (oldVersion < 33) {
      await _addColumnIfMissing(db, 'customers', 'usr_reg_num', 'TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_org_reg_num ON customers(orgId, usr_reg_num)',
      );
    }
    if (oldVersion < 34) {
      await _addColumnIfMissing(db, 'order_items', 'item_name', 'TEXT');
    }
    if (oldVersion < 35) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          remote_id INTEGER,
          customerId TEXT NOT NULL,
          credit_limit_amount REAL,
          outstanding_balance REAL NOT NULL DEFAULT 0,
          total_credit_so_far REAL NOT NULL DEFAULT 0,
          total_repaid REAL NOT NULL DEFAULT 0,
          updated_on TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_customer ON credit_accounts(orgId, storeId, customerId)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_local_id ON credit_accounts(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_remote_id ON credit_accounts(orgId, storeId, remote_id)',
      );
    }
    if (oldVersion < 36) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_refunds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          local_id TEXT NOT NULL,
          remote_id INTEGER,
          order_id INTEGER NOT NULL,
          payment_id INTEGER NOT NULL,
          payment_local_id TEXT,
          payment_reference_id TEXT,
          amount REAL NOT NULL,
          reason TEXT,
          status TEXT NOT NULL DEFAULT 'success',
          created_on TEXT NOT NULL,
          exported INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_refunds_scope_local_id ON order_refunds(orgId, storeId, local_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_refunds_order ON order_refunds(orgId, storeId, order_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_refunds_payment ON order_refunds(orgId, storeId, payment_id)',
      );
    }
    if (oldVersion < 37) {
      await _addColumnIfMissing(db, 'orders', 'updated_on', 'TEXT');
      await db.execute('''
        UPDATE orders
        SET updated_on = COALESCE(
          NULLIF(TRIM(updated_on), ''),
          NULLIF(TRIM(last_exported_at), ''),
          NULLIF(TRIM(created_on), ''),
          datetime('now')
        )
        WHERE updated_on IS NULL OR TRIM(updated_on) = ''
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_watermarks (
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          entity TEXT NOT NULL,
          watermark TEXT NOT NULL,
          PRIMARY KEY (orgId, storeId, entity)
        )
      ''');
    }
    if (oldVersion < 38) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_scope_exported_updated '
        'ON orders(orgId, storeId, exported, updated_on)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_scope_status_exported '
        'ON orders(orgId, storeId, exported)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_attempts_started_at '
        'ON sync_attempts(started_at)',
      );
    }
    if (oldVersion < 39) {
      await _addColumnIfMissing(
        db,
        'orders',
        'export_fail_count',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'orders', 'next_export_at', 'TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_scope_next_export '
        'ON orders(orgId, storeId, exported, next_export_at)',
      );
    }
    if (oldVersion < 40) {
      await _addColumnIfMissing(db, 'orders', 'serve_number', 'INTEGER');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_counters (
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          value INTEGER NOT NULL,
          PRIMARY KEY (orgId, storeId, name)
        )
      ''');
    }
  }

  static Future<void> _createUniqueIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_scope_local_id ON orders(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_scope_remote_id ON orders(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_payments_scope_local_id ON order_payments(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_payments_scope_remote_id ON order_payments(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_refunds_scope_local_id ON order_refunds(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_refunds_order ON order_refunds(orgId, storeId, order_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_refunds_payment ON order_refunds(orgId, storeId, payment_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credits_scope_local_id ON credits(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credits_scope_remote_id ON credits(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_customer ON credit_accounts(orgId, storeId, customerId)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_local_id ON credit_accounts(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_remote_id ON credit_accounts(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_repayments_scope_local_id ON credit_repayments(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_repayments_scope_remote_id ON credit_repayments(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_local_id ON credit_installments(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_remote_id ON credit_installments(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_credit_installments_credit_id ON credit_installments(credit_id, sequence)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_local_id ON wallets(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_remote_id ON wallets(orgId, storeId, remote_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_scheduled_repayments_scope_local_id ON credit_scheduled_repayments(orgId, storeId, local_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_credit_scheduled_repayments_customer ON credit_scheduled_repayments(orgId, storeId, customerId, due_date)',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'orders',
      'unique_id',
      'idx_orders_scope_unique_id',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'order_items',
      'unique_id',
      'idx_order_items_scope_unique_id',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'offers',
      'unique_id',
      'idx_offers_scope_unique_id',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'categories',
      'unique_id',
      'idx_categories_scope_unique_id',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'products',
      'unique_id',
      'idx_products_scope_unique_id',
    );
    await _createUniqueIndexIfColumnExists(
      db,
      'product_variants',
      'unique_id',
      'idx_product_variants_scope_unique_id',
    );
  }

  static Future<void> _backfillSyncIdentityColumns(Database db) async {
    await db.execute('''
      UPDATE orders
      SET local_id = COALESCE(
        NULLIF(local_id, ''),
        orgId || ':' || storeId || ':legacy-order:' || CAST(COALESCE(order_id, id) AS TEXT) || ':' || CAST(id AS TEXT)
      )
      WHERE local_id IS NULL OR local_id = ''
    ''');
    await db.execute('''
      UPDATE orders
      SET remote_id = id
      WHERE remote_id IS NULL AND last_imported_at IS NOT NULL
    ''');

    await db.execute('''
      UPDATE order_payments
      SET local_id = COALESCE(
        NULLIF(local_id, ''),
        orgId || ':' || storeId || ':legacy-order-payment:' || CAST(id AS TEXT)
      )
      WHERE local_id IS NULL OR local_id = ''
    ''');

    await db.execute('''
      UPDATE credits
      SET local_id = COALESCE(
        NULLIF(local_id, ''),
        orgId || ':' || storeId || ':legacy-credit:' || CAST(id AS TEXT)
      )
      WHERE local_id IS NULL OR local_id = ''
    ''');

    await db.execute('''
      UPDATE credit_repayments
      SET local_id = COALESCE(
        NULLIF(local_id, ''),
        orgId || ':' || storeId || ':legacy-credit-repayment:' || CAST(id AS TEXT)
      )
      WHERE local_id IS NULL OR local_id = ''
    ''');
  }

  static Future<void> _backfillRemoteMetadataColumns(Database db) async {
    await db.execute('''
      UPDATE organisation
      SET remote_id = COALESCE(NULLIF(remote_id, ''), orgId)
      WHERE remote_id IS NULL OR remote_id = ''
    ''');
    await db.execute('''
      UPDATE store_info
      SET remote_id = COALESCE(NULLIF(remote_id, ''), storeId)
      WHERE remote_id IS NULL OR remote_id = ''
    ''');
    await db.execute('''
      UPDATE customers
      SET remote_id = COALESCE(NULLIF(remote_id, ''), customerId)
      WHERE remote_id IS NULL OR remote_id = ''
    ''');
    await db.execute('''
      UPDATE store_roles
      SET remote_id = COALESCE(NULLIF(remote_id, ''), orgId || ':' || storeId || ':' || customerId || ':' || role)
      WHERE remote_id IS NULL OR remote_id = ''
    ''');
  }

  static Future<void> _backfillUniqueIds(Database db) async {
    await _clearEmptyUniqueIdValues(db, 'orders');
    await _clearEmptyUniqueIdValues(db, 'order_items');
    await _clearEmptyUniqueIdValues(db, 'offers');
    await _clearEmptyUniqueIdValues(db, 'categories');
    await _clearEmptyUniqueIdValues(db, 'products');
    await _clearEmptyUniqueIdValues(db, 'product_variants');
  }

  static Future<void> _clearEmptyUniqueIdValues(
    Database db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final hasUniqueId = rows.any((row) => row['name'] == 'unique_id');
    if (!hasUniqueId) {
      return;
    }
    await db.execute(
      'UPDATE $table SET unique_id = NULL WHERE unique_id = \'\'',
    );
  }

  static Future<void> _createUniqueIndexIfColumnExists(
    Database db,
    String table,
    String column,
    String indexName,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final hasColumn = rows.any((row) => row['name'] == column);
    if (!hasColumn) {
      return;
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS $indexName ON $table(orgId, storeId, $column)',
    );
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final hasColumn = rows.any((row) => row['name'] == column);
    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _backfillScopedData(Database db) async {
    final storeRows = await db.query('store_info', limit: 1);
    final storeInfo = storeRows.isEmpty ? null : storeRows.first;
    final orgId = storeInfo?['orgId'] as String? ?? 'org_default';
    final storeId = (storeInfo?['storeId'] as String?)?.isNotEmpty == true
        ? storeInfo!['storeId'] as String
        : (storeInfo?['uniqueId'] as String? ?? 'store_default');
    final serviceInstanceId =
        (storeInfo?['serviceInstanceId'] as num?)?.toInt() ?? 1;
    final generatedCode = serviceInstanceId
        .toString()
        .padLeft(6, '0')
        .substring(0, 6);

    if (storeInfo != null) {
      await db.update(
        'store_info',
        {'storeId': storeId, 'remote_id': storeId},
        where: 'uniqueId = ?',
        whereArgs: [storeInfo['uniqueId']],
      );
    }

    await db.insert('organisation', {
      'orgId': orgId,
      'remote_id': orgId,
      'org_name': storeInfo?['storeName'] as String? ?? 'Default Organisation',
      'org_code': generatedCode,
      'logo': storeInfo?['logo'] as String? ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.rawUpdate(
      "UPDATE orders SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE categories SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE product_variants SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE products SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE order_items SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE order_payments SET orgId = ?, storeId = ? WHERE orgId = '' OR storeId = ''",
      [orgId, storeId],
    );
    await db.rawUpdate(
      "UPDATE customers SET orgId = ? WHERE orgId IS NULL OR orgId = ''",
      [orgId],
    );
    await db.rawUpdate(
      "UPDATE customers SET storeId = ? WHERE storeId IS NULL OR storeId = ''",
      [storeId],
    );
  }

  /// Simple login: returns true if email and password match a customer.
  static Future<bool> login(Database db, String email, String password) async {
    final result = await db.query(
      'customers',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
