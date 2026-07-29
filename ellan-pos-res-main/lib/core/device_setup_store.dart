import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/discovery_constants.dart';
import 'offline_pos_config.dart';
import 'org_timezone.dart';

/// One saved gateway target: server host + organisation instance id.
class PosServerEntry {
  final String serverUrl;
  final String orgInstanceId;

  const PosServerEntry({
    required this.serverUrl,
    required this.orgInstanceId,
  });

  String get displayLabel {
    final origin = discoveryOrigin(serverUrl);
    final org = orgInstanceId.trim();
    if (org.isEmpty) return origin;
    return '$origin · $org';
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'orgInstanceId': orgInstanceId,
      };

  factory PosServerEntry.fromJson(Map<String, dynamic> json) {
    return PosServerEntry(
      serverUrl: '${json['serverUrl'] ?? ''}'.trim(),
      orgInstanceId: '${json['orgInstanceId'] ?? ''}'.trim(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PosServerEntry &&
        other.serverUrl == serverUrl &&
        other.orgInstanceId == orgInstanceId;
  }

  @override
  int get hashCode => Object.hash(serverUrl, orgInstanceId);
}

/// Local persistence for the one-time POS device setup.
///
/// First launch (online): device registration → bootstrap → login → catalogue
/// sync. After [isCatalogSynced] the tablet boots offline; opening a store
/// listed in [syncedStoreIds] needs no network.
class DeviceSetupStore {
  static const orgCodeKey = 'orgCode';
  static const setupCompleteKey = 'deviceSetupComplete';
  static const catalogSyncedKey = 'posCatalogSynced';
  static const deviceApprovedKey = 'posDeviceApproved';
  static const configJsonKey = 'cachedStoreConfigJson';
  static const bootstrapJsonKey = 'cachedBootstrapJson';
  static const organisationLoginKey = 'cachedOrganisationLoginJson';
  static const syncedStoreIdsKey = 'posSyncedStoreIds';
  static const serverEntriesKey = 'posServerEntries';
  static const activeServerUrlKey = 'posActiveServerUrl';
  static const activeOrgInstanceIdKey = 'posActiveOrgInstanceId';
  /// Shared with [DeviceSettingsStore.lastSyncAtKey].
  static const lastSuccessfulSyncAtKey = 'posLastSuccessfulSyncAt';

  final SharedPreferences prefs;

  DeviceSetupStore(this.prefs);

  bool get isSetupComplete => prefs.getBool(setupCompleteKey) == true;

  /// True once the first-launch catalogue import has finished successfully.
  bool get isCatalogSynced => prefs.getBool(catalogSyncedKey) == true;

  /// Stores whose catalogue has already been pulled onto this device.
  List<String> get syncedStoreIds =>
      prefs.getStringList(syncedStoreIdsKey) ?? const [];

  bool isCatalogSyncedForStore(String storeId) =>
      syncedStoreIds.contains(storeId);

  Future<void> markCatalogSyncedForStore(String storeId) async {
    final synced = syncedStoreIds.toList();
    if (!synced.contains(storeId)) {
      synced.add(storeId);
      await prefs.setStringList(syncedStoreIdsKey, synced);
    }
  }

  bool get isDeviceApproved => prefs.getBool(deviceApprovedKey) == true;

  /// First launch is unfinished until catalogue has been synced online.
  bool get needsOnlineFirstLaunch => isSetupComplete && !isCatalogSynced;

  String? get orgCode => prefs.getString(orgCodeKey);

  Future<Directory> _setupDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/pos_device_setup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> customersFile() async {
    final dir = await _setupDir();
    return File('${dir.path}/bootstrap_customers.json');
  }

  Future<File> bootstrapFile() async {
    final dir = await _setupDir();
    return File('${dir.path}/bootstrap.json');
  }

  Future<File> configFile() async {
    final dir = await _setupDir();
    return File('${dir.path}/store_config.json');
  }

  /// Persist bootstrap + first-launch config (catalogue import URLs still on).
  Future<void> saveSetup({
    required String orgCode,
    required Map<String, dynamic> bootstrapPayload,
    required Map<String, dynamic> setupConfig,
    bool deviceApproved = true,
  }) async {
    final customersPayload = <String, dynamic>{
      'data': bootstrapPayload['data'] ?? const [],
      'store_roles': bootstrapPayload['store_roles'] ?? const [],
      'org_roles': bootstrapPayload['org_roles'] ?? const [],
    };

    final bootstrapPath = await bootstrapFile();
    final configPath = await configFile();
    final customersPath = await customersFile();

    await bootstrapPath.writeAsString(jsonEncode(bootstrapPayload));
    final sanitizedConfig = sanitizeStoreConfigJson(setupConfig);
    await configPath.writeAsString(jsonEncode(sanitizedConfig));
    await customersPath.writeAsString(jsonEncode(customersPayload));

    await prefs.setString(orgCodeKey, orgCode);
    await prefs.setString(bootstrapJsonKey, jsonEncode(bootstrapPayload));
    await prefs.setString(configJsonKey, jsonEncode(sanitizedConfig));
    await prefs.setString('cachedCustomersPath', customersPath.path);
    await prefs.setBool(setupCompleteKey, true);
    await prefs.setBool(deviceApprovedKey, deviceApproved);
    await prefs.setBool(catalogSyncedKey, false);
    await prefs.setStringList(syncedStoreIdsKey, const []);
  }

  /// After a catalogue import, drop the bootstrap/auth URLs so cold starts run
  /// offline. Catalogue import URLs stay for stores not yet synced.
  Future<void> sealOfflineAfterCatalogSync() async {
    final current = loadCachedConfigJson();
    if (current == null) {
      throw StateError('No cached POS config to seal offline.');
    }
    final offline = sealOfflinePosConfig(current);
    final repaired = ensureCatalogImportUrls(sanitizeStoreConfigJson(offline));
    final configPath = await configFile();
    await configPath.writeAsString(jsonEncode(repaired));
    await prefs.setString(configJsonKey, jsonEncode(repaired));
    await prefs.setBool(catalogSyncedKey, true);
  }

  Map<String, dynamic>? loadCachedConfigJson() {
    final raw = prefs.getString(configJsonKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    Map<String, dynamic>? config;
    if (decoded is Map<String, dynamic>) {
      config = decoded;
    } else if (decoded is Map) {
      config = decoded.cast<String, dynamic>();
    }
    if (config == null) return null;

    final withLocale = _backfillLocaleFields(config);
    final sanitized = ensureCatalogImportUrls(sanitizeStoreConfigJson(withLocale));
    // Persist repaired metadata so cold starts stop failing on blank logo/etc.
    if (jsonEncode(sanitized) != jsonEncode(config)) {
      // Fire-and-forget is fine for cold start; sign-in awaits [persistCachedConfig].
      prefs.setString(configJsonKey, jsonEncode(sanitized));
      configFile().then((file) => file.writeAsString(jsonEncode(sanitized)));
    }
    return sanitized;
  }

  /// Older cached configs dropped timezone / country; restore from bootstrap.
  Map<String, dynamic> _backfillLocaleFields(Map<String, dynamic> config) {
    final next = Map<String, dynamic>.from(config);
    final bootstrap = loadCachedBootstrapJson() ?? const <String, dynamic>{};
    final organisation = bootstrap['organisation'];
    final orgMap =
        organisation is Map ? organisation.cast<String, dynamic>() : const {};

    String pick(List<Object?> values) {
      for (final value in values) {
        final text = '${value ?? ''}'.trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    void ensureTop(String key, List<Object?> sources) {
      if ('${next[key] ?? ''}'.trim().isNotEmpty) return;
      final value = pick(sources);
      if (value.isNotEmpty) next[key] = value;
    }

    ensureTop('timezone', [
      orgMap['timezone'],
      orgMap['time_zone'],
      bootstrap['timezone'],
    ]);
    ensureTop('time_zone', [next['timezone'], orgMap['time_zone']]);
    ensureTop('country_code', [
      orgMap['country_code'],
      bootstrap['country_code'],
    ]);
    ensureTop('country_flag', [
      orgMap['country_flag'],
      orgMap['flag'],
      bootstrap['country_flag'],
    ]);
    ensureTop('country_name', [
      orgMap['country_name'],
      bootstrap['country_name'],
    ]);
    ensureTop('currency_code', [
      orgMap['currency_code'],
      bootstrap['currency_code'],
    ]);
    ensureTop('currency_symbol', [
      orgMap['currency_symbol'],
      bootstrap['currency_symbol'],
    ]);
    ensureTop('currency_name', [
      orgMap['currency_name'],
      bootstrap['currency_name'],
    ]);

    if (orgMap.isNotEmpty) {
      final existingOrg = next['organisation'];
      final mergedOrg = <String, dynamic>{
        ...orgMap,
        if (existingOrg is Map) ...existingOrg.cast<String, dynamic>(),
      };
      for (final key in [
        'timezone',
        'time_zone',
        'country_code',
        'country_flag',
        'country_name',
        'currency_code',
        'currency_symbol',
        'currency_name',
      ]) {
        if ('${mergedOrg[key] ?? ''}'.trim().isEmpty &&
            '${next[key] ?? ''}'.trim().isNotEmpty) {
          mergedOrg[key] = next[key];
        }
      }
      next['organisation'] = mergedOrg;
    }

    final stores = next['stores'];
    if (stores is List) {
      final bootStores = bootstrap['stores'];
      final fixedStores = <Map<String, dynamic>>[];
      for (final raw in stores) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw.cast<String, dynamic>());
        for (final key in [
          'timezone',
          'time_zone',
          'country_code',
          'country_flag',
          'country_name',
          'currency_code',
          'currency_symbol',
          'currency_name',
        ]) {
          if ('${row[key] ?? ''}'.trim().isEmpty &&
              '${next[key] ?? ''}'.trim().isNotEmpty) {
            row[key] = next[key];
          }
        }
        final sid = '${row['store_id'] ?? row['storeId'] ?? ''}'.trim();
        if (sid.isNotEmpty && bootStores is List) {
          for (final boot in bootStores) {
            if (boot is! Map) continue;
            final bootId =
                '${boot['store_id'] ?? boot['storeId'] ?? ''}'.trim();
            if (bootId != sid) continue;
            for (final key in [
              'timezone',
              'time_zone',
              'country_code',
              'country_flag',
              'country_name',
              'currency_code',
              'currency_symbol',
              'currency_name',
            ]) {
              if ('${row[key] ?? ''}'.trim().isEmpty) {
                final value = '${boot[key] ?? ''}'.trim();
                if (value.isNotEmpty) row[key] = value;
              }
            }
            break;
          }
        }
        fixedStores.add(row);
      }
      next['stores'] = fixedStores;
    }

    // Last resort: derive ISO code from timezone so the home flag can render.
    if ('${next['country_code'] ?? ''}'.trim().isEmpty) {
      final inferred = countryCodeFromTimezone(
        '${next['timezone'] ?? next['time_zone'] ?? ''}',
      );
      if (inferred.isNotEmpty) {
        next['country_code'] = inferred;
        next['country_flag'] = countryCodeToFlagEmoji(inferred);
      }
    }
    return next;
  }

  /// Awaitable write of a (usually already repaired) cached store config.
  Future<void> persistCachedConfig(Map<String, dynamic> config) async {
    final sanitized = ensureCatalogImportUrls(sanitizeStoreConfigJson(config));
    final encoded = jsonEncode(sanitized);
    await prefs.setString(configJsonKey, encoded);
    final configPath = await configFile();
    await configPath.writeAsString(encoded);
  }

  /// Merge store-wide credit defaults from a credits sync payload into cache.
  /// Also persists organisation currency when the gateway includes it (FK only).
  Future<void> mergeCreditSettings(Map<String, dynamic> creditSettings) async {
    final current = loadCachedConfigJson() ?? <String, dynamic>{};
    final next = Map<String, dynamic>.from(current);
    final creditsOnly = Map<String, dynamic>.from(creditSettings);
    final code = '${creditsOnly.remove('currency_code') ?? ''}'.trim();
    final symbol = '${creditsOnly.remove('currency_symbol') ?? ''}'.trim();
    final name = '${creditsOnly.remove('currency_name') ?? ''}'.trim();
    next['credit_settings'] = creditsOnly;

    if (code.isNotEmpty) next['currency_code'] = code;
    if (symbol.isNotEmpty) next['currency_symbol'] = symbol;
    if (name.isNotEmpty) next['currency_name'] = name;

    final organisation = next['organisation'];
    if (organisation is Map &&
        (code.isNotEmpty || symbol.isNotEmpty || name.isNotEmpty)) {
      final orgNext = Map<String, dynamic>.from(
        organisation.cast<String, dynamic>(),
      );
      if (code.isNotEmpty) orgNext['currency_code'] = code;
      if (symbol.isNotEmpty) orgNext['currency_symbol'] = symbol;
      if (name.isNotEmpty) orgNext['currency_name'] = name;
      next['organisation'] = orgNext;
    }

    // Keep bootstrap organisation in sync so cold starts see the same symbol.
    final bootstrap = loadCachedBootstrapJson();
    if (bootstrap != null &&
        (code.isNotEmpty || symbol.isNotEmpty || name.isNotEmpty)) {
      final bootNext = Map<String, dynamic>.from(bootstrap);
      if (code.isNotEmpty) bootNext['currency_code'] = code;
      if (symbol.isNotEmpty) bootNext['currency_symbol'] = symbol;
      if (name.isNotEmpty) bootNext['currency_name'] = name;
      final bootOrg = bootNext['organisation'];
      if (bootOrg is Map) {
        final bootOrgNext = Map<String, dynamic>.from(
          bootOrg.cast<String, dynamic>(),
        );
        if (code.isNotEmpty) bootOrgNext['currency_code'] = code;
        if (symbol.isNotEmpty) bootOrgNext['currency_symbol'] = symbol;
        if (name.isNotEmpty) bootOrgNext['currency_name'] = name;
        bootNext['organisation'] = bootOrgNext;
      }
      final encoded = jsonEncode(bootNext);
      await prefs.setString(bootstrapJsonKey, encoded);
      final bootstrapPath = await bootstrapFile();
      await bootstrapPath.writeAsString(encoded);
    }

    await persistCachedConfig(next);
  }

  Map<String, dynamic>? loadCachedBootstrapJson() {
    final raw = prefs.getString(bootstrapJsonKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return null;
  }

  String? get cachedCustomersPath => prefs.getString('cachedCustomersPath');

  /// Persist the last successful organisation login (includes password hash).
  /// Used for lease-valid silent cold starts when bootstrap hashes are stale.
  Future<void> saveOrganisationLogin(StoreOrganisationLoginResult login) async {
    await prefs.setString(organisationLoginKey, jsonEncode(login.toJson()));
  }

  StoreOrganisationLoginResult? loadOrganisationLogin() {
    final raw = prefs.getString(organisationLoginKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StoreOrganisationLoginResult.fromJson(
        decoded.cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached login when identifier/password still match the stored hash.
  StoreOrganisationLoginResult? loadOrganisationLoginForCredentials({
    required String email,
    required String password,
  }) {
    final cached = loadOrganisationLogin();
    if (cached == null) return null;
    if (cached.accessibleStores.isEmpty) return null;

    final key = email.trim().toLowerCase();
    final digits = key.replaceAll(RegExp(r'[^0-9]'), '');
    final cachedEmail = cached.email.trim().toLowerCase();
    final row = cached.customerRow ?? const <String, dynamic>{};
    final reg = '${row['usr_reg_num'] ?? row['reg_num'] ?? ''}'
        .trim()
        .toLowerCase();
    final phone = '${row['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    final matchesIdentifier = (cachedEmail.isNotEmpty && cachedEmail == key) ||
        (reg.isNotEmpty && (reg == key || (digits.isNotEmpty && reg == digits))) ||
        (digits.isNotEmpty &&
            phone.isNotEmpty &&
            (phone == digits ||
                (digits.length >= 7 &&
                    phone.length >= 7 &&
                    (phone.endsWith(digits) || digits.endsWith(phone)))));
    if (!matchesIdentifier) return null;

    final stored = '${row['password'] ?? ''}';
    if (stored.isEmpty) return null;
    final hashed = sha256.convert(utf8.encode(password)).toString();
    if (stored != hashed && stored != password) return null;
    return cached;
  }

  /// After online login, write the real offline password hash into the cached
  /// bootstrap so future local auth against bootstrap succeeds.
  Future<void> patchBootstrapOperatorCredential(
    StoreOrganisationLoginResult login,
  ) async {
    final password = '${login.customerRow?['password'] ?? ''}'.trim();
    if (password.isEmpty) return;

    final bootstrap = loadCachedBootstrapJson();
    if (bootstrap == null) return;

    final customerId = login.customerId.trim();
    final emailKey = login.email.trim().toLowerCase();
    final data = bootstrap['data'];
    if (data is! List) return;

    var changed = false;
    final updated = <dynamic>[];
    for (final row in data) {
      if (row is! Map) {
        updated.add(row);
        continue;
      }
      final map = Map<String, dynamic>.from(row);
      final rowId = '${map['customerId'] ?? ''}'.trim();
      final rowEmail = '${map['email'] ?? ''}'.trim().toLowerCase();
      final match = (customerId.isNotEmpty && rowId == customerId) ||
          (emailKey.isNotEmpty && rowEmail == emailKey);
      if (match) {
        map['password'] = password;
        changed = true;
      }
      updated.add(map);
    }
    if (!changed) return;

    final next = Map<String, dynamic>.from(bootstrap)..['data'] = updated;
    final encoded = jsonEncode(next);
    await prefs.setString(bootstrapJsonKey, encoded);
    final bootstrapPath = await bootstrapFile();
    await bootstrapPath.writeAsString(encoded);

    final customersPayload = <String, dynamic>{
      'data': updated,
      'store_roles': next['store_roles'] ?? const [],
      'org_roles': next['org_roles'] ?? const [],
    };
    final customersPath = await customersFile();
    await customersPath.writeAsString(jsonEncode(customersPayload));
    await prefs.setString('cachedCustomersPath', customersPath.path);
  }

  /// Persist a verified staff password into the organisation-login cache and
  /// bootstrap so offline unlock works for the rest of the lease.
  Future<void> persistVerifiedStaffCredential({
    required String identifier,
    required String password,
    String? customerId,
    String? email,
  }) async {
    final hash = sha256.convert(utf8.encode(password)).toString();
    final cached = loadOrganisationLogin();
    if (cached == null) return;

    final row = Map<String, dynamic>.from(
      cached.customerRow ?? const <String, dynamic>{},
    );
    row['password'] = hash;
    if ((email ?? '').trim().isNotEmpty) {
      row['email'] = email!.trim();
    }
    final phoneDigits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length >= 7 && '${row['phone'] ?? ''}'.trim().isEmpty) {
      row['phone'] = phoneDigits;
    }

    final updated = StoreOrganisationLoginResult(
      organisation: cached.organisation,
      customerId: (customerId ?? cached.customerId).trim().isNotEmpty
          ? (customerId ?? cached.customerId)
          : cached.customerId,
      customerName: cached.customerName,
      email: (email ?? cached.email).trim().isNotEmpty
          ? (email ?? cached.email)
          : cached.email,
      organisationRole: cached.organisationRole,
      accessibleStores: cached.accessibleStores,
      customerRow: row,
      accessToken: cached.accessToken,
      refreshToken: cached.refreshToken,
      sessionId: cached.sessionId,
      serviceInstanceId: cached.serviceInstanceId,
    );
    await saveOrganisationLogin(updated);
    await patchBootstrapOperatorCredential(updated);
  }

  /// 4-digit organisation POS code from the gateway config (if assigned).
  String? get posCode {
    final config = loadCachedConfigJson();
    final code = '${config?['pos_code'] ?? ''}'.trim();
    return code.isEmpty ? null : code;
  }

  /// IANA timezone for [storeId], falling back to org / config default.
  String? timezoneForStore(String? storeId) {
    final config = loadCachedConfigJson();
    if (config == null) return null;
    final sid = (storeId ?? '').trim();
    if (sid.isNotEmpty) {
      final stores = config['stores'];
      if (stores is List) {
        for (final row in stores) {
          if (row is! Map) continue;
          final id = '${row['storeId'] ?? row['store_id'] ?? ''}'.trim();
          if (id != sid) continue;
          final tz = '${row['timezone'] ?? row['time_zone'] ?? ''}'.trim();
          if (tz.isNotEmpty) return tz;
        }
      }
    }
    final top = '${config['timezone'] ?? config['time_zone'] ?? ''}'.trim();
    if (top.isNotEmpty) return top;
    final organisation = config['organisation'];
    if (organisation is Map) {
      final tz =
          '${organisation['timezone'] ?? organisation['time_zone'] ?? ''}'
              .trim();
      if (tz.isNotEmpty) return tz;
    }
    final bootstrap = loadCachedBootstrapJson();
    final bootOrg = bootstrap?['organisation'];
    if (bootOrg is Map) {
      final tz = '${bootOrg['timezone'] ?? bootOrg['time_zone'] ?? ''}'.trim();
      if (tz.isNotEmpty) return tz;
    }
    return null;
  }

  /// Organisation currency only — never invents `$` / USD.
  ({String code, String symbol, String name}) currencyMetaForStore(
    String? storeId,
  ) {
    String code = '';
    String symbol = '';
    String name = '';

    void take(Map row) {
      final nested = row['currency'];
      if (nested is Map) {
        final nestedCode =
            '${nested['currency_code'] ?? nested['code'] ?? ''}'.trim();
        final nestedSymbol =
            '${nested['currency_symbol'] ?? nested['symbol'] ?? ''}'.trim();
        final nestedName =
            '${nested['currency_name'] ?? nested['name'] ?? ''}'.trim();
        if (code.isEmpty && nestedCode.isNotEmpty) code = nestedCode;
        if (symbol.isEmpty && nestedSymbol.isNotEmpty) symbol = nestedSymbol;
        if (name.isEmpty && nestedName.isNotEmpty) name = nestedName;
      }
      final nextCode = '${row['currency_code'] ?? ''}'.trim();
      final nextSymbol = '${row['currency_symbol'] ?? ''}'.trim();
      final nextName = '${row['currency_name'] ?? ''}'.trim();
      if (code.isEmpty && nextCode.isNotEmpty) code = nextCode;
      if (symbol.isEmpty && nextSymbol.isNotEmpty) symbol = nextSymbol;
      if (name.isEmpty && nextName.isNotEmpty) name = nextName;
    }

    final config = loadCachedConfigJson();
    // Prefer organisation currency over store/country inferences.
    if (config != null) {
      final organisation = config['organisation'];
      if (organisation is Map) take(organisation);
      take(config);
      final defaultStore = config['default_store'];
      if (defaultStore is Map) take(defaultStore);
    }
    final bootstrap = loadCachedBootstrapJson();
    final bootOrg = bootstrap?['organisation'];
    if (bootOrg is Map) take(bootOrg);
    if (bootstrap != null) take(bootstrap);

    final sid = (storeId ?? '').trim();
    if (config != null && sid.isNotEmpty && symbol.isEmpty && code.isEmpty) {
      final stores = config['stores'];
      if (stores is List) {
        for (final row in stores) {
          if (row is! Map) continue;
          final id = '${row['storeId'] ?? row['store_id'] ?? ''}'.trim();
          if (id == sid) {
            take(row);
            break;
          }
        }
      }
    }
    // Last resort: any store row that carries currency.
    if (config != null && symbol.isEmpty && code.isEmpty) {
      final stores = config['stores'];
      if (stores is List) {
        for (final row in stores) {
          if (row is! Map) continue;
          take(row);
          if (symbol.isNotEmpty || code.isNotEmpty) break;
        }
      }
    }

    return (code: code, symbol: symbol, name: name);
  }

  /// Display symbol for amounts: org symbol, else code — never `$` fallback.
  String currencySymbolForStore(String? storeId) {
    final meta = currencyMetaForStore(storeId);
    if (meta.symbol.isNotEmpty) return meta.symbol;
    return meta.code;
  }

  /// Country flag emoji / code for [storeId] (org fallback).
  ({String flag, String code, String name}) countryMetaForStore(String? storeId) {
    String flag = '';
    String code = '';
    String name = '';

    void take(Map row) {
      final nextFlag = '${row['country_flag'] ?? row['flag'] ?? ''}'.trim();
      final nextCode = '${row['country_code'] ?? ''}'.trim();
      final nextName = '${row['country_name'] ?? ''}'.trim();
      if (flag.isEmpty && nextFlag.isNotEmpty) flag = nextFlag;
      if (code.isEmpty && nextCode.isNotEmpty) code = nextCode;
      if (name.isEmpty && nextName.isNotEmpty) name = nextName;
    }

    final config = loadCachedConfigJson();
    final sid = (storeId ?? '').trim();
    if (config != null && sid.isNotEmpty) {
      final stores = config['stores'];
      if (stores is List) {
        for (final row in stores) {
          if (row is! Map) continue;
          final id = '${row['storeId'] ?? row['store_id'] ?? ''}'.trim();
          if (id == sid) {
            take(row);
            break;
          }
        }
      }
    }
    if (config != null) {
      take(config);
      final organisation = config['organisation'];
      if (organisation is Map) take(organisation);
    }
    final bootstrap = loadCachedBootstrapJson();
    final bootOrg = bootstrap?['organisation'];
    if (bootOrg is Map) take(bootOrg);

    if (flag.isEmpty && code.length == 2) {
      flag = countryCodeToFlagEmoji(code);
    }
    if (code.isEmpty) {
      final tz = timezoneForStore(storeId);
      final inferred = countryCodeFromTimezone(tz);
      if (inferred.isNotEmpty) {
        code = inferred;
        if (flag.isEmpty) flag = countryCodeToFlagEmoji(code);
      }
    }
    return (flag: flag, code: code, name: name);
  }

  /// Default net terms from branch credit settings (gateway config).
  int get creditNetDays {
    final config = loadCachedConfigJson();
    final settings = config?['credit_settings'];
    if (settings is Map) {
      final raw = settings['credit_net_days'];
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse('${raw ?? ''}');
      if (parsed != null && parsed >= 0) return parsed;
    }
    return 14;
  }

  Map<String, dynamic>? get _creditSettings {
    final settings = loadCachedConfigJson()?['credit_settings'];
    return settings is Map ? settings.cast<String, dynamic>() : null;
  }

  /// Optional per-customer outstanding limit from branch credit settings.
  double? get creditLimitAmount {
    final raw = _creditSettings?['credit_limit_amount'];
    if (raw == null || '$raw'.trim().isEmpty) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw');
  }

  /// When true, tablet/portal reject credit sales that would exceed the limit.
  bool get creditLimitHardBlock =>
      _creditSettings?['credit_limit_hard_block'] == true;

  DateTime? lastSuccessfulSyncAt() {
    final raw = prefs.getString(lastSuccessfulSyncAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markSyncSucceeded([DateTime? when]) async {
    await prefs.setString(
      lastSuccessfulSyncAtKey,
      (when ?? DateTime.now()).toIso8601String(),
    );
  }

  /// Saved server URL + organisation instance id pairs on this device.
  List<PosServerEntry> listServerEntries() {
    final raw = prefs.getString(serverEntriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => PosServerEntry.fromJson(row.cast<String, dynamic>()))
          .where(
            (entry) =>
                entry.serverUrl.trim().isNotEmpty &&
                entry.orgInstanceId.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? get activeServerUrl {
    final value = prefs.getString(activeServerUrlKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? get activeOrgInstanceId {
    final value = prefs.getString(activeOrgInstanceIdKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Restores the last-used gateway into the process-wide discovery URL.
  void restoreActiveDiscoveryUrl() {
    final stored = activeServerUrl;
    if (stored != null) {
      setActiveDiscoveryUrl(stored);
    }
  }

  /// Upserts [entry] into the local dropdown list and marks it active.
  Future<void> saveServerEntry(PosServerEntry entry) async {
    final normalized = PosServerEntry(
      serverUrl: normalizeDiscoveryUrl(entry.serverUrl),
      orgInstanceId: entry.orgInstanceId.trim(),
    );
    if (normalized.serverUrl.isEmpty || normalized.orgInstanceId.isEmpty) {
      throw ArgumentError('Server URL and organisation instance id are required.');
    }

    final next = <PosServerEntry>[normalized];
    for (final existing in listServerEntries()) {
      final sameServer =
          normalizeDiscoveryUrl(existing.serverUrl) == normalized.serverUrl;
      final sameOrg = existing.orgInstanceId.trim() == normalized.orgInstanceId;
      if (sameServer && sameOrg) continue;
      next.add(existing);
    }

    await prefs.setString(
      serverEntriesKey,
      jsonEncode(next.map((row) => row.toJson()).toList(growable: false)),
    );
    await prefs.setString(activeServerUrlKey, normalized.serverUrl);
    await prefs.setString(activeOrgInstanceIdKey, normalized.orgInstanceId);
    setActiveDiscoveryUrl(normalized.serverUrl);
  }

  /// Removes a saved entry. Clears the active selection when it matched.
  Future<void> deleteServerEntry(PosServerEntry entry) async {
    final targetUrl = normalizeDiscoveryUrl(entry.serverUrl);
    final targetOrg = entry.orgInstanceId.trim();
    final next = listServerEntries()
        .where(
          (row) =>
              !(normalizeDiscoveryUrl(row.serverUrl) == targetUrl &&
                  row.orgInstanceId.trim() == targetOrg),
        )
        .toList(growable: false);

    await prefs.setString(
      serverEntriesKey,
      jsonEncode(next.map((row) => row.toJson()).toList(growable: false)),
    );

    final activeUrl = activeServerUrl;
    final activeOrg = activeOrgInstanceId;
    if (activeUrl != null &&
        activeOrg != null &&
        normalizeDiscoveryUrl(activeUrl) == targetUrl &&
        activeOrg == targetOrg) {
      await prefs.remove(activeServerUrlKey);
      await prefs.remove(activeOrgInstanceIdKey);
      clearActiveDiscoveryUrl();
    }
  }

  /// Marks an existing list entry as the active gateway for setup / cold start.
  Future<void> setActiveServerEntry(PosServerEntry entry) async {
    final normalized = PosServerEntry(
      serverUrl: normalizeDiscoveryUrl(entry.serverUrl),
      orgInstanceId: entry.orgInstanceId.trim(),
    );
    await prefs.setString(activeServerUrlKey, normalized.serverUrl);
    await prefs.setString(activeOrgInstanceIdKey, normalized.orgInstanceId);
    setActiveDiscoveryUrl(normalized.serverUrl);
  }
}
