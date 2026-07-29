import 'dart:convert';

import 'constants/discovery_constants.dart';

/// Builds StoreConfig for the **first online launch**.
///
/// Keeps catalogue import URLs so products / tables / credits / customers can
/// be pulled once after the operator signs in and opens a store. Bootstrap and
/// device-registration URLs stay empty — those already ran during setup.
Map<String, dynamic> buildFirstLaunchPosConfig({
  required Map<String, dynamic> remoteConfig,
  required Map<String, dynamic> bootstrapPayload,
  required String localCustomersPath,
}) {
  return _buildPosConfig(
    remoteConfig: remoteConfig,
    bootstrapPayload: bootstrapPayload,
    localCustomersPath: localCustomersPath,
    keepCatalogImports: true,
  );
}

/// Builds a StoreConfig that keeps POS ordering fully offline after setup.
///
/// - No remote bootstrap lookup URL (prevents re-calling /api/pos/bootstrap)
/// - No import/export endpoints (catalogue already on-device; orders never leave)
/// - Points customers asset path at the locally cached bootstrap customer file
Map<String, dynamic> buildOfflinePosConfig({
  required Map<String, dynamic> remoteConfig,
  required Map<String, dynamic> bootstrapPayload,
  required String localCustomersPath,
}) {
  return _buildPosConfig(
    remoteConfig: remoteConfig,
    bootstrapPayload: bootstrapPayload,
    localCustomersPath: localCustomersPath,
    keepCatalogImports: false,
  );
}

/// Rewrites a previously saved first-launch config into a sealed offline one.
///
/// Bootstrap discovery / device-registration URLs are dropped so cold starts
/// never re-register. Catalogue import URLs (and login_url) stay: every store
/// the operator opens still has to pull its own products / tables / credits,
/// and sign-in still goes through Org/Auth/Login via the gateway.
Map<String, dynamic> sealOfflinePosConfig(Map<String, dynamic> config) {
  final sync = config['sync'];
  final syncMap = sync is Map ? Map<String, dynamic>.from(sync) : <String, dynamic>{};
  final bootstrap = config['bootstrap'];
  final bootstrapMap =
      bootstrap is Map ? bootstrap.cast<String, dynamic>() : <String, dynamic>{};
  final loginUrl = _normalizePosLoginUrl(
    '${bootstrapMap['login_url'] ?? ''}'.trim().isNotEmpty
        ? '${bootstrapMap['login_url']}'
        : _loginUrlFromBase(syncMap['base_url']),
  );
  // Prefer discovery login when the cached value is missing or doubled.
  final gatewayLogin =
      Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/login').toString();
  return sanitizeStoreConfigJson({
    ...config,
    'bootstrap': <String, dynamic>{
      'lookup_url': '',
      'device_registration_url': '',
      // Keep login so store-list catalogue sync can still authenticate remotely.
      'login_url': loginUrl.isNotEmpty ? loginUrl : gatewayLogin,
    },
    'sync': {
      'base_url': syncMap['base_url'] ?? '',
      'auto_sync_enabled': false,
      'periodic_duration_seconds':
          syncMap['periodic_duration_seconds'] ?? 300,
      // Orders keep their export endpoint: local orders upload on every sync.
      'orders': _importAndExport(syncMap['orders']),
      // Products keep export so tablet Store Setup catalogue reaches the server.
      'products': _importAndExport(syncMap['products']),
      'customers': _importOnly(syncMap['customers']),
      // Credits keep export so buy-on-credit ledger reaches the server.
      'credits': _importAndExport(syncMap['credits']),
      'tables': _importOnly(syncMap['tables']),
      'wallets': _importOnly(syncMap['wallets']),
      'offers': _importOnly(syncMap['offers']),
    },
    if (config['pos_code'] != null) 'pos_code': config['pos_code'],
  });
}

String _loginUrlFromBase(Object? baseUrl) {
  final base = '${baseUrl ?? ''}'.trim().replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return '';
  if (base.endsWith('/api/pos')) return _normalizePosLoginUrl('$base/login');
  return _normalizePosLoginUrl('$base/api/pos/login');
}

/// Collapses `/api/pos/api/pos/...` left behind by older sealed configs.
String _normalizePosLoginUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return '';
  while (url.contains('/api/pos/api/pos')) {
    url = url.replaceAll('/api/pos/api/pos', '/api/pos');
  }
  return url;
}

