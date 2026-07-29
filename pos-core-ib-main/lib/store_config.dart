import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'store_models.dart';

enum StoreEnvironment { development, test, production }

class StoreConfig {
  static const String developmentAssetPath =
      'fixtures/config/store_config.dev.json';
  static const String testAssetPath = 'fixtures/config/store_config.test.json';
  static const String productionAssetPath =
      'fixtures/config/store_config.production.json';
  static const String defaultAssetPath = developmentAssetPath;

  final String dbNameId;
  final StoreBootstrapConfig bootstrap;
  final StoreSyncConfig sync;
  final int sessionDurationHours;
  final StoreMetadataConfig? defaultStore;
  final StoreMetadataConfig? testStore;
  final List<StoreMetadataConfig> stores;
  final StoreAssetPathsConfig assetPaths;
  final StoreAuthConfig defaultLogin;

  const StoreConfig({
    required this.dbNameId,
    required this.bootstrap,
    required this.sync,
    required this.sessionDurationHours,
    required this.defaultStore,
    required this.testStore,
    required this.stores,
    required this.assetPaths,
    required this.defaultLogin,
  });

  static const StoreMetadataConfig defaultTestStoreMetadata =
      StoreMetadataConfig(
        orgId: 'org_001',
        orgName: 'Ellan Test Organisation',
        orgCode: '100001',
        storeId: 'store_001',
        serviceInstanceId: 1,
        storeName: 'Test Store',
        logo: 'logo.png',
        uniqueId: '12345678',
        contactEmail: 'test@store.com',
        phone: '+1234567890',
        contactPerson: 'Test Person',
        status: 'active',
        serviceVariantType: 'standard',
      );

  Duration get defaultSessionDuration => Duration(hours: sessionDurationHours);

  String buildDatabaseFileName(String databaseKey) =>
      '${dbNameId}_$databaseKey.db';

  String buildOrganisationDatabaseFileName(String orgId) =>
      buildDatabaseFileName(orgId);

  List<StoreOrganisation> get organisations {
    final organisationsById = <String, StoreOrganisation>{};
    for (final store in stores) {
      organisationsById[store.orgId] = StoreOrganisation(
        orgId: store.orgId,
        remoteId: store.organisationRemoteId,
        orgName: store.orgName,
        orgCode: store.orgCode,
        logo: store.logo,
      );
    }
    return organisationsById.values.toList(growable: false);
  }

  StoreOrganisation? findOrganisationByCode(String orgCode) {
    for (final organisation in organisations) {
      if (organisation.orgCode == orgCode) {
        return organisation;
      }
    }
    return null;
  }

  List<StoreMetadataConfig> storesForOrganisation(String orgId) {
    return stores
        .where((store) => store.orgId == orgId)
        .toList(growable: false);
  }

  StoreMetadataConfig? findStoreById(String orgId, String storeId) {
    for (final store in stores) {
      if (store.orgId == orgId && store.storeId == storeId) {
        return store;
      }
    }
    return null;
  }

  static String assetPathForEnvironment(StoreEnvironment environment) {
    switch (environment) {
      case StoreEnvironment.development:
        return developmentAssetPath;
      case StoreEnvironment.test:
        return testAssetPath;
      case StoreEnvironment.production:
        return productionAssetPath;
    }
  }

  static Future<StoreConfig> loadFromFile([
    String filePath = defaultAssetPath,
  ]) async {
    final content = await File(filePath).readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return StoreConfig.fromJson(json);
  }

  static Future<StoreConfig> loadForEnvironment(StoreEnvironment environment) {
    return loadFromFile(assetPathForEnvironment(environment));
  }

  static Future<StoreConfig> loadRemoteForOrganisation({
    required String orgCode,
    required String lookupUrl,
  }) async {
    final payload = await _fetchBootstrapPayload(
      lookupUrl: lookupUrl,
      orgCode: orgCode,
    );
    if (payload == null) {
      throw StateError(
        'Organisation bootstrap was not found for orgCode=$orgCode.',
      );
    }
    return _loadRemoteFromBootstrapPayload(payload, lookupUrl: lookupUrl);
  }

  static Future<StoreConfig> loadRemoteForOrganisationId({
    required String orgId,
    required String lookupUrl,
  }) async {
    final payload = await _fetchBootstrapPayload(
      lookupUrl: lookupUrl,
      orgId: orgId,
    );
    if (payload == null) {
      throw StateError(
        'Organisation bootstrap was not found for orgId=$orgId.',
      );
    }
    return _loadRemoteFromBootstrapPayload(payload, lookupUrl: lookupUrl);
  }

