import 'dart:io';
import 'dart:convert';
import 'sqflite_ffi_io.dart';
import 'package:path/path.dart' as p;
import 'product_data_importer.dart';
import 'store_models.dart';

/// Backend setup for persistent SQLite database.
/// Call [setupDatabase] with a dbName to initialize and get the database instance.

class BackendSetup {
  static const int schemaVersion = 54;

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
        address TEXT,
        registration_number TEXT,
        tax_number TEXT,
        identifier TEXT,
        logo_pending_sync INTEGER DEFAULT 0,
        profile_pending_sync INTEGER DEFAULT 0,
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
        updated_on TEXT NOT NULL,
        exported INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
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
        usr_reg_num TEXT,
        photo_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscribers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT,
        remote_id INTEGER,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        user_id TEXT,
        email TEXT,
        phone_number TEXT,
        country_id TEXT,
        type TEXT NOT NULL DEFAULT 'report',
        notification_type TEXT NOT NULL DEFAULT 'email',
        periodicity TEXT NOT NULL DEFAULT 'daily',
        deleted INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        is_owner_default INTEGER NOT NULL DEFAULT 0,
        created_by TEXT,
        created_on TEXT NOT NULL,
        updated_on TEXT,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        exported INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_subscribers_email_type_channel ON subscribers(orgId, storeId, email, type, notification_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscribers_local_id ON subscribers(orgId, storeId, local_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_email_config (
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        purpose TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        from_email TEXT NOT NULL,
        from_name TEXT NOT NULL,
        use_tls INTEGER NOT NULL DEFAULT 1,
        locked INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (orgId, storeId, purpose)
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
      CREATE TABLE IF NOT EXISTS wallet_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variant_id INTEGER NOT NULL,
        key TEXT,
        name TEXT NOT NULL,
        type INTEGER,
        type_name TEXT,
        pg_type INTEGER,
        pg_name TEXT,
        logo TEXT,
        locked INTEGER NOT NULL DEFAULT 1,
        sorting_order INTEGER NOT NULL DEFAULT 0,
        synced_on TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_variants_scope_variant ON wallet_variants(orgId, storeId, variant_id)',
    );
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
        id INTEGER,
        master_unique_id TEXT,
        exported INTEGER NOT NULL DEFAULT 1,
        last_exported_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
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
        local_image_path TEXT,
        image_cache_source TEXT,
        image_etag TEXT,
        image_last_modified TEXT,
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
        tax_label TEXT,
        master_unique_id TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        exported INTEGER NOT NULL DEFAULT 0,
        last_imported_at TEXT,
        last_exported_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
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
        is_allergens INTEGER,
        categoryLocalId TEXT,
        master_unique_id TEXT,
        exported INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
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
      CREATE TABLE IF NOT EXISTS master_categories (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        short_code TEXT,
        service_variant_type TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_products (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        unique_id TEXT,
        master_category_unique_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_addon_groups (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        min_select INTEGER NOT NULL DEFAULT 0,
        max_select INTEGER NOT NULL DEFAULT 1,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_addon_items (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        groupLocalId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        price TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_variant_addon_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variantLocalId TEXT NOT NULL,
        groupLocalId TEXT NOT NULL,
        UNIQUE(orgId, storeId, variantLocalId, groupLocalId)
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
      // Legacy DBs may lack `total`; only reference columns that exist.
      final orderCols = await db.rawQuery('PRAGMA table_info(orders)');
      final orderColNames = {
        for (final row in orderCols) '${row['name'] ?? ''}',
      };
      if (orderColNames.contains('total')) {
        await db.execute('''
          UPDATE orders
          SET total_value = COALESCE(total_value, total, 0),
              offer_applied_value = COALESCE(offer_applied_value, 0),
              final_value = COALESCE(final_value, total, 0),
              total = COALESCE(final_value, total, 0)
        ''');
      } else {
        await db.execute('''
          UPDATE orders
          SET total_value = COALESCE(total_value, 0),
              offer_applied_value = COALESCE(offer_applied_value, 0),
              final_value = COALESCE(final_value, total_value, 0)
        ''');
      }
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
      await _executeIfTableExists(
        db,
        'orders',
        'CREATE INDEX IF NOT EXISTS idx_orders_customer_unique_id ON orders(orgId, storeId, customer_unique_id)',
      );
      await _executeIfTableExists(
        db,
        'customers',
        'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(orgId, phone)',
      );
      await _executeIfTableExists(
        db,
        'customers',
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
      await _executeIfTableExists(
        db,
        'customers',
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
      final orderCols = await db.rawQuery('PRAGMA table_info(orders)');
      final names = {
        for (final row in orderCols) '${row['name'] ?? ''}',
      };
      final coalesceParts = <String>[
        "NULLIF(TRIM(updated_on), '')",
        if (names.contains('last_exported_at'))
          "NULLIF(TRIM(last_exported_at), '')",
        if (names.contains('created_on')) "NULLIF(TRIM(created_on), '')",
        "datetime('now')",
      ];
      await db.execute('''
        UPDATE orders
        SET updated_on = COALESCE(
          ${coalesceParts.join(',\n          ')}
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
      await _addColumnIfMissing(
        db,
        'orders',
        'exported',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _createIndexIfColumnsExist(
        db,
        'orders',
        ['orgId', 'storeId', 'exported', 'updated_on'],
        'CREATE INDEX IF NOT EXISTS idx_orders_scope_exported_updated '
        'ON orders(orgId, storeId, exported, updated_on)',
      );
      await _createIndexIfColumnsExist(
        db,
        'orders',
        ['orgId', 'storeId', 'exported'],
        'CREATE INDEX IF NOT EXISTS idx_orders_scope_status_exported '
        'ON orders(orgId, storeId, exported)',
      );
      await _executeIfTableExists(
        db,
        'sync_attempts',
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
    if (oldVersion < 41) {
      await _addColumnIfMissing(db, 'categories', 'master_unique_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'categories',
        'exported',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'categories', 'last_exported_at', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'categoryLocalId', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'master_unique_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'products',
        'exported',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'product_variants', 'tax_label', 'TEXT');
      await _addColumnIfMissing(
        db,
        'product_variants',
        'master_unique_id',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        'offers',
        'exported',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'offers', 'description', 'TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS master_categories (
          localId TEXT PRIMARY KEY,
          orgId TEXT NOT NULL,
          unique_id TEXT,
          name TEXT NOT NULL,
          short_code TEXT,
          service_variant_type TEXT,
          exported INTEGER NOT NULL DEFAULT 0,
          last_exported_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS master_products (
          localId TEXT PRIMARY KEY,
          orgId TEXT NOT NULL,
          unique_id TEXT,
          master_category_unique_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          exported INTEGER NOT NULL DEFAULT 0,
          last_exported_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS catalog_addon_groups (
          localId TEXT PRIMARY KEY,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          unique_id TEXT,
          name TEXT NOT NULL,
          min_select INTEGER NOT NULL DEFAULT 0,
          max_select INTEGER NOT NULL DEFAULT 1,
          exported INTEGER NOT NULL DEFAULT 0,
          last_exported_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS catalog_addon_items (
          localId TEXT PRIMARY KEY,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          groupLocalId TEXT NOT NULL,
          unique_id TEXT,
          name TEXT NOT NULL,
          price TEXT,
          exported INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS catalog_variant_addon_links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orgId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          variantLocalId TEXT NOT NULL,
          groupLocalId TEXT NOT NULL,
          UNIQUE(orgId, storeId, variantLocalId, groupLocalId)
        )
      ''');
    }
    if (oldVersion < 42) {
      await _ensureSoftDeleteColumns(db);
    }
    if (oldVersion < 43) {
      await _ensureCompanyProfileColumns(db);
    }
    if (oldVersion < 44) {
      // Repair DBs that landed on 42/43 without columns (web/hot-restart edge cases).
      await _ensureSoftDeleteColumns(db);
      await _ensureCompanyProfileColumns(db);
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
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_offer_targets_scope_value ON offer_targets(orgId, storeId, offer_local_id, target_value)',
      );
    }
    if (oldVersion < 45) {
      await _upgradeToV45(db);
    }
    if (oldVersion < 46) {
      await _upgradeToV46(db);
    }
    if (oldVersion < 47) {
      await _upgradeToV47(db);
    }
    if (oldVersion < 48) {
      await _upgradeToV48(db);
    }
    if (oldVersion < 49) {
      await _upgradeToV49(db);
    }
    if (oldVersion < 50) {
      await _upgradeToV50(db);
    }
    if (oldVersion < 51) {
      await _upgradeToV51(db);
    }
    if (oldVersion < 52) {
      await _upgradeToV52(db);
    }
    if (oldVersion < 53) {
      await _upgradeToV53(db);
    }
    if (oldVersion < 54) {
      await _upgradeToV54(db);
    }
  }

  /// Idempotent repairs for tables/columns that sync and store-setup need.
  /// Safe to call from onOpen even when user_version is already current.
  static Future<void> ensureSchemaRepairs(Database db) async {
    await _upgradeToV48(db);
    await _upgradeToV49(db);
    await _upgradeToV50(db);
    await _upgradeToV51(db);
    await _upgradeToV52(db);
    await _upgradeToV53(db);
    await _upgradeToV54(db);
  }

  /// Packages can be switched inactive (hidden from billing) without deleting.
  static Future<void> _upgradeToV54(Database db) async {
    await _addColumnIfMissing(
      db,
      'product_variants',
      'active',
      'INTEGER NOT NULL DEFAULT 1',
    );
  }

  /// Company profile edits saved offline wait for the next push.
  static Future<void> _upgradeToV53(Database db) async {
    await _ensureCompanyProfileColumns(db);
    await _addColumnIfMissing(db, 'store_info', 'logo_pending_sync', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'store_info', 'profile_pending_sync', 'INTEGER DEFAULT 0');
  }

  static Future<void> _upgradeToV52(Database db) async {
    for (final column in [
      'local_image_path',
      'image_cache_source',
      'image_etag',
      'image_last_modified',
    ]) {
      await _addColumnIfMissing(db, 'product_variants', column, 'TEXT');
    }
  }

  static Future<void> _upgradeToV49(Database db) async {
    await _ensureOfferTargetsTable(db);
    await _ensureSoftDeleteColumns(db);
    await _ensureCompanyProfileColumns(db);
    await _addColumnIfMissing(db, 'product_variants', 'tax_label', 'TEXT');
    // Re-run wallet_variants create for DBs that landed on v48 without the table.
    await _upgradeToV48(db);
  }

  /// Idempotent catalogue tables for DBs that skipped / partially ran v41.
  static Future<void> _upgradeToV50(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_categories (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        short_code TEXT,
        service_variant_type TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_products (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        unique_id TEXT,
        master_category_unique_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_addon_groups (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        min_select INTEGER NOT NULL DEFAULT 0,
        max_select INTEGER NOT NULL DEFAULT 1,
        exported INTEGER NOT NULL DEFAULT 0,
        last_exported_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_addon_items (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        groupLocalId TEXT NOT NULL,
        unique_id TEXT,
        name TEXT NOT NULL,
        price TEXT,
        exported INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_variant_addon_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variantLocalId TEXT NOT NULL,
        groupLocalId TEXT NOT NULL,
        UNIQUE(orgId, storeId, variantLocalId, groupLocalId)
      )
    ''');
    await _ensureSoftDeleteColumns(db);
    await _addColumnIfMissing(db, 'products', 'productId', 'INTEGER');
    await _addColumnIfMissing(db, 'categories', 'categoryId', 'INTEGER');
    await _addColumnIfMissing(db, 'categories', 'id', 'INTEGER');
  }

  /// Master unique indexes + one-shot cleanup of duplicate master/catalogue rows.
  static Future<void> _upgradeToV51(Database db) async {
    await _dedupeMasterRows(db, 'master_categories');
    await _dedupeMasterRows(db, 'master_products');
    await _dedupeStoreCatalogByUniqueId(db, 'categories');
    await _dedupeStoreCatalogByUniqueId(db, 'products');
    await _dedupeStoreCatalogByUniqueId(db, 'product_variants');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_master_categories_org_unique '
      'ON master_categories(orgId, unique_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_master_products_org_unique '
      'ON master_products(orgId, unique_id)',
    );
  }

  static Future<void> _dedupeMasterRows(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (rows.isEmpty) return;

    // Same unique_id → keep lexicographically smallest localId.
    final byUnique = await db.rawQuery('''
      SELECT orgId, unique_id, MIN(localId) AS keepId, COUNT(*) AS c
      FROM $table
      WHERE unique_id IS NOT NULL AND TRIM(unique_id) != ''
      GROUP BY orgId, unique_id
      HAVING c > 1
    ''');
    for (final row in byUnique) {
      await db.delete(
        table,
        where: 'orgId = ? AND unique_id = ? AND localId != ?',
        whereArgs: [row['orgId'], row['unique_id'], row['keepId']],
      );
    }

    // Same name, different unique_ids → keep numeric/server unique_id when present.
    final byName = await db.rawQuery('''
      SELECT orgId, lower(trim(name)) AS n, COUNT(*) AS c
      FROM $table
      WHERE name IS NOT NULL AND TRIM(name) != ''
      GROUP BY orgId, lower(trim(name))
      HAVING c > 1
    ''');
    for (final group in byName) {
      final orgId = '${group['orgId']}';
      final nameKey = '${group['n']}';
      final dupes = await db.query(
        table,
        where: 'orgId = ? AND lower(trim(name)) = ?',
        whereArgs: [orgId, nameKey],
        orderBy: 'localId ASC',
      );
      if (dupes.length < 2) continue;
      Map<String, Object?> keep = dupes.first;
      for (final row in dupes) {
        final uid = '${row['unique_id'] ?? ''}'.trim();
        final keepUid = '${keep['unique_id'] ?? ''}'.trim();
        final rowNumeric = RegExp(r'^\d+$').hasMatch(uid);
        final keepNumeric = RegExp(r'^\d+$').hasMatch(keepUid);
        if (rowNumeric && !keepNumeric) {
          keep = row;
        }
      }
      final keepId = '${keep['localId']}';
      final keepUnique = '${keep['unique_id'] ?? keepId}'.trim();
      for (final row in dupes) {
        final id = '${row['localId']}';
        if (id == keepId) continue;
        // Point store rows at the surviving master unique_id, then drop the dupe.
        if (table == 'master_categories') {
          await db.rawUpdate(
            '''
            UPDATE categories
            SET master_unique_id = ?
            WHERE orgId = ? AND master_unique_id = ?
            ''',
            [keepUnique, orgId, row['unique_id'] ?? row['localId']],
          );
        } else if (table == 'master_products') {
          await db.rawUpdate(
            '''
            UPDATE products
            SET master_unique_id = ?
            WHERE orgId = ? AND master_unique_id = ?
            ''',
            [keepUnique, orgId, row['unique_id'] ?? row['localId']],
          );
          await db.rawUpdate(
            '''
            UPDATE product_variants
            SET master_unique_id = ?
            WHERE orgId = ? AND master_unique_id = ?
            ''',
            [keepUnique, orgId, row['unique_id'] ?? row['localId']],
          );
        }
        await db.delete(table, where: 'localId = ?', whereArgs: [id]);
      }
    }
  }

  static Future<void> _dedupeStoreCatalogByUniqueId(
    Database db,
    String table,
  ) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (rows.isEmpty) return;
    final dupes = await db.rawQuery('''
      SELECT orgId, storeId, unique_id, MIN(localId) AS keepId, COUNT(*) AS c
      FROM $table
      WHERE unique_id IS NOT NULL AND TRIM(unique_id) != ''
      GROUP BY orgId, storeId, unique_id
      HAVING c > 1
    ''');
    for (final row in dupes) {
      final keepId = '${row['keepId']}';
      final losers = await db.query(
        table,
        columns: ['localId'],
        where: 'orgId = ? AND storeId = ? AND unique_id = ? AND localId != ?',
        whereArgs: [row['orgId'], row['storeId'], row['unique_id'], keepId],
      );
      for (final loser in losers) {
        final localId = '${loser['localId']}';
        // Soft-delete when possible so selling/history stay safe.
        final info = await db.rawQuery('PRAGMA table_info($table)');
        final hasDeleted = info.any((c) => c['name'] == 'deleted');
        if (hasDeleted) {
          await db.update(
            table,
            {'deleted': 1, 'exported': 0},
            where: 'localId = ?',
            whereArgs: [localId],
          );
        } else {
          await db.delete(table, where: 'localId = ?', whereArgs: [localId]);
        }
      }
    }
  }

  static Future<void> _ensureOfferTargetsTable(Database db) async {
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
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_offer_targets_scope_value ON offer_targets(orgId, storeId, offer_local_id, target_value)',
    );
  }

  static Future<void> _upgradeToV48(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallet_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variant_id INTEGER NOT NULL,
        key TEXT,
        name TEXT NOT NULL,
        type INTEGER,
        type_name TEXT,
        pg_type INTEGER,
        pg_name TEXT,
        logo TEXT,
        locked INTEGER NOT NULL DEFAULT 1,
        sorting_order INTEGER NOT NULL DEFAULT 0,
        synced_on TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_variants_scope_variant ON wallet_variants(orgId, storeId, variant_id)',
    );
  }

  static Future<void> _upgradeToV45(Database db) async {
    await _addColumnIfMissing(db, 'store_info', 'logo_pending_sync', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'customers', 'photo_path', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_subscribers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        cadence TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        is_owner_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_report_subscribers_email ON report_subscribers(orgId, storeId, email)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_email_config (
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        purpose TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        from_email TEXT NOT NULL,
        from_name TEXT NOT NULL,
        use_tls INTEGER NOT NULL DEFAULT 1,
        locked INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (orgId, storeId, purpose)
      )
    ''');
  }

  static Future<void> _upgradeToV46(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscribers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT,
        remote_id INTEGER,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        user_id TEXT,
        email TEXT,
        phone_number TEXT,
        country_id TEXT,
        type TEXT NOT NULL DEFAULT 'report',
        notification_type TEXT NOT NULL DEFAULT 'email',
        periodicity TEXT NOT NULL DEFAULT 'daily',
        deleted INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        is_owner_default INTEGER NOT NULL DEFAULT 0,
        created_by TEXT,
        created_on TEXT NOT NULL,
        updated_on TEXT,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        exported INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_subscribers_email_type_channel ON subscribers(orgId, storeId, email, type, notification_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscribers_local_id ON subscribers(orgId, storeId, local_id)',
    );

    // Migrate any legacy report_subscribers rows into the multipurpose table.
    try {
      final legacy = await db.query('report_subscribers');
      final now = DateTime.now().toIso8601String();
      for (final row in legacy) {
        final email = (row['email'] as String?)?.trim().toLowerCase() ?? '';
        if (email.isEmpty) continue;
        var cadence = (row['cadence'] as String?)?.trim().toLowerCase() ?? 'daily';
        if (cadence == 'annual' || cadence == 'yearly') cadence = 'annually';
        final existing = await db.query(
          'subscribers',
          where: 'orgId = ? AND storeId = ? AND email = ? AND type = ?',
          whereArgs: [row['orgId'], row['storeId'], email, 'report'],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await db.insert('subscribers', {
          'local_id': 'legacy-report-${row['id']}',
          'orgId': row['orgId'],
          'storeId': row['storeId'],
          'name': row['name'] ?? email,
          'email': email,
          'type': 'report',
          'notification_type': 'email',
          'periodicity': cadence,
          'deleted': 0,
          'active': ((row['enabled'] as num?)?.toInt() ?? 1) == 0 ? 0 : 1,
          'is_owner_default': (row['is_owner_default'] as num?)?.toInt() ?? 0,
          'created_on': row['created_at'] ?? now,
          'updated_on': now,
          'pending_sync': 1,
          'exported': 0,
        });
      }
    } catch (_) {
      // Legacy table may not exist on fresh installs.
    }
  }

  static Future<void> _upgradeToV47(Database db) async {
    await _addColumnIfMissing(
      db,
      'subscribers',
      'notification_type',
      "TEXT NOT NULL DEFAULT 'email'",
    );
    try {
      await db.execute('DROP INDEX IF EXISTS idx_subscribers_email_type');
    } catch (_) {}
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_subscribers_email_type_channel ON subscribers(orgId, storeId, email, type, notification_type)',
    );
  }

  static Future<void> _ensureSoftDeleteColumns(Database db) async {
    for (final table in [
      'categories',
      'products',
      'product_variants',
      'offers',
      'catalog_addon_groups',
      'catalog_addon_items',
    ]) {
      // Prefer nullable-with-default ALTER for broader SQLite/web compatibility.
      await _addColumnIfMissing(db, table, 'deleted', 'INTEGER DEFAULT 0');
    }
  }

  static Future<void> _ensureCompanyProfileColumns(Database db) async {
    await _addColumnIfMissing(db, 'store_info', 'address', 'TEXT');
    await _addColumnIfMissing(db, 'store_info', 'registration_number', 'TEXT');
    await _addColumnIfMissing(db, 'store_info', 'tax_number', 'TEXT');
    await _addColumnIfMissing(db, 'store_info', 'identifier', 'TEXT');
  }

  static Future<void> _createUniqueIndexes(Database db) async {
    Future<void> indexIfTable(
      String table,
      String sql,
    ) async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [table],
      );
      if (rows.isEmpty) return;
      await db.execute(sql);
    }

    await indexIfTable(
      'orders',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_scope_local_id ON orders(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'orders',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_scope_remote_id ON orders(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'order_payments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_payments_scope_local_id ON order_payments(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'order_payments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_payments_scope_remote_id ON order_payments(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'order_refunds',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_order_refunds_scope_local_id ON order_refunds(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'order_refunds',
      'CREATE INDEX IF NOT EXISTS idx_order_refunds_order ON order_refunds(orgId, storeId, order_id)',
    );
    await indexIfTable(
      'order_refunds',
      'CREATE INDEX IF NOT EXISTS idx_order_refunds_payment ON order_refunds(orgId, storeId, payment_id)',
    );
    await indexIfTable(
      'credits',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credits_scope_local_id ON credits(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'credits',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credits_scope_remote_id ON credits(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'credit_accounts',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_customer ON credit_accounts(orgId, storeId, customerId)',
    );
    await indexIfTable(
      'credit_accounts',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_local_id ON credit_accounts(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'credit_accounts',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_accounts_scope_remote_id ON credit_accounts(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'credit_repayments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_repayments_scope_local_id ON credit_repayments(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'credit_repayments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_repayments_scope_remote_id ON credit_repayments(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'credit_installments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_local_id ON credit_installments(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'credit_installments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_installments_scope_remote_id ON credit_installments(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'credit_installments',
      'CREATE INDEX IF NOT EXISTS idx_credit_installments_credit_id ON credit_installments(credit_id, sequence)',
    );
    await indexIfTable(
      'wallets',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_local_id ON wallets(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'wallets',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_scope_remote_id ON wallets(orgId, storeId, remote_id)',
    );
    await indexIfTable(
      'credit_scheduled_repayments',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_scheduled_repayments_scope_local_id ON credit_scheduled_repayments(orgId, storeId, local_id)',
    );
    await indexIfTable(
      'credit_scheduled_repayments',
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
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tableRows.isEmpty) {
      return;
    }
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
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tableRows.isEmpty) {
      return;
    }
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final hasColumn = rows.any((row) => row['name'] == column);
    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _executeIfTableExists(
    Database db,
    String table,
    String sql,
  ) async {
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tableRows.isEmpty) return;
    await db.execute(sql);
  }

  static Future<void> _createIndexIfColumnsExist(
    Database db,
    String table,
    List<String> columns,
    String sql,
  ) async {
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tableRows.isEmpty) return;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final names = {for (final row in info) '${row['name'] ?? ''}'};
    for (final column in columns) {
      if (!names.contains(column)) return;
    }
    await db.execute(sql);
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