/// Fills in catalogue import endpoints that an older sealed config dropped,
/// and repairs login/base URLs so sign-in does not hit a doubled `/api/pos` path.
Map<String, dynamic> ensureCatalogImportUrls(Map<String, dynamic> config) {
  final sync = config['sync'];
  final syncMap =
      sync is Map ? Map<String, dynamic>.from(sync) : <String, dynamic>{};
  final bootstrap = config['bootstrap'];
  final bootstrapMap = bootstrap is Map
      ? Map<String, dynamic>.from(bootstrap)
      : <String, dynamic>{};

  final gateway = Uri.parse(kDiscoveryUrl);
  final origin =
      gateway.replace(path: '').toString().replaceAll(RegExp(r'/+$'), '');
  final correctLogin = gateway.replace(path: '/api/pos/login').toString();

  const entities = [
    'products',
    'customers',
    'credits',
    'tables',
    'orders',
    'wallets',
    'offers',
  ];
  const twoWayEntities = {'orders', 'customers', 'credits', 'products'};
  const defaultExportTokens = {
    'orders': 'orders-token',
    'customers': 'customers-token',
    'credits': 'credits-token',
    'products': 'products-token',
  };

  for (final entity in entities) {
    final row = syncMap[entity];
    var map = row is Map ? row.cast<String, dynamic>() : <String, dynamic>{};
    final hasImport = '${map['import_url'] ?? ''}'.trim().isNotEmpty ||
        '${map['import_path'] ?? ''}'.trim().isNotEmpty;
    if (!hasImport) {
      map = {
        ...map,
        'import_url':
            gateway.replace(path: '/api/pos/$entity/import').toString(),
      };
    } else {
      // Repair absolute import URLs that doubled the gateway prefix.
      final importUrl = '${map['import_url'] ?? ''}'.trim();
      if (importUrl.contains('/api/pos/api/pos')) {
        map = {...map, 'import_url': _normalizePosLoginUrl(importUrl)};
      }
    }
    if (twoWayEntities.contains(entity)) {
      // Older cached configs dropped the export endpoint — restore it so
      // local rows upload during sync.
      final hasExport = '${map['export_url'] ?? ''}'.trim().isNotEmpty ||
          '${map['export_path'] ?? ''}'.trim().isNotEmpty;
      if (!hasExport) {
        map = {
          ...map,
          'export_url':
              gateway.replace(path: '/api/pos/$entity/export').toString(),
        };
      }
      if ('${map['export_token'] ?? ''}'.trim().isEmpty) {
        map = {
          ...map,
          'export_token': defaultExportTokens[entity] ?? '$entity-token',
        };
      }
    }
    syncMap[entity] = map;
  }

  // Origin only — never store .../api/pos here.
  final baseUrl =
      '${syncMap['base_url'] ?? ''}'.trim().replaceAll(RegExp(r'/+$'), '');
  if (baseUrl.isEmpty || baseUrl.endsWith('/api/pos')) {
    syncMap['base_url'] = origin;
  }

  // Always rewrite login_url from discovery — do not trust a cached doubled path.
  bootstrapMap['login_url'] = correctLogin;

  return {...config, 'bootstrap': bootstrapMap, 'sync': syncMap};
}

/// Strips everything but the import endpoint from a sync entity section.
Map<String, dynamic> _importOnly(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final row = raw.cast<String, dynamic>();
  return {
    if (row['import_path'] != null) 'import_path': row['import_path'],
    if (row['import_url'] != null) 'import_url': row['import_url'],
  };
}

/// Keeps both directions for entities that push local rows to the gateway.
Map<String, dynamic> _importAndExport(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final row = raw.cast<String, dynamic>();
  return {
    ..._importOnly(row),
    if (row['export_path'] != null) 'export_path': row['export_path'],
    if (row['export_url'] != null) 'export_url': row['export_url'],
    if (row['export_token'] != null) 'export_token': row['export_token'],
  };
}