  static Future<StoreConfig> _loadRemoteFromBootstrapPayload(
    Map<String, dynamic> payload, {
    required String lookupUrl,
  }) async {
    final inlineConfig = _optionalMap(payload, 'config');
    if (inlineConfig != null) {
      return StoreConfig.fromJson(inlineConfig);
    }

    final configUrl = _optionalString(payload, 'config_url');
    if (configUrl != null && configUrl.isNotEmpty) {
      final resolvedUrl = _resolveRelativeUrl(
        baseUrl: lookupUrl,
        rawUrl: configUrl,
      );
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Remote config lookup failed with status ${response.statusCode}.',
        );
      }
      return StoreConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw StateError(
      'Bootstrap payload does not include config or config_url.',
    );
  }

  factory StoreConfig.fromJson(Map<String, dynamic> json) {
    return StoreConfig(
      dbNameId: _requireString(json, 'db_name_id'),
      bootstrap: StoreBootstrapConfig.fromJson(
        _optionalMap(json, 'bootstrap') ?? const {},
        baseUrl: _optionalString(_requireMap(json, 'sync'), 'base_url') ?? '',
      ),
      sync: StoreSyncConfig.fromJson(_requireMap(json, 'sync')),
      sessionDurationHours: _requireInt(json, 'session_duration_hours'),
      defaultStore: _optionalMetadata(json, 'default_store'),
      testStore: _optionalMetadata(json, 'test_store'),
      stores: _parseStores(json),
      assetPaths: StoreAssetPathsConfig.fromJson(
        _requireMap(json, 'asset_paths'),
      ),
      defaultLogin: StoreAuthConfig.fromJson(
        _requireMap(json, 'default_login'),
      ),
    );
  }
}