/// Ensures store metadata satisfies StoreConfig's non-empty string rules.
///
/// Older cached setups may still have blank `logo` / `contact_person` values
/// from the gateway; sanitize them before [StoreConfig.fromJson].
Map<String, dynamic> sanitizeStoreConfigJson(Map<String, dynamic> config) {
  final sanitized = Map<String, dynamic>.from(config);

  Map<String, dynamic> fixStore(Map raw) {
    final row = raw.cast<String, dynamic>();
    return {
      ...row,
      'org_id': _nonEmpty(row['org_id'] ?? row['orgId'], '0'),
      'org_name': _nonEmpty(row['org_name'] ?? row['orgName'], 'Organisation'),
      'org_code': _nonEmpty(row['org_code'] ?? row['orgCode'], '000000'),
      'store_id': _nonEmpty(row['store_id'] ?? row['storeId'], '0'),
      'service_instance_id':
          row['service_instance_id'] ?? row['serviceInstanceId'] ?? 0,
      'store_name': _nonEmpty(row['store_name'] ?? row['storeName'], 'Store'),
      'logo': _nonEmpty(row['logo'], 'logo.png'),
      'unique_id': _nonEmpty(row['unique_id'] ?? row['uniqueId'], '00000000'),
      'contact_email': _nonEmpty(
        row['contact_email'] ?? row['contactEmail'],
        'noreply@example.com',
      ),
      'phone': _nonEmpty(row['phone'], '0000000000'),
      'contact_person': _nonEmpty(
        row['contact_person'] ?? row['contactPerson'],
        'Staff',
      ),
      'status': _nonEmpty(row['status'], 'active'),
      'service_variant_type': _nonEmpty(
        row['service_variant_type'] ?? row['serviceVariantType'],
        'standard',
      ),
    };
  }

  final stores = sanitized['stores'];
  if (stores is List) {
    sanitized['stores'] = [
      for (final raw in stores)
        if (raw is Map) fixStore(raw),
    ];
  }
  for (final key in ['default_store', 'test_store']) {
    final raw = sanitized[key];
    if (raw is Map) {
      sanitized[key] = fixStore(raw);
    }
  }

  final login = sanitized['default_login'];
  if (login is Map) {
    final row = login.cast<String, dynamic>();
    sanitized['default_login'] = {
      ...row,
      'email': _nonEmpty(row['email'], 'pos@example.com'),
      'password': _nonEmpty(row['password'], 'pos123'),
    };
  }

  final assets = sanitized['asset_paths'];
  if (assets is Map) {
    final row = assets.cast<String, dynamic>();
    sanitized['asset_paths'] = {
      ...row,
      // Empty products/orders = remote-only catalogue; never fixture fallbacks.
      'orders': row['orders'] is String ? row['orders'] : '',
      'products': row['products'] is String ? row['products'] : '',
      'customers': _nonEmpty(
        row['customers'],
        'local_customers.json',
      ),
    };
  }

  return sanitized;
}