Future<Map<String, dynamic>?> _fetchBootstrapPayload({
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

String _resolveRelativeUrl({required String baseUrl, required String rawUrl}) {
  final candidate = Uri.parse(rawUrl);
  if (candidate.hasScheme) {
    return rawUrl;
  }
  return Uri.parse(baseUrl).resolveUri(candidate).toString();
}

List<StoreMetadataConfig> _parseStores(Map<String, dynamic> json) {
  final rawStores = json['stores'];
  if (rawStores is List) {
    return rawStores
        .whereType<Map<String, dynamic>>()
        .map(StoreMetadataConfig.fromJson)
        .toList(growable: false);
  }

  final fallback = [
    _optionalMetadata(json, 'default_store'),
    _optionalMetadata(json, 'test_store'),
  ].whereType<StoreMetadataConfig>();
  final uniqueStores = <String, StoreMetadataConfig>{};
  for (final store in fallback) {
    uniqueStores['${store.orgId}:${store.storeId}'] = store;
  }
  return uniqueStores.values.toList(growable: false);
}

StoreMetadataConfig? _optionalMetadata(Map<String, dynamic> json, String key) {
  final value = _optionalMap(json, key);
  if (value == null) {
    return null;
  }
  return StoreMetadataConfig.fromJson(value);
}

class StoreBootstrapConfig {
  final String lookupUrl;
  final String deviceRegistrationUrl;
  final String loginUrl;

  const StoreBootstrapConfig({
    required this.lookupUrl,
    required this.deviceRegistrationUrl,
    this.loginUrl = '',
  });

  bool get isConfigured => lookupUrl.isNotEmpty;
  bool get requiresDeviceRegistration => deviceRegistrationUrl.isNotEmpty;
  bool get requiresRemoteLogin => loginUrl.isNotEmpty;

  factory StoreBootstrapConfig.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final absoluteLookup = _optionalString(json, 'lookup_url');
    final lookupPath = _optionalString(json, 'lookup_path');
    // Explicit empty lookup_url (and no path) disables remote bootstrap —
    // used by offline POS after one-time device setup.
    final lookupDisabled = json.containsKey('lookup_url') &&
        (absoluteLookup == null || absoluteLookup.isEmpty) &&
        lookupPath == null;

    return StoreBootstrapConfig(
      lookupUrl: lookupDisabled
          ? ''
          : _resolveSyncUrl(
              baseUrl: baseUrl,
              absoluteUrl: absoluteLookup,
              path: lookupPath ??
                  (json.containsKey('lookup_url') ||
                          json.containsKey('lookup_path')
                      ? null
                      : '/api/bootstrap'),
            ),
      deviceRegistrationUrl: _resolveSyncUrl(
        baseUrl: baseUrl,
        absoluteUrl: _optionalString(json, 'device_registration_url'),
        path: _optionalString(json, 'device_registration_path'),
      ),
      loginUrl: _resolveSyncUrl(
        baseUrl: baseUrl,
        absoluteUrl: _optionalString(json, 'login_url'),
        path: _optionalString(json, 'login_path'),
      ),
    );
  }
}

class StoreSyncConfig {
  final String baseUrl;
  final bool autoSyncEnabled;
  final int periodicDurationSeconds;
  final StoreSyncEndpointConfig orders;
  final StoreSyncEndpointConfig products;
  final StoreSyncEndpointConfig customers;
  final StoreSyncEndpointConfig credits;
  final StoreSyncEndpointConfig tables;
  final StoreSyncEndpointConfig wallets;
  final StoreSyncEndpointConfig offers;
  final StoreSyncEndpointConfig subscribers;

  const StoreSyncConfig({
    required this.baseUrl,
    required this.autoSyncEnabled,
    required this.periodicDurationSeconds,
    required this.orders,
    required this.products,
    required this.customers,
    required this.credits,
    required this.tables,
    required this.wallets,
    this.offers = const StoreSyncEndpointConfig(
      importUrl: '',
      exportUrl: '',
      exportToken: '',
      importBatchSize: 500,
    ),
    this.subscribers = const StoreSyncEndpointConfig(
      importUrl: '',
      exportUrl: '',
      exportToken: '',
      importBatchSize: 500,
    ),
  });

  Duration get periodicDuration => Duration(seconds: periodicDurationSeconds);

  factory StoreSyncConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = _optionalString(json, 'base_url') ?? '';
    return StoreSyncConfig(
      baseUrl: baseUrl,
      autoSyncEnabled: _requireBool(json, 'auto_sync_enabled'),
      periodicDurationSeconds: _requireInt(json, 'periodic_duration_seconds'),
      orders: StoreSyncEndpointConfig.fromJson(
        _requireMap(json, 'orders'),
        baseUrl: baseUrl,
      ),
      products: StoreSyncEndpointConfig.fromJson(
        _requireMap(json, 'products'),
        baseUrl: baseUrl,
      ),
      customers: StoreSyncEndpointConfig.fromJson(
        _requireMap(json, 'customers'),
        baseUrl: baseUrl,
      ),
      credits: StoreSyncEndpointConfig.fromJson(
        _optionalMap(json, 'credits') ?? const {},
        baseUrl: baseUrl,
      ),
      tables: StoreSyncEndpointConfig.fromJson(
        _optionalMap(json, 'tables') ?? const {},
        baseUrl: baseUrl,
      ),
      wallets: StoreSyncEndpointConfig.fromJson(
        _optionalMap(json, 'wallets') ?? const {},
        baseUrl: baseUrl,
      ),
      offers: StoreSyncEndpointConfig.fromJson(
        _optionalMap(json, 'offers') ?? const {},
        baseUrl: baseUrl,
      ),
      subscribers: StoreSyncEndpointConfig.fromJson(
        _optionalMap(json, 'subscribers') ?? const {},
        baseUrl: baseUrl,
      ),
    );
  }
}

class StoreSyncEndpointConfig {
  final String importUrl;
  final String exportUrl;
  final String exportToken;
  final int importBatchSize;

  const StoreSyncEndpointConfig({
    required this.importUrl,
    required this.exportUrl,
    required this.exportToken,
    required this.importBatchSize,
  });

  bool get canImport => importUrl.isNotEmpty;
  bool get canExport => exportUrl.isNotEmpty;

  factory StoreSyncEndpointConfig.fromJson(
    Map<String, dynamic> json, {
    String baseUrl = '',
  }) {
    return StoreSyncEndpointConfig(
      importUrl: _resolveSyncUrl(
        baseUrl: baseUrl,
        absoluteUrl: _optionalString(json, 'import_url'),
        path: _optionalString(json, 'import_path'),
      ),
      exportUrl: _resolveSyncUrl(
        baseUrl: baseUrl,
        absoluteUrl: _optionalString(json, 'export_url'),
        path: _optionalString(json, 'export_path'),
      ),
      exportToken: _optionalString(json, 'export_token') ?? '',
      importBatchSize: _optionalInt(json, 'import_batch_size') ?? 500,
    );
  }
}