Map<String, dynamic> _buildPosConfig({
  required Map<String, dynamic> remoteConfig,
  required Map<String, dynamic> bootstrapPayload,
  required String localCustomersPath,
  required bool keepCatalogImports,
}) {
  final stores = <Map<String, dynamic>>[];
  final bootstrapStores = bootstrapPayload['stores'];
  if (bootstrapStores is List) {
    for (final raw in bootstrapStores) {
      if (raw is! Map) continue;
      final row = raw.cast<String, dynamic>();
      stores.add({
        'org_id': _nonEmpty(row['org_id'] ?? row['orgId'], '0'),
        'org_name': _nonEmpty(row['org_name'] ?? row['orgName'], 'Organisation'),
        'org_code': _nonEmpty(row['org_code'] ?? row['orgCode'], '000000'),
        'store_id': _nonEmpty(row['store_id'] ?? row['storeId'], '0'),
        'service_instance_id':
            row['service_instance_id'] ?? row['serviceInstanceId'] ?? 0,
        'store_name': _nonEmpty(row['store_name'] ?? row['storeName'], 'Store'),
        // StoreConfig rejects empty strings for these required fields.
        'logo': _nonEmpty(row['logo'], 'logo.png'),
        'unique_id': _nonEmpty(row['unique_id'] ?? row['uniqueId'], '00000000'),
        'contact_email': _nonEmpty(
          row['contact_email'] ?? row['contactEmail'],
          'noreply@example.com',
        ),
        'phone': _nonEmpty(row['phone'], '0000000000'),
        'contact_person': _nonEmpty(
          row['contact_person'] ?? row['contactPerson'],
          'Staff',
        ),
        'status': _nonEmpty(row['status'], 'active'),
        'service_variant_type': _nonEmpty(
          row['service_variant_type'] ?? row['serviceVariantType'],
          'standard',
        ),
        'remote_id': row['remote_id'] ?? row['store_id'] ?? row['storeId'],
        // Organisation clock / country flag (home AppBar).
        if ('${row['timezone'] ?? row['time_zone'] ?? ''}'.trim().isNotEmpty)
          'timezone': '${row['timezone'] ?? row['time_zone']}'.trim(),
        if ('${row['timezone'] ?? row['time_zone'] ?? ''}'.trim().isNotEmpty)
          'time_zone': '${row['timezone'] ?? row['time_zone']}'.trim(),
        if ('${row['country_code'] ?? ''}'.trim().isNotEmpty)
          'country_code': '${row['country_code']}'.trim(),
        if ('${row['country_flag'] ?? row['flag'] ?? ''}'.trim().isNotEmpty)
          'country_flag': '${row['country_flag'] ?? row['flag']}'.trim(),
        if ('${row['country_name'] ?? ''}'.trim().isNotEmpty)
          'country_name': '${row['country_name']}'.trim(),
        if ('${row['currency_code'] ?? ''}'.trim().isNotEmpty)
          'currency_code': '${row['currency_code']}'.trim(),
        if ('${row['currency_symbol'] ?? ''}'.trim().isNotEmpty)
          'currency_symbol': '${row['currency_symbol']}'.trim(),
        if ('${row['currency_name'] ?? ''}'.trim().isNotEmpty)
          'currency_name': '${row['currency_name']}'.trim(),
      });
    }
  }

  final defaultStore = stores.isNotEmpty ? stores.first : null;
  final remoteSync = remoteConfig['sync'];
  final remoteSyncMap =
      remoteSync is Map ? remoteSync.cast<String, dynamic>() : <String, dynamic>{};
  final remoteAssets = remoteConfig['asset_paths'];
  final remoteAssetsMap = remoteAssets is Map
      ? remoteAssets.cast<String, dynamic>()
      : <String, dynamic>{};
  final remoteLogin = remoteConfig['default_login'];
  final remoteLoginMap = remoteLogin is Map
      ? remoteLogin.cast<String, dynamic>()
      : <String, dynamic>{
          'email': 'pos@example.com',
          'password': 'unused',
        };

  Map<String, dynamic> entitySync(String key) {
    if (!keepCatalogImports) return <String, dynamic>{};
    final raw = remoteSyncMap[key];
    if (raw is! Map) return <String, dynamic>{};
    final row = raw.cast<String, dynamic>();
    // Orders, directory customers, and credits sync both ways (local rows upload).
    if (key == 'orders' || key == 'customers' || key == 'credits') {
      return _importAndExport(row);
    }
    return _importOnly(row);
  }

    // Device registration + bootstrap already completed during setup.
    // Keep login_url for first-launch online auth via Org/Auth/Login (org SI).
    final remoteBootstrap = remoteConfig['bootstrap'];
    final remoteBootstrapMap = remoteBootstrap is Map
        ? remoteBootstrap.cast<String, dynamic>()
        : <String, dynamic>{};
    final loginUrl = keepCatalogImports
        ? '${remoteBootstrapMap['login_url'] ?? ''}'.trim()
        : '';

    return {
    'db_name_id': remoteConfig['db_name_id'] ?? 'store_pos_offline',
    'environment': remoteConfig['environment'] ?? 'development',
    'bootstrap': <String, dynamic>{
      'lookup_url': '',
      'device_registration_url': '',
      'login_url': loginUrl,
    },
    'sync': {
      'base_url': keepCatalogImports ? (remoteSyncMap['base_url'] ?? '') : '',
      'auto_sync_enabled': false,
      'periodic_duration_seconds':
          remoteSyncMap['periodic_duration_seconds'] ?? 300,
      'orders': entitySync('orders'),
      'products': entitySync('products'),
      'customers': entitySync('customers'),
      'credits': entitySync('credits'),
      'tables': entitySync('tables'),
      'wallets': entitySync('wallets'),
      'offers': entitySync('offers'),
    },
    'session_duration_hours': remoteConfig['session_duration_hours'] ?? 12,
    'login_lease_minutes':
        remoteConfig['login_lease_minutes'] ?? (7 * 24 * 60),
    'login_lease_days': remoteConfig['login_lease_days'] ?? 7,
    if (remoteConfig['pos_code'] != null) 'pos_code': remoteConfig['pos_code'],
    if (remoteConfig['fixed_email_mailers'] is List)
      'fixed_email_mailers': remoteConfig['fixed_email_mailers'],
    // Top-level org clock / country (home AppBar + dashboard buckets).
    ..._localeFieldsFrom(remoteConfig, bootstrapPayload, defaultStore),
    if (defaultStore != null) 'default_store': defaultStore,
    if (defaultStore != null) 'test_store': defaultStore,
    'stores': stores,
    // Products/orders: remote import only. Customers: local bootstrap cache.
    'asset_paths': {
      'orders': '',
      'products': '',
      'customers': localCustomersPath,
      if (remoteAssetsMap['offers'] != null) 'offers': remoteAssetsMap['offers'],
    },
    'default_login': remoteLoginMap,
  };
}

/// Pull timezone + country from device config / bootstrap / default store.
Map<String, dynamic> _localeFieldsFrom(
  Map<String, dynamic> remoteConfig,
  Map<String, dynamic> bootstrapPayload,
  Map<String, dynamic>? defaultStore,
) {
  final organisation = bootstrapPayload['organisation'];
  final orgMap =
      organisation is Map ? organisation.cast<String, dynamic>() : const {};

  String pick(List<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  final timezone = pick([
    remoteConfig['timezone'],
    remoteConfig['time_zone'],
    orgMap['timezone'],
    orgMap['time_zone'],
    defaultStore?['timezone'],
    defaultStore?['time_zone'],
  ]);
  final countryCode = pick([
    remoteConfig['country_code'],
    orgMap['country_code'],
    defaultStore?['country_code'],
  ]);
  final countryFlag = pick([
    remoteConfig['country_flag'],
    remoteConfig['flag'],
    orgMap['country_flag'],
    orgMap['flag'],
    defaultStore?['country_flag'],
    defaultStore?['flag'],
  ]);
  final countryName = pick([
    remoteConfig['country_name'],
    orgMap['country_name'],
    defaultStore?['country_name'],
  ]);
  final currencyCode = pick([
    remoteConfig['currency_code'],
    orgMap['currency_code'],
    defaultStore?['currency_code'],
  ]);
  final currencySymbol = pick([
    remoteConfig['currency_symbol'],
    orgMap['currency_symbol'],
    defaultStore?['currency_symbol'],
  ]);
  final currencyName = pick([
    remoteConfig['currency_name'],
    orgMap['currency_name'],
    defaultStore?['currency_name'],
  ]);

  return {
    if (timezone.isNotEmpty) 'timezone': timezone,
    if (timezone.isNotEmpty) 'time_zone': timezone,
    if (countryCode.isNotEmpty) 'country_code': countryCode,
    if (countryFlag.isNotEmpty) 'country_flag': countryFlag,
    if (countryName.isNotEmpty) 'country_name': countryName,
    if (currencyCode.isNotEmpty) 'currency_code': currencyCode,
    if (currencySymbol.isNotEmpty) 'currency_symbol': currencySymbol,
    if (currencyName.isNotEmpty) 'currency_name': currencyName,
    if (orgMap.isNotEmpty) 'organisation': {
      ...orgMap,
      if (timezone.isNotEmpty) 'timezone': timezone,
      if (timezone.isNotEmpty) 'time_zone': timezone,
      if (countryCode.isNotEmpty) 'country_code': countryCode,
      if (countryFlag.isNotEmpty) 'country_flag': countryFlag,
      if (countryName.isNotEmpty) 'country_name': countryName,
      if (currencyCode.isNotEmpty) 'currency_code': currencyCode,
      if (currencySymbol.isNotEmpty) 'currency_symbol': currencySymbol,
      if (currencyName.isNotEmpty) 'currency_name': currencyName,
    },
  };
}

String encodePretty(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

String _nonEmpty(Object? value, String fallback) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}