String _resolveSyncUrl({
  required String baseUrl,
  required String? absoluteUrl,
  required String? path,
}) {
  if (absoluteUrl != null && absoluteUrl.isNotEmpty) {
    return absoluteUrl;
  }
  if (path != null && path.isNotEmpty) {
    if (baseUrl.isEmpty) {
      throw FormatException(
        'sync.base_url is required when import_path/export_path is used.',
      );
    }
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }
  return '';
}

class StoreMetadataConfig {
  final String orgId;
  final String? organisationRemoteId;
  final String orgName;
  final String orgCode;
  final String storeId;
  final String? storeRemoteId;
  final int serviceInstanceId;
  final String storeName;
  final String logo;
  final String uniqueId;
  final String contactEmail;
  final String phone;
  final String contactPerson;
  final String status;
  final String serviceVariantType;

  const StoreMetadataConfig({
    required this.orgId,
    this.organisationRemoteId,
    required this.orgName,
    required this.orgCode,
    required this.storeId,
    this.storeRemoteId,
    required this.serviceInstanceId,
    required this.storeName,
    required this.logo,
    required this.uniqueId,
    required this.contactEmail,
    required this.phone,
    required this.contactPerson,
    required this.status,
    required this.serviceVariantType,
  });

  factory StoreMetadataConfig.fromJson(Map<String, dynamic> json) {
    return StoreMetadataConfig(
      orgId: _requireString(json, 'org_id'),
      organisationRemoteId:
          _optionalString(json, 'org_remote_id') ??
          _optionalString(json, 'org_id'),
      orgName: _requireString(json, 'org_name'),
      orgCode: _requireSixDigitCode(json, 'org_code'),
      storeId: _requireString(json, 'store_id'),
      storeRemoteId:
          _optionalString(json, 'remote_id') ??
          _optionalString(json, 'store_id'),
      serviceInstanceId: _requireInt(json, 'service_instance_id'),
      storeName: _requireString(json, 'store_name'),
      logo: _requireString(json, 'logo'),
      uniqueId: _requireString(json, 'unique_id'),
      contactEmail: _requireString(json, 'contact_email'),
      phone: _requireString(json, 'phone'),
      contactPerson: _requireString(json, 'contact_person'),
      status: _requireString(json, 'status'),
      serviceVariantType: _requireString(json, 'service_variant_type'),
    );
  }

  StoreDirectoryEntry toDirectoryEntry() {
    return StoreDirectoryEntry(
      orgId: orgId,
      orgName: orgName,
      orgCode: orgCode,
      storeId: storeId,
      remoteId: storeRemoteId,
      serviceInstanceId: serviceInstanceId,
      storeName: storeName,
      logo: logo,
      uniqueId: uniqueId,
      contactEmail: contactEmail,
      phone: phone,
      contactPerson: contactPerson,
      status: status,
      serviceVariantType: serviceVariantType,
    );
  }
}

class StoreAssetPathsConfig {
  final String orders;
  final String products;
  final String customers;
  final String? offers;

  const StoreAssetPathsConfig({
    required this.orders,
    required this.products,
    required this.customers,
    required this.offers,
  });

  factory StoreAssetPathsConfig.fromJson(Map<String, dynamic> json) {
    return StoreAssetPathsConfig(
      // Orders/products are pulled from the remote gateway — empty paths mean
      // "do not seed from local fixture files".
      orders: _requireStringAllowEmpty(json, 'orders'),
      products: _requireStringAllowEmpty(json, 'products'),
      customers: _requireString(json, 'customers'),
      offers: _optionalString(json, 'offers'),
    );
  }
}

class StoreAuthConfig {
  final String email;
  final String password;

  const StoreAuthConfig({required this.email, required this.password});

  factory StoreAuthConfig.fromJson(Map<String, dynamic> json) {
    return StoreAuthConfig(
      email: _requireString(json, 'email'),
      password: _requireString(json, 'password'),
    );
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

String _requireStringAllowEmpty(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

String _requireSixDigitCode(Map<String, dynamic> json, String key) {
  final value = _requireString(json, key);
  final sixDigits = RegExp(r'^\d{6}$');
  if (sixDigits.hasMatch(value)) {
    return value;
  }
  throw FormatException(
    'Missing or invalid "$key" in store configuration. Expected a unique 6-digit code.',
  );
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected "$key" to be an integer.');
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw FormatException('Missing or invalid "$key" in store configuration.');
}
