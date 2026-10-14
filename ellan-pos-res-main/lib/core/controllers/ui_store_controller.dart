import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pos_orders_offline/sqflite_ffi_io.dart';
import 'package:pos_orders_offline/store.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_orders_offline/store_offer_engine.dart';
import 'checkout_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/discovery_constants.dart';
import '../currency_format.dart';
import '../device_local_reset.dart';
import '../device_settings_store.dart';
import '../device_setup_store.dart';
import '../di/service_locator.dart';
import '../login_lease_store.dart';
import '../network_reachability.dart';
import '../order_types_repository.dart';
import '../device_approval.dart';
import '../org_timezone.dart';
import '../pos_checkout_meta.dart';
import '../pos_lock_pin.dart';
import '../pos_report_mailer_defaults.dart';

export 'checkout_models.dart';
export '../device_local_reset.dart' show DeviceLocalResetResult;
export '../order_types_repository.dart' show PosOrderType;

class UiStoreController {
  static const String developmentAssetPath = 'config/store_config.dev.json';
  static const String testAssetPath = 'config/store_config.test.json';
  static const String productionAssetPath =
      'config/store_config.production.json';

  StoreConfig? _config;
  StoreOrganisation? _organisation;
  StoreOrganisationLoginResult? _organisationLogin;
  StoreOrganisationBootstrapSyncResult? _bootstrap;
  StoreDeviceRegistrationRequest? _deviceRegistration;
  Store? _store;
  Timer? _deviceAutoSyncTimer;
  bool _deviceAutoSyncInProgress = false;
  Future<void>? _syncInFlight;
  bool _deviceSyncBlocked = false;

  /// True after an auto-sync (or last sync) failure; cleared on success.
  final ValueNotifier<bool> autoSyncFailed = ValueNotifier(false);

  Store? get store => _store;
  StoreOrganisation? get organisation => _organisation;
  StoreOrganisationLoginResult? get organisationLogin => _organisationLogin;
  StoreOrganisationBootstrapSyncResult? get bootstrap => _bootstrap;

  Future<void> boot({
    StoreEnvironment environment = StoreEnvironment.development,
  }) async {
    _config = await loadForEnvironment(environment);
  }

  Future<void> bootWithConfig(StoreConfig config) async {
    _config = config;
  }

  Future<StoreConfig> loadFromFile([
    String filePath = developmentAssetPath,
  ]) async {
    final content = await rootBundle.loadString(filePath);
    final json = jsonDecode(content) as Map<String, dynamic>;
    return StoreConfig.fromJson(json);
  }

  Future<StoreConfig> loadForEnvironment(StoreEnvironment environment) {
    return loadFromFile(assetPathForEnvironment(environment));
  }

  String assetPathForEnvironment(StoreEnvironment environment) {
    switch (environment) {
      case StoreEnvironment.development:
        return developmentAssetPath;
      case StoreEnvironment.test:
        return testAssetPath;
      case StoreEnvironment.production:
        return productionAssetPath;
    }
  }

  /// Apply the one-time bootstrap payload already fetched during device setup.
  /// Does not call the network.
  Future<void> applyBootstrapPayload(
    Map<String, dynamic> bootstrapPayload,
  ) async {
    final organisationRaw = bootstrapPayload['organisation'];
    if (organisationRaw is! Map) {
      throw StateError('Bootstrap payload is missing organisation.');
    }
    final organisation = StoreOrganisation.fromRow(
      organisationRaw.cast<String, dynamic>(),
    );

    final storeRows = bootstrapPayload['stores'];
    final stores = <StoreDirectoryEntry>[];
    if (storeRows is List) {
      for (final raw in storeRows) {
        if (raw is Map) {
          stores.add(StoreDirectoryEntry.fromRow(raw.cast<String, dynamic>()));
        }
      }
    }

    final customerRows = <Map<String, dynamic>>[];
    final dataRows = bootstrapPayload['data'];
    if (dataRows is List) {
      for (final raw in dataRows) {
        if (raw is Map) {
          customerRows.add(raw.cast<String, dynamic>());
        }
      }
    }

    final storeRoleRows = <StoreRoleAccess>[];
    final roleRows = bootstrapPayload['store_roles'];
    if (roleRows is List) {
      for (final raw in roleRows) {
        if (raw is Map) {
          storeRoleRows.add(
            StoreRoleAccess.fromRow(raw.cast<String, dynamic>()),
          );
        }
      }
    }

    final orgRoleRows = <StoreOrganisationRoleRecord>[];
    final orgRoles = bootstrapPayload['org_roles'];
    if (orgRoles is List) {
      for (final raw in orgRoles) {
        if (raw is Map) {
          orgRoleRows.add(
            StoreOrganisationRoleRecord.fromRow(raw.cast<String, dynamic>()),
          );
        }
      }
    }

    _organisation = organisation;
    _bootstrap = StoreOrganisationBootstrapSyncResult(
      organisation: organisation,
      stores: stores,
      customers: customerRows
          .map(StoreCustomer.fromRow)
          .toList(growable: false),
      storeRoles: storeRoleRows,
      organisationRoles: orgRoleRows,
    );
  }

  Future<StoreOrganisation?> resolveOrganisation(String orgCode) async {
    final config = _requireConfig();
    final organisation = await Store.resolveOrganisationByCode(
      orgCode,
      config: config,
    );
    _organisation = organisation;
    return organisation;
  }

  Future<StoreOrganisationBootstrapSyncResult?> syncOrganisationBootstrap(
    String orgCode,
  ) async {
    final config = _requireConfig();
    final bootstrap = await Store.syncOrganisationBootstrap(
      orgCode: orgCode,
      config: config,
    );
    _bootstrap = bootstrap;
    _organisation = bootstrap?.organisation;
    return bootstrap;
  }

  /// Restore the last organisation login (stores / roles) without a staff password.
  /// Used to open the store shell before the staff lock screen.
  Future<bool> restoreOrganisationLoginFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final setup = DeviceSetupStore(prefs);
    final cached = setup.loadOrganisationLogin();
    if (cached == null || cached.accessibleStores.isEmpty) {
      return false;
    }
    _organisationLogin = cached;
    _organisation = cached.organisation;
    return true;
  }

  /// Clear the active staff session but keep the device / store shell ready.
  Future<void> lockStaff() async {
    final prefs = await SharedPreferences.getInstance();
    final open = _store;
    if (open != null) {
      await persistSelectedStore(
        storeId: open.scope.storeId,
        storeName: open.storeName,
      );
    }
    try {
      if (_store != null) {
        await logout();
      }
    } catch (_) {}
    await prefs.remove('userPassword');
    await prefs.remove('userLoggedIn');
  }

  /// Logout: forget this staff member's lock PIN and end the store session.
  /// Other staff PINs stay so they can still unlock offline.
  Future<void> signOutStaff() async {
    final prefs = await SharedPreferences.getInstance();
    final session = await _store?.auth.currentSession();
    if (session != null) {
      final pins = PosLockPinStore(prefs);
      for (final pin in pins.loadAll()) {
        if (_sameStaffId(pin.customerId, session.customerId) ||
            pin.email.toLowerCase() == session.email.toLowerCase()) {
          await pins.remove(pin.customerId);
        }
      }
    }
    await lockStaff();
  }

  /// Offline staff switch after a verified lock-screen PIN: keeps the open
  /// session when it already belongs to [pin], otherwise opens one for them.
  /// False when that staff member cannot use the open store.
  Future<bool> openSessionForPin(PosLockPin pin) async {
    final store = _store;
    if (store == null) return false;
    final current = await store.auth.currentSession();
    if (current != null && _sameStaffId(current.customerId, pin.customerId)) {
      return true;
    }
    try {
      await store.auth.logout();
    } catch (_) {}
    final session = await store.auth.loginVerifiedCustomer(
      store.scope,
      pin.customerId,
    );
    if (session == null) return false;
    await PosLockPinStore(
      await SharedPreferences.getInstance(),
    ).markLast(pin.customerId);
    return true;
  }

  static bool _sameStaffId(String a, String b) {
    String norm(String v) {
      final t = v.trim();
      return t.startsWith('user_') ? t.substring(5) : t;
    }

    return norm(a).isNotEmpty && norm(a) == norm(b);
  }

  /// Staff unlock while the device lease is valid (local).
  ///
  /// Prefer a fast in-store session switch when the store is already open;
  /// otherwise run organisation login + openStore.
  Future<StaffUnlockResult> unlockStaff({
    required String identifier,
    required String password,
    String? storeId,
  }) async {
    final trimmedId = identifier.trim();
    final trimmedPassword = password;
    if (trimmedId.isEmpty || trimmedPassword.isEmpty) {
      return const StaffUnlockResult(
        ok: false,
        message: 'Enter staff ID and password.',
      );
    }

    try {
      await ensureDeviceAllowed();
    } on DeviceAccessDeniedException catch (e) {
      return StaffUnlockResult(ok: false, message: e.userMessage);
    }

    final lease = await LoginLeaseStore.open();
    if (lease.isExpired) {
      return const StaffUnlockResult(
        ok: false,
        needsOnlineRenew: true,
        message: 'Device login expired. Sign in online to renew.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final setup = DeviceSetupStore(prefs);
    final orgCode = setup.orgCode;
    if (orgCode == null || orgCode.isEmpty) {
      return const StaffUnlockResult(
        ok: false,
        message: 'Organisation is not set up on this device.',
      );
    }

    final preferredStoreId =
        (storeId ?? prefs.getString('selectedStoreId') ?? '').trim();

    // Fast path: store already open — try local switch, then online rebind.
    final existingStore = _store;
    if (existingStore != null) {
      try {
        await existingStore.auth.logout();
      } catch (_) {}
      var session = await existingStore.auth.login(
        existingStore.scope,
        StoreLoginRequest(email: trimmedId, password: trimmedPassword),
      );

      // Local SQLite hashes go stale after password changes / first sync with
      // the default offline hash. Fall back to gateway auth and rebind when
      // the device can reach the server; otherwise stay offline-only.
      if (session == null) {
        final online = await NetworkReachability.canReachGateway();
        if (!online) {
          return const StaffUnlockResult(
            ok: false,
            message: 'Invalid staff ID or password.',
          );
        }
        final onlineOk = await _loginOrganisationForUnlock(
          orgCode: orgCode,
          identifier: trimmedId,
          password: trimmedPassword,
          allowOnline: true,
        );
        if (!onlineOk) {
          return const StaffUnlockResult(
            ok: false,
            message: 'Invalid staff ID or password.',
          );
        }
        final login = _organisationLogin;
        if (login == null) {
          return const StaffUnlockResult(
            ok: false,
            message: 'Invalid staff ID or password.',
          );
        }
        final hasThisStore = login.accessibleStores.any(
          (entry) => entry.store.storeId == existingStore.scope.storeId,
        );
        if (!hasThisStore) {
          final row = login.customerRow;
          await _rememberStaffHint(
            prefs,
            trimmedId,
            login.email,
            displayName: '${row?['name'] ?? login.customerName}'.trim(),
            customerId: login.customerId,
          );
          return const StaffUnlockResult(ok: true, needsStorePicker: true);
        }
        try {
          _store = await existingStore.switchAccessibleStore(
            login: login,
            storeId: existingStore.scope.storeId,
            deviceRegistration: _deviceRegistration,
          );
          session = await _store?.auth.currentSession();
        } catch (_) {
          return const StaffUnlockResult(
            ok: false,
            message:
                'Signed in, but this branch is not available. Try Switch store.',
          );
        }
      }

      if (session == null) {
        return const StaffUnlockResult(
          ok: false,
          message: 'Invalid staff ID or password.',
        );
      }

      final open = _store ?? existingStore;
      final customer = await open.auth.currentCustomer();
      await _rememberStaffHint(
        prefs,
        trimmedId,
        session.email,
        displayName: customer?.name,
        customerId: customer?.customerId ?? session.customerId,
      );
      await _persistVerifiedOfflineCredentials(
        identifier: trimmedId,
        password: trimmedPassword,
        customerId: customer?.customerId ?? session.customerId,
        email: session.email,
      );
      try {
        await applyDeviceAutoSync();
      } catch (_) {}
      return StaffUnlockResult(ok: true, storeId: open.scope.storeId);
    }

    final loggedIn = await _loginOrganisationForUnlock(
      orgCode: orgCode,
      identifier: trimmedId,
      password: trimmedPassword,
      allowOnline: await NetworkReachability.canReachGateway(),
    );
    if (!loggedIn) {
      return const StaffUnlockResult(
        ok: false,
        message: 'Invalid staff ID or password.',
      );
    }

    final stores = accessibleStores();
    if (stores.isEmpty) {
      return const StaffUnlockResult(
        ok: false,
        message: 'No accessible stores for this staff member.',
      );
    }

    String? targetStoreId;
    if (preferredStoreId.isNotEmpty &&
        stores.any((s) => s.store.storeId == preferredStoreId)) {
      targetStoreId = preferredStoreId;
    } else if (stores.length == 1) {
      targetStoreId = stores.first.store.storeId;
    }

    if (targetStoreId == null) {
      final row = _organisationLogin?.customerRow;
      await _rememberStaffHint(
        prefs,
        trimmedId,
        null,
        displayName: '${row?['name'] ?? ''}'.trim(),
        customerId: _organisationLogin?.customerId,
      );
      await _persistVerifiedOfflineCredentials(
        identifier: trimmedId,
        password: trimmedPassword,
        customerId: _organisationLogin?.customerId,
        email: _organisationLogin?.email,
      );
      return const StaffUnlockResult(ok: true, needsStorePicker: true);
    }

    try {
      await openStore(targetStoreId);
    } catch (e) {
      return StaffUnlockResult(
        ok: false,
        message: 'Could not open store. Try Switch store or Online sign-in.',
      );
    }
    final row = _organisationLogin?.customerRow;
    await _rememberStaffHint(
      prefs,
      trimmedId,
      null,
      displayName: '${row?['name'] ?? ''}'.trim(),
      customerId: _organisationLogin?.customerId,
    );
    await _persistVerifiedOfflineCredentials(
      identifier: trimmedId,
      password: trimmedPassword,
      customerId: _organisationLogin?.customerId,
      email: _organisationLogin?.email,
    );
    return StaffUnlockResult(ok: true, storeId: targetStoreId);
  }

  /// Local cache first, then gateway — keeps unlock working when offline hashes
  /// are stale but the real password is correct online.
  Future<bool> _loginOrganisationForUnlock({
    required String orgCode,
    required String identifier,
    required String password,
    bool allowOnline = true,
  }) async {
    try {
      final localOk = await loginToOrganisation(
        orgCode: orgCode,
        email: identifier,
        password: password,
        preferLocal: true,
      );
      if (localOk) return true;
    } catch (_) {}

    if (!allowOnline) return false;

    try {
      return await loginToOrganisation(
        orgCode: orgCode,
        email: identifier,
        password: password,
        forceOnline: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// After a successful unlock, keep the verified password hash on-device for
  /// offline staff unlock until lease end / a newer sync credential arrives.
  Future<void> _persistVerifiedOfflineCredentials({
    required String identifier,
    required String password,
    String? customerId,
    String? email,
  }) async {
    final open = _store;
    if (open != null) {
      try {
        await open.auth.persistVerifiedOfflinePassword(
          password: password,
          customerId: customerId,
          identifier: identifier,
        );
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final setup = DeviceSetupStore(prefs);
    try {
      await setup.persistVerifiedStaffCredential(
        identifier: identifier,
        password: password,
        customerId: customerId,
        email: email,
      );
    } catch (_) {}
  }

  Future<void> _rememberStaffHint(
    SharedPreferences prefs,
    String identifier,
    String? email, {
    String? displayName,
    String? customerId,
  }) async {
    await prefs.setString('lastStaffIdentifier', identifier);
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      await prefs.setString('lastStaffDisplayName', name);
    } else {
      await prefs.setString('lastStaffDisplayName', identifier);
    }
    if (email != null && email.trim().isNotEmpty) {
      await prefs.setString('userEmail', email.trim());
    } else {
      await prefs.setString('userEmail', identifier);
    }
    await prefs.remove('userPassword');
    await prefs.remove('userLoggedIn');
    await _pushRecentStaff(
      prefs,
      PosStaffOption(
        customerId: (customerId ?? '').trim().isNotEmpty
            ? customerId!.trim()
            : identifier,
        name: name.isNotEmpty ? name : identifier,
        identifier: identifier,
      ),
    );
  }

  static const _recentStaffKey = 'recentStaffUnlocks';

  Future<void> _pushRecentStaff(
    SharedPreferences prefs,
    PosStaffOption staff,
  ) async {
    final existing = await loadRecentStaffOptions();
    final next = <PosStaffOption>[
      staff,
      ...existing.where(
        (row) =>
            row.customerId != staff.customerId &&
            row.identifier.toLowerCase() != staff.identifier.toLowerCase(),
      ),
    ];
    final encoded = next
        .take(12)
        .map(
          (row) => {
            'customerId': row.customerId,
            'name': row.name,
            'identifier': row.identifier,
          },
        )
        .toList(growable: false);
    await prefs.setString(_recentStaffKey, jsonEncode(encoded));
  }

  Future<List<PosStaffOption>> loadRecentStaffOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentStaffKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <PosStaffOption>[];
      for (final row in decoded) {
        if (row is! Map) continue;
        final customerId = '${row['customerId'] ?? ''}'.trim();
        final name = '${row['name'] ?? ''}'.trim();
        final identifier = '${row['identifier'] ?? ''}'.trim();
        if (customerId.isEmpty || identifier.isEmpty) continue;
        out.add(
          PosStaffOption(
            customerId: customerId,
            name: name.isNotEmpty ? name : identifier,
            identifier: identifier,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Display name for the currently unlocked operator (top bar).
  String get currentStaffDisplayName {
    final row = _organisationLogin?.customerRow;
    if (row != null) {
      final name = '${row['name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
      final reg = '${row['usr_reg_num'] ?? row['reg_num'] ?? ''}'.trim();
      if (reg.isNotEmpty) return reg;
      final email = '${row['email'] ?? ''}'.trim();
      if (email.isNotEmpty) return email;
    }
    return '';
  }

  Future<String> resolveStaffDisplayName() async {
    final live = currentStaffDisplayName.trim();
    if (live.isNotEmpty) return live;
    try {
      final customer = await _store?.auth.currentCustomer();
      final name = (customer?.name ?? '').trim();
      if (name.isNotEmpty) return name;
      final reg = (customer?.usrRegNum ?? '').trim();
      if (reg.isNotEmpty) return reg;
      final email = (customer?.email ?? '').trim();
      if (email.isNotEmpty) return email;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('lastStaffDisplayName')?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    return prefs.getString('lastStaffIdentifier')?.trim() ??
        prefs.getString('userEmail')?.trim() ??
        '';
  }

  Future<bool> loginToOrganisation({
    required String orgCode,
    required String email,
    required String password,
    String? deviceId,

    /// When true, authenticate against local hashes (lease still valid).
    /// When false/null, choose from [LoginLeaseStore]: local if valid, else remote.
    bool? preferLocal,

    /// When true, always hit the gateway (renew / force online login).
    bool forceOnline = false,
  }) async {
    final config = _requireConfig();
    final lease = await LoginLeaseStore.open();
    final useLocal = forceOnline ? false : (preferLocal ?? lease.isValid);

    final prefs = await SharedPreferences.getInstance();
    final setup = DeviceSetupStore(prefs);

    // Prefer the last online-login snapshot while the lease is valid — bootstrap
    // password hashes stay stale until the next gateway login patches them.
    if (useLocal) {
      final cachedLogin = setup.loadOrganisationLoginForCredentials(
        email: email,
        password: password,
      );
      if (cachedLogin != null) {
        _organisationLogin = cachedLogin;
        _organisation = cachedLogin.organisation;
        return true;
      }
    }

    Map<String, dynamic>? localBootstrap;
    String? customersPath = config.assetPaths.customers;
    if (useLocal) {
      localBootstrap = setup.loadCachedBootstrapJson();
      final cachedCustomers = prefs.getString('cachedCustomersPath')?.trim();
      if (cachedCustomers != null && cachedCustomers.isNotEmpty) {
        customersPath = cachedCustomers;
      }
    }

    final login = await Store.loginToOrganisation(
      orgCode: orgCode,
      email: email,
      password: password,
      deviceId: deviceId,
      config: config,
      customerJson: customersPath,
      preferLocal: useLocal,
      localBootstrap: localBootstrap,
    );
    _organisationLogin = login;
    _organisation = login?.organisation;
    if (login != null) {
      await setup.saveOrganisationLogin(login);
      if (!useLocal) {
        await lease.markOnlineLoginSucceeded();
        await setup.patchBootstrapOperatorCredential(login);
      }
    }
    return login != null;
  }

  List<StoreAccessibleStore> accessibleStores() {
    return _organisationLogin?.accessibleStores ?? const [];
  }

  /// Local POS operators for the staff unlock name buttons (this store only).
  Future<List<PosStaffOption>> listLocalStaffOptions({String? storeId}) async {
    final open = _store;
    final preferredStoreId = (storeId ?? open?.scope.storeId ?? '').trim();
    // Key by login identity (reg / email), not customerId — the same person can
    // appear as both `user_123` and a legacy row after sync.
    final byLoginKey = <String, PosStaffOption>{};

    String loginKey({
      required String reg,
      required String email,
      required String customerId,
    }) {
      final regKey = reg.trim().toLowerCase();
      if (regKey.isNotEmpty) return 'reg:$regKey';
      final emailKey = email.trim().toLowerCase();
      if (emailKey.isNotEmpty) return 'email:$emailKey';
      final id = customerId.trim().toLowerCase();
      if (id.startsWith('user_')) return 'id:$id';
      if (id.isNotEmpty) return 'id:user_$id';
      return '';
    }

    void addRow(Map<String, dynamic> row) {
      final customerId = '${row['customerId'] ?? ''}'.trim();
      if (customerId.isEmpty) return;
      final role = '${row['role'] ?? ''}'.trim().toLowerCase();
      if (role == 'retail_customer' || role == 'business_customer') return;
      final name = '${row['name'] ?? ''}'.trim();
      final reg = '${row['usr_reg_num'] ?? row['reg_num'] ?? ''}'.trim();
      final email = '${row['email'] ?? ''}'.trim();
      final identifier = reg.isNotEmpty
          ? reg
          : (email.isNotEmpty ? email : customerId);
      if (identifier.isEmpty) return;
      final key = loginKey(reg: reg, email: email, customerId: customerId);
      if (key.isEmpty) return;
      final display = name.isNotEmpty
          ? name
          : (reg.isNotEmpty ? reg : (email.isNotEmpty ? email : customerId));
      final existing = byLoginKey[key];
      if (existing == null) {
        byLoginKey[key] = PosStaffOption(
          customerId: customerId,
          name: display,
          identifier: identifier,
        );
        return;
      }
      final betterName =
          existing.name.trim().isEmpty && display.trim().isNotEmpty;
      final betterId =
          existing.identifier == existing.customerId &&
          identifier != customerId;
      if (betterName || betterId) {
        byLoginKey[key] = PosStaffOption(
          customerId: existing.customerId,
          name: betterName ? display : existing.name,
          identifier: betterId ? identifier : existing.identifier,
        );
      }
    }

    // Branch-scoped operators from the open store DB (store_roles), even after
    // logout — do not list org-wide customers.
    var loadedFromStore = false;
    if (open != null) {
      try {
        final rows = await open.customers.listStoreOperators(
          scope: open.scope,
          limit: 500,
          offset: 0,
        );
        for (final customer in rows) {
          addRow({
            'customerId': customer.customerId,
            'name': customer.name,
            'email': customer.email,
            'role': customer.role,
            'storeId': customer.storeId,
            'usr_reg_num': customer.usrRegNum,
          });
        }
        loadedFromStore = true;
      } catch (_) {}
    }

    if (!loadedFromStore && preferredStoreId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final setup = DeviceSetupStore(prefs);
        final bootstrap = setup.loadCachedBootstrapJson();
        if (bootstrap != null) {
          final roleByCustomer = <String>{};
          final roleRows = bootstrap['store_roles'];
          if (roleRows is List) {
            for (final raw in roleRows) {
              if (raw is! Map) continue;
              final customerId = '${raw['customerId'] ?? ''}'.trim();
              final roleStoreId = '${raw['storeId'] ?? ''}'.trim();
              if (customerId.isEmpty) continue;
              if (roleStoreId != preferredStoreId) continue;
              final access = raw['access_enabled'];
              final enabled = access is bool
                  ? access
                  : ((access as num?)?.toInt() ?? 1) == 1;
              if (!enabled) continue;
              final role = '${raw['role'] ?? ''}'.trim().toLowerCase();
              if (role == 'retail_customer' || role == 'business_customer') {
                continue;
              }
              roleByCustomer.add(customerId);
            }
          }

          final data = bootstrap['data'];
          if (data is List && roleByCustomer.isNotEmpty) {
            for (final raw in data) {
              if (raw is! Map) continue;
              final row = raw.cast<String, dynamic>();
              final customerId = '${row['customerId'] ?? ''}'.trim();
              if (!roleByCustomer.contains(customerId)) continue;
              addRow(row);
            }
          }
        }
      } catch (_) {}
    }

    final staff = byLoginKey.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return staff;
  }

  /// Display name for the open / selected store on staff unlock.
  String? staffUnlockStoreName({String? storeId}) {
    final open = _store;
    if (open != null) {
      final name = open.storeName.trim();
      if (name.isNotEmpty) return name;
    }
    final id = (storeId ?? open?.scope.storeId ?? '').trim();
    if (id.isEmpty) return null;
    for (final entry in accessibleStores()) {
      final sid = entry.store.storeId.trim();
      final remote = (entry.store.remoteId ?? '').trim();
      if (sid == id || (remote.isNotEmpty && remote == id)) {
        final name = entry.store.storeName.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return null;
  }

  /// Persist selected branch id + display name for staff unlock / cold start.
  Future<void> persistSelectedStore({
    required String storeId,
    String? storeName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = storeId.trim();
    if (id.isEmpty) return;
    await prefs.setString('selectedStoreId', id);
    final name = (storeName ?? staffUnlockStoreName(storeId: id) ?? '').trim();
    if (name.isNotEmpty) {
      await prefs.setString('selectedStoreName', name);
    }
  }

  /// 4-digit POS code of the logged-in organisation ('' when unknown).
  String get organisationPosCode => _organisation?.posCode ?? '';

  Future<StoreDeviceRegistrationResult?> registerDevice({
    required String deviceId,
    required String make,
    required String model,
    double? lat,
    double? lan,
  }) async {
    final config = _requireConfig();
    final organisation = _requireOrganisation();
    final request = StoreDeviceRegistrationRequest(
      deviceId: deviceId,
      make: make,
      model: model,
      lat: lat,
      lan: lan,
    );
    _deviceRegistration = request;

    // Only call the network when device registration is configured (setup time).
    if (!config.bootstrap.requiresDeviceRegistration) {
      return StoreDeviceRegistrationResult(
        orgId: organisation.orgId,
        deviceId: deviceId,
        make: make,
        model: model,
        lat: lat ?? 0,
        lan: lan ?? 0,
        status: 'active',
        message: 'Local device registration (offline POS).',
        registeredAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }

    final result = await Store.registerDeviceForOrganisation(
      orgId: organisation.orgId,
      request: request,
      config: config,
    );
    return result;
  }

  /// Remember device identity without another network call (cold start).
  Future<void> registerDeviceLocally({
    required String deviceId,
    required String make,
    required String model,
    double? lat,
    double? lan,
  }) async {
    _deviceRegistration = StoreDeviceRegistrationRequest(
      deviceId: deviceId,
      make: make,
      model: model,
      lat: lat,
      lan: lan,
    );
  }

  /// Delete the local SQLite DB for the current organisation so the next
  /// [openStore] recreates it with the current schema.
  Future<void> deleteStoreDatabase(String storeId) async {
    try {
      final existing = _store;
      if (existing != null) {
        try {
          await existing.close();
        } catch (_) {}
        _store = null;
      }
      final config = _requireConfig();
      final login = _requireOrganisationLogin();
      final dbRoot = await databaseFactory.getDatabasesPath();
      final dbFileName = config.buildOrganisationDatabaseFileName(
        login.organisation.orgId,
      );
      final dbFile = File(p.join(dbRoot, dbFileName));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      // Also delete journal/wal files.
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File('${dbFile.path}$suffix');
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('deleteStoreDatabase: $e');
    }
  }

  Future<void> openStore(String storeId) async {
    final config = _requireConfig();
    final login = _requireOrganisationLogin();
    final deviceRegistration = _requireDeviceRegistration();
    final databasePath = await databaseFactory.getDatabasesPath();

    final existingStore = _store;
    if (existingStore == null) {
      _store = await Store.openAccessibleStore(
        login: login,
        storeId: storeId,
        deviceRegistration: deviceRegistration,
        config: config,
        databasePath: databasePath,
      );
    } else {
      _store = await existingStore.switchAccessibleStore(
        login: login,
        storeId: storeId,
        deviceRegistration: deviceRegistration,
      );
    }
    if (_store == null) {
      throw StateError('Failed to open store with ID $storeId');
    } else {
      print(
        'Opened store: ${_store!.storeName} (ID: ${_store!.scope.storeId})',
      );
    }

    await persistSelectedStore(
      storeId: _store!.scope.storeId,
      storeName: _store!.storeName,
    );
    try {
      await _store!.ensureFixedSystemMailers(
        host: PosReportMailerDefaults.host,
        port: PosReportMailerDefaults.port,
        username: PosReportMailerDefaults.username,
        password: PosReportMailerDefaults.password,
        fromEmail: PosReportMailerDefaults.fromEmail,
        reportsFromName: PosReportMailerDefaults.reportsFromName,
        invoicesFromName: PosReportMailerDefaults.invoicesFromName,
        useTls: PosReportMailerDefaults.useTls,
      );
    } catch (_) {
      // Non-fatal — settings/reports screens will retry.
    }
    await applyDeviceAutoSync();
  }

  Future<void> switchStore(String storeId) async {
    final store = _requireStore();
    final login = _requireOrganisationLogin();
    final deviceRegistration = _requireDeviceRegistration();

    _store = await store.switchAccessibleStore(
      login: login,
      storeId: storeId,
      deviceRegistration: deviceRegistration,
    );

    if (_store!.sync.autoSyncEnabled && !_store!.sync.isAutoSyncRunning) {
      _store!.sync.startAutoSync(_store!.scope);
    }

    await applyDeviceAutoSync();
  }

  Future<StoreRoleAccess?> currentStoreAccess() {
    final store = _requireStore();
    return store.auth.currentStoreAccess(store.scope);
  }

  Future<bool> restoreSession() async {
    final store = _requireStore();
    return store.auth.isLoggedIn();
  }

  Future<StoreSession?> currentSession() {
    return _requireStore().auth.currentSession();
  }

  Future<StoreCustomer?> currentCustomer() {
    return _requireStore().auth.currentCustomer();
  }

  Future<List<StoreOrderSummary>> loadOrders({String? pricingMode}) {
    final store = _requireStore();
    return store.orders.listSummaries(store.scope, pricingMode: pricingMode);
  }

  Future<bool> alignOrderPricingMode(int orderId, String pricingMode) {
    final store = _requireStore();
    return store.orders.alignPricingMode(store.scope, orderId, pricingMode);
  }

  Future<int> loadServeNumberMaximum() {
    final store = _requireStore();
    return store.orders.getServeNumberMaximum(store.scope);
  }

  Future<void> updateServeNumberMaximum(int maximum) {
    final store = _requireStore();
    return store.orders.setServeNumberMaximum(store.scope, maximum);
  }

  Future<StoreOrderDetails?> loadOrder(int orderId) {
    final store = _requireStore();
    return store.orders.getById(store.scope, orderId);
  }

  Future<List<StoreOrderPaymentRecord>> loadOrderPayments(int orderId) {
    final store = _requireStore();
    return store.orders.listPayments(store.scope, orderId);
  }

  /// Resolves display labels for order line items from the on-device catalogue.
  Future<Map<String, String>> resolveOrderItemLabels(
    List<StoreOrderItemDetails> items,
  ) async {
    final catalogue = await loadCatalogue();
    final byId = <String, String>{};
    for (final product in catalogue.products) {
      void put(String? key) {
        final k = (key ?? '').trim();
        if (k.isEmpty) return;
        byId.putIfAbsent(k, () => product.name);
      }

      put(product.id);
      put(product.localId);
      if (product.variantId != null) put('${product.variantId}');
    }
    final labels = <String, String>{};
    for (final detail in items) {
      final item = detail.item;
      final key = item.productVariantId.isNotEmpty
          ? item.productVariantId
          : item.productId;
      final named = item.itemName.trim();
      labels[key] = named.isNotEmpty
          ? named
          : (byId[item.productVariantId] ??
                byId[item.productId] ??
                (item.productId.isNotEmpty ? item.productId : 'Item'));
    }
    return labels;
  }

  /// Catalogue products keyed by variant/product id for sell-unit display.
  Future<Map<String, PosCatalogProduct>> resolveOrderItemCatalogue(
    List<StoreOrderItemDetails> items,
  ) async {
    final catalogue = await loadCatalogue();
    final byId = <String, PosCatalogProduct>{};
    void index(PosCatalogProduct product) {
      void put(String? key) {
        final k = (key ?? '').trim();
        if (k.isEmpty) return;
        byId.putIfAbsent(k, () => product);
      }

      put(product.id);
      put(product.localId);
      if (product.variantId != null) put('${product.variantId}');
    }

    for (final product in catalogue.products) {
      index(product);
    }
    final resolved = <String, PosCatalogProduct>{};
    for (final detail in items) {
      final item = detail.item;
      final key = item.productVariantId.isNotEmpty
          ? item.productVariantId
          : item.productId;
      final product = byId[item.productVariantId] ?? byId[item.productId];
      if (product != null) resolved[key] = product;
    }
    return resolved;
  }

  /// Completes checkout: create order → add cart lines → take payment(s) →
  /// close when fully paid. Supports split / partial tenders.
  ///
  /// When [existingOrderId] is set (for example after KOT), that scoped open
  /// order is finalized instead of creating a duplicate.
  Future<CheckoutCompletionResult> completeCheckout({
    required List<CheckoutLineItem> items,
    required List<CheckoutPaymentLine> payments,
    required String orderType,
    String pricingMode = StoreOrderPricingMode.selling,
    int? existingOrderId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUniqueId,
    String? tableId,
    String? creditCustomerId,
    double tipsAmount = 0,
    double serviceTaxAmount = 0,
    double discountAmount = 0,
    double offerAmount = 0,
    double deliveryCharge = 0,
  }) async {
    final store = _requireStore();
    if (items.isEmpty) {
      throw StateError('Cannot checkout an empty cart.');
    }

    final resolvedOrderType = _mapOrderType(orderType);
    final resolvedPricingMode = StoreOrderPricingMode.normalize(pricingMode);
    final isBuying = resolvedPricingMode == StoreOrderPricingMode.buying;
    final timestamp = DateTime.now().toIso8601String();
    final sessionCustomer = await store.auth.currentCustomer();
    final staffName = (sessionCustomer?.name ?? '').trim().isNotEmpty
        ? sessionCustomer!.name.trim()
        : (sessionCustomer?.email ?? sessionCustomer?.customerId ?? 'POS');
    final staffReg = (sessionCustomer?.usrRegNum ?? '').trim();
    var createdBy = PosCheckoutMeta(
      staffName: staffName,
      staffReg: staffReg,
      tips: tipsAmount,
      serviceTax: serviceTaxAmount,
      discount: discountAmount,
      delivery: deliveryCharge,
    ).encode();

    String? resolvedCustomerId = customerUniqueId?.trim();
    final hasCustomerDetails =
        customerName != null &&
        customerName.trim().isNotEmpty &&
        customerPhone != null &&
        customerPhone.trim().isNotEmpty;
    if (hasCustomerDetails) {
      if (resolvedCustomerId == null || resolvedCustomerId.isEmpty) {
        final created = await createDirectoryCustomer(
          name: customerName.trim(),
          phone: customerPhone.trim(),
          email: customerEmail,
          customerGroup: isBuying ? 'supplier' : 'retail_customer',
        );
        resolvedCustomerId = created?.customerId;
      } else {
        final existing = await store.customers.getById(resolvedCustomerId);
        final expectedRole = isBuying ? 'supplier' : 'retail_customer';
        final sameName =
            (existing?.name.trim().toLowerCase() ?? '') ==
            customerName.trim().toLowerCase();
        final samePhone =
            (existing?.phone.trim() ?? '') == customerPhone.trim();
        final sameEmail =
            (existing?.email.trim().toLowerCase() ?? '') ==
            (customerEmail ?? '').trim().toLowerCase();
        final sameRole =
            (existing?.role.trim().toLowerCase() ?? '') == expectedRole;
        if (existing == null ||
            !sameName ||
            !samePhone ||
            !sameEmail ||
            !sameRole) {
          resolvedCustomerId = await store.customers.recordDirectoryCustomer(
            scope: store.scope,
            name: customerName.trim(),
            phone: customerPhone.trim(),
            email: customerEmail,
            uniqueId: resolvedCustomerId,
            role: expectedRole,
          );
        }
      }
    }

    var previousBalance = 0.0;
    if ((resolvedCustomerId ?? '').trim().isNotEmpty) {
      try {
        final partyId = resolvedCustomerId!.trim();
        final records = await store.credits.listRecords(
          store.scope,
          customerId: partyId,
        );
        previousBalance = records.fold<double>(
          0,
          (sum, record) => sum + record.outstandingAmount,
        );
        if (records.isEmpty) {
          final account = await store.credits.getAccountByCustomer(
            store.scope,
            partyId,
          );
          previousBalance = account?.outstandingBalance ?? 0;
        }
      } catch (_) {
        previousBalance = 0;
      }
    }
    createdBy = PosCheckoutMeta(
      staffName: staffName,
      staffReg: staffReg,
      tips: tipsAmount,
      serviceTax: serviceTaxAmount,
      discount: discountAmount,
      delivery: deliveryCharge,
      previousBalance: previousBalance,
    ).encode();

    final needsCreditCustomer = payments.any(
      (line) =>
          _mapPaymentMethod(line.paymentMethod) == StoreOrderPaymentMode.credit,
    );
    String? resolvedCreditCustomerId;
    if (needsCreditCustomer) {
      // Require an explicit credit customer — never fall back to the signed-in
      // staff session, which would silently "succeed" credit without a buyer.
      resolvedCreditCustomerId = (creditCustomerId ?? resolvedCustomerId)
          ?.trim();
      if (resolvedCreditCustomerId == null ||
          resolvedCreditCustomerId.isEmpty) {
        throw StateError(
          isBuying
              ? 'Payable checkout requires a supplier. Search or add a supplier before placing the balance on account.'
              : 'Credit checkout requires a customer. Search or add a customer before paying on credit.',
        );
      }
    }

    if (isBuying) {
      final supplierId = (resolvedCustomerId ?? '').trim();
      if (supplierId.isEmpty) {
        throw StateError(
          'Purchase checkout requires a supplier. Search or add a supplier before checkout.',
        );
      }
      resolvedCreditCustomerId ??= supplierId;
    }

    final hasPayablePayment = payments.any((line) => line.amount > 0.0001);
    if (!hasPayablePayment && !isBuying) {
      throw StateError(
        'Cannot checkout without at least one payment. Select a customer to put remaining balance on credit, or add another tender.',
      );
    }

    var orderId = existingOrderId;
    var reusedExistingOrder = false;
    if (orderId != null) {
      final existing = await store.orders.getById(store.scope, orderId);
      if (existing == null ||
          StoreOrderStatus.isCompleted(existing.statusName) ||
          StoreOrderStatus.isCancelled(existing.statusName)) {
        orderId = null;
      } else {
        reusedExistingOrder = true;
        await store.orders.alignPricingMode(
          store.scope,
          orderId,
          resolvedPricingMode,
        );
        if (StoreOrderStatus.isDraft(existing.statusName) ||
            StoreOrderStatus.isInitiated(existing.statusName)) {
          await store.orders.updateStatus(
            store.scope,
            orderId,
            StoreOrderStatus.pending,
          );
        }
      }
    }

    if (orderId == null) {
      orderId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: (customerName != null && customerName.trim().isNotEmpty)
              ? customerName.trim()
              : (isBuying ? 'Unspecified Supplier' : 'Walk-in Customer'),
          mobile: (customerPhone != null && customerPhone.trim().isNotEmpty)
              ? customerPhone.trim()
              : '+1000000000',
          customerUniqueId: resolvedCustomerId,
          statusName: 'Pending',
          total: 0,
          serviceInstance: store.serviceInstanceId,
          createdBy: createdBy,
          createdOn: timestamp,
          paymentStatus: 'Unpaid',
          orderType: resolvedOrderType,
          pricingMode: resolvedPricingMode,
        ),
      );
    }

    if (reusedExistingOrder) {
      final existingItems = await store.orders.listItems(store.scope, orderId);
      final qtyByVariant = <String, double>{};
      for (final row in existingItems) {
        final key = row.productVariantId.trim().isNotEmpty
            ? row.productVariantId
            : row.productId;
        qtyByVariant[key] = (qtyByVariant[key] ?? 0) + row.quantity.toDouble();
      }
      for (final item in items) {
        final key = item.productVariantId.trim().isNotEmpty
            ? item.productVariantId
            : item.productId;
        final have = qtyByVariant[key] ?? 0;
        final want = item.quantity;
        final delta = want - have;
        if (delta <= 0.0001) continue;
        await store.orders.addItem(
          store.scope,
          StoreAddOrderItemRequest(
            orderId: orderId,
            productVariantId: item.productVariantId,
            productId: item.productId,
            itemName: item.itemName,
            tableId: tableId,
            quantity: delta,
            unitPrice: item.unitPrice,
            sellPrice: item.unitPrice,
            mrpPrice: item.unitPrice,
            pricingMode: resolvedPricingMode,
            finalPrice: item.unitPrice * delta,
            createdBy: createdBy,
            createdOn: timestamp,
            addons: [
              for (final addon in item.addons)
                StoreAddOrderItemAddonRequest(
                  addonGroupId: addon.addonGroupId,
                  addonGroupName: addon.addonGroupName,
                  minSelections: addon.minSelections,
                  maxSelections: addon.maxSelections,
                  addonItemId: addon.addonItemId,
                  addonItemName: addon.addonItemName,
                  quantity: addon.quantity,
                  sellPrice: addon.unitPrice,
                  mrpPrice: addon.unitPrice,
                  unitPrice: addon.unitPrice,
                  createdOn: timestamp,
                ),
            ],
          ),
          refreshTotals: false,
          recalculateItemPricing: false,
        );
        qtyByVariant[key] = have + delta;
      }
    } else {
      for (final item in items) {
        await store.orders.addItem(
          store.scope,
          StoreAddOrderItemRequest(
            orderId: orderId,
            productVariantId: item.productVariantId,
            productId: item.productId,
            itemName: item.itemName,
            tableId: tableId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            sellPrice: item.unitPrice,
            mrpPrice: item.unitPrice,
            pricingMode: resolvedPricingMode,
            finalPrice: item.lineTotal ?? (item.unitPrice * item.quantity),
            createdBy: createdBy,
            createdOn: timestamp,
            addons: [
              for (final addon in item.addons)
                StoreAddOrderItemAddonRequest(
                  addonGroupId: addon.addonGroupId,
                  addonGroupName: addon.addonGroupName,
                  minSelections: addon.minSelections,
                  maxSelections: addon.maxSelections,
                  addonItemId: addon.addonItemId,
                  addonItemName: addon.addonItemName,
                  quantity: addon.quantity,
                  sellPrice: addon.unitPrice,
                  mrpPrice: addon.unitPrice,
                  unitPrice: addon.unitPrice,
                  createdOn: timestamp,
                ),
            ],
          ),
          refreshTotals: false,
          recalculateItemPricing: false,
        );
      }
    }

    // One offer/total pass after all lines — avoids O(n) full-order rebuilds.
    final refreshed = await store.orders.refreshTotals(store.scope, orderId);
    final itemsTotal = refreshed['finalValue'] ?? 0;
    final offerDiscount = refreshed['offerAppliedValue'] ?? 0;
    final itemsSubtotal = refreshed['totalValue'] ?? itemsTotal;
    final manualDiscount = discountAmount > 0 ? discountAmount : 0.0;
    final adjustedTotalValue = double.parse(
      (itemsTotal +
              (deliveryCharge > 0 ? deliveryCharge : 0) +
              (serviceTaxAmount > 0 ? serviceTaxAmount : 0) +
              (tipsAmount > 0 ? tipsAmount : 0))
          .toStringAsFixed(2),
    );
    // Keep offer discount separate; fold manual % discount into offer_applied.
    final adjustedOffer = double.parse(
      (offerDiscount + manualDiscount).toStringAsFixed(2),
    );
    final amountDue = double.parse(
      (adjustedTotalValue - manualDiscount)
          .clamp(0, double.infinity)
          .toStringAsFixed(2),
    );
    if ((tipsAmount + serviceTaxAmount + deliveryCharge + manualDiscount)
            .abs() >
        0.0001) {
      await store.orders.setAmounts(
        store.scope,
        orderId,
        totalValue: double.parse(
          (itemsSubtotal > 0 ? itemsSubtotal : itemsTotal).toStringAsFixed(2),
        ),
        offerAppliedValue: adjustedOffer,
        finalValue: amountDue,
      );
    }
    if (amountDue <= 0) {
      throw StateError('Order $orderId has no payable amount.');
    }

    var totalPaid = 0.0;
    if (reusedExistingOrder) {
      final existingPayments = await store.orders.listPayments(
        store.scope,
        orderId,
      );
      totalPaid = existingPayments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );
    }
    final modeLabels = <String>[];
    for (final line in payments) {
      if (line.amount <= 0.0001) continue;
      final paymentMode = _mapPaymentMethod(line.paymentMethod);
      final isCredit = paymentMode == StoreOrderPaymentMode.credit;
      await store.orders.addPayment(
        store.scope,
        orderId,
        StoreCreateOrderPaymentRequest(
          paymentMode: paymentMode,
          amount: line.amount,
          customerId: isCredit ? resolvedCreditCustomerId : null,
          referenceId:
              line.referenceId ??
              'pos-$paymentMode-$orderId-${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      totalPaid += line.amount;
      modeLabels.add(paymentMode);

      if (isCredit) {
        String? dueDate;
        final installmentCount = line.creditInstallmentCount ?? 0;
        if (installmentCount < 2 &&
            line.creditDueInDays != null &&
            line.creditDueInDays! > 0) {
          final due = DateTime.now().add(Duration(days: line.creditDueInDays!));
          dueDate =
              '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
        }
        await store.credits.create(
          store.scope,
          StoreCreateCreditRequest(
            orgId: store.orgId,
            customerId: resolvedCreditCustomerId!,
            orderId: orderId,
            amount: line.amount,
            createdOn: timestamp,
            updatedOn: timestamp,
            dueDate: dueDate,
            installmentCount: installmentCount >= 2 ? installmentCount : null,
            installmentCadence: installmentCount >= 2
                ? (line.creditInstallmentCadence ?? 'weekly')
                : null,
          ),
        );
      }
    }

    totalPaid = double.parse(totalPaid.toStringAsFixed(2));
    var balance = double.parse(
      (amountDue - totalPaid).clamp(0, amountDue).toStringAsFixed(2),
    );

    if (isBuying && balance > 0.0001) {
      final supplierId =
          (resolvedCreditCustomerId ?? resolvedCustomerId ?? '').trim();
      if (supplierId.isEmpty) {
        throw StateError(
          'Purchase checkout requires a supplier for payable balance.',
        );
      }
      await store.credits.create(
        store.scope,
        StoreCreateCreditRequest(
          orgId: store.orgId,
          customerId: supplierId,
          orderId: orderId,
          amount: balance,
          createdOn: timestamp,
          updatedOn: timestamp,
        ),
      );
      await store.orders.addPayment(
        store.scope,
        orderId,
        StoreCreateOrderPaymentRequest(
          paymentMode: StoreOrderPaymentMode.credit,
          amount: balance,
          customerId: supplierId,
          referenceId:
              'pos-credit-auto-$orderId-${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      totalPaid = double.parse((totalPaid + balance).toStringAsFixed(2));
      modeLabels.add(StoreOrderPaymentMode.credit);
      balance = double.parse(
        (amountDue - totalPaid).clamp(0, amountDue).toStringAsFixed(2),
      );
    }

    final paymentStatus = totalPaid <= 0.0001
        ? 'Unpaid'
        : (balance <= 0.0001 ? 'Paid' : 'Partial');
    await store.orders.updatePaymentStatus(store.scope, orderId, paymentStatus);

    String statusName = 'Pending';
    if (isBuying || (balance <= 0.0001 && totalPaid > 0)) {
      await store.orders.close(store.scope, orderId);
      statusName = 'Closed';
    }

    return CheckoutCompletionResult(
      orderId: orderId,
      totalPaid: totalPaid,
      paymentMode: modeLabels.isEmpty ? 'none' : modeLabels.join('+'),
      statusName: statusName,
      restaurantName: store.storeName,
      paymentStatus: paymentStatus,
      balanceDue: balance,
      pricingMode: resolvedPricingMode,
      customerName: (customerName ?? '').trim(),
      customerId: (resolvedCustomerId ?? '').trim(),
      previousBalance: previousBalance,
      offerAmount: offerAmount,
      tipsAmount: tipsAmount,
      discountAmount: discountAmount,
    );
  }

  /// Records a (possibly partial) payment against an existing order.
  Future<({double paidTotal, double balance, String paymentStatus})>
  recordOrderPayment({
    required int orderId,
    required String paymentMethod,
    required double amount,
    String? referenceId,
    String? creditCustomerId,
    int? creditDueInDays,
    int? creditInstallmentCount,
    String? creditInstallmentCadence,
  }) async {
    final store = _requireStore();
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero.');
    }

    final order = await store.orders.getById(store.scope, orderId);
    if (order == null) {
      throw StateError('Order $orderId was not found.');
    }

    final orderTotal = order.finalValue > 0 ? order.finalValue : order.total;
    final alreadyPaid = order.payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final remaining = double.parse(
      (orderTotal - alreadyPaid).clamp(0, orderTotal).toStringAsFixed(2),
    );
    if (amount - remaining > 0.0001) {
      throw StateError(
        'Amount ${PosCurrency.format(amount)} exceeds remaining ${PosCurrency.format(remaining)}.',
      );
    }

    final paymentMode = _mapPaymentMethod(paymentMethod);
    String? resolvedCreditCustomerId;
    if (paymentMode == StoreOrderPaymentMode.credit) {
      String? fromOrder;
      final summaries = await store.orders.listSummaries(store.scope);
      for (final summary in summaries) {
        if (summary.orderId == orderId) {
          fromOrder = summary.customerUniqueId;
          break;
        }
      }
      resolvedCreditCustomerId = creditCustomerId ?? fromOrder;
      if (resolvedCreditCustomerId == null ||
          resolvedCreditCustomerId.isEmpty) {
        throw StateError('Credit payment requires a customer on the order.');
      }
    }

    final timestamp = DateTime.now().toIso8601String();
    await store.orders.addPayment(
      store.scope,
      orderId,
      StoreCreateOrderPaymentRequest(
        paymentMode: paymentMode,
        amount: amount,
        customerId: resolvedCreditCustomerId,
        referenceId:
            referenceId ??
            'pos-$paymentMode-$orderId-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (paymentMode == StoreOrderPaymentMode.credit) {
      String? dueDate;
      final installmentCount = creditInstallmentCount ?? 0;
      if (installmentCount < 2 &&
          creditDueInDays != null &&
          creditDueInDays > 0) {
        final due = DateTime.now().add(Duration(days: creditDueInDays));
        dueDate =
            '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      }
      await store.credits.create(
        store.scope,
        StoreCreateCreditRequest(
          orgId: store.orgId,
          customerId: resolvedCreditCustomerId!,
          orderId: orderId,
          amount: amount,
          createdOn: timestamp,
          updatedOn: timestamp,
          dueDate: dueDate,
          installmentCount: installmentCount >= 2 ? installmentCount : null,
          installmentCadence: installmentCount >= 2
              ? (creditInstallmentCadence ?? 'weekly')
              : null,
        ),
      );
    }

    final paidTotal = double.parse((alreadyPaid + amount).toStringAsFixed(2));
    final balance = double.parse(
      (orderTotal - paidTotal).clamp(0, orderTotal).toStringAsFixed(2),
    );
    final paymentStatus = paidTotal <= 0.0001
        ? 'Unpaid'
        : (balance <= 0.0001 ? 'Paid' : 'Partial');
    await store.orders.updatePaymentStatus(store.scope, orderId, paymentStatus);

    if (balance <= 0.0001) {
      try {
        await store.orders.close(store.scope, orderId);
      } catch (_) {
        // Already closed or status gate — payment status still updated.
      }
    }

    return (
      paidTotal: paidTotal,
      balance: balance,
      paymentStatus: paymentStatus,
    );
  }

  String _mapPaymentMethod(String method) {
    final normalized = method.trim().toLowerCase();
    if (StoreOrderPaymentMode.supported.contains(normalized)) {
      return normalized;
    }
    switch (normalized) {
      case 'cash':
        return StoreOrderPaymentMode.cash;
      case 'card':
        return StoreOrderPaymentMode.card;
      case 'upi':
      case 'upi / online':
      case 'online':
        return StoreOrderPaymentMode.online;
      case 'credit':
      case 'pay later':
        return StoreOrderPaymentMode.credit;
      default:
        throw ArgumentError.value(
          method,
          'paymentMethod',
          'Unsupported payment method.',
        );
    }
  }

  String _mapOrderType(String orderType) {
    // Keep synced keys (ONSITE, INSTORE, …). Only blank values fall back to pickup.
    final normalized = StoreOrderType.normalize(orderType);
    if (normalized.isEmpty) {
      return StoreOrderType.pickUp;
    }
    return normalized;
  }

  Future<int> createWalkInOrder() {
    final store = _requireStore();
    return store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Walk-in Customer',
        mobile: '+1000000000',
        statusName: 'Pending',
        total: 42.5,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'ui-example',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
        payments: const [
          StoreCreateOrderPaymentRequest(
            paymentMode: StoreOrderPaymentMode.cash,
            amount: 20.0,
            referenceId: 'ui-cash-auto-order',
          ),
        ],
      ),
    );
  }

  Future<void> addOrderPayment(int orderId) {
    return recordOrderPayment(
      orderId: orderId,
      paymentMethod: StoreOrderPaymentMode.card,
      amount: 22.5,
      referenceId: 'ui-card-auto-order',
    ).then((_) {});
  }

  Future<void> closeOrder(int orderId) {
    final store = _requireStore();
    return store.orders.close(store.scope, orderId);
  }

  /// Saves the cart as a local-only Draft order (no payments, not exported).
  Future<int> saveDraftFromCart({
    required List<CheckoutLineItem> items,
    required String orderType,
    String pricingMode = StoreOrderPricingMode.selling,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUniqueId,
    String? tableId,
    double tipsAmount = 0,
    double serviceTaxAmount = 0,
    double discountAmount = 0,
    double deliveryCharge = 0,
  }) async {
    final store = _requireStore();
    if (items.isEmpty) {
      throw StateError('Cannot save an empty draft.');
    }
    final timestamp = DateTime.now().toIso8601String();
    final sessionCustomer = await store.auth.currentCustomer();
    final staffName = (sessionCustomer?.name ?? '').trim().isNotEmpty
        ? sessionCustomer!.name.trim()
        : (sessionCustomer?.email ?? sessionCustomer?.customerId ?? 'POS');
    final staffReg = (sessionCustomer?.usrRegNum ?? '').trim();
    final createdBy = PosCheckoutMeta(
      staffName: staffName,
      staffReg: staffReg,
      tips: tipsAmount,
      serviceTax: serviceTaxAmount,
      discount: discountAmount,
      delivery: deliveryCharge,
    ).encode();

    String? resolvedCustomerId = customerUniqueId?.trim();
    final hasCustomerDetails =
        customerName != null &&
        customerName.trim().isNotEmpty &&
        customerPhone != null &&
        customerPhone.trim().isNotEmpty;
    if (hasCustomerDetails) {
      if (resolvedCustomerId == null || resolvedCustomerId.isEmpty) {
        final created = await createDirectoryCustomer(
          name: customerName.trim(),
          phone: customerPhone.trim(),
          email: customerEmail,
        );
        resolvedCustomerId = created?.customerId;
      } else {
        resolvedCustomerId = await store.customers.recordDirectoryCustomer(
          scope: store.scope,
          name: customerName.trim(),
          phone: customerPhone.trim(),
          email: customerEmail,
          uniqueId: resolvedCustomerId,
        );
      }
    }

    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : 'Walk-in Customer',
        mobile: (customerPhone != null && customerPhone.trim().isNotEmpty)
            ? customerPhone.trim()
            : '+1000000000',
        customerUniqueId: resolvedCustomerId,
        statusName: StoreOrderStatus.draft,
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: createdBy,
        createdOn: timestamp,
        paymentStatus: 'Unpaid',
        orderType: _mapOrderType(orderType),
        pricingMode: StoreOrderPricingMode.normalize(pricingMode),
        exported: true,
      ),
    );

    final resolvedDraftPricingMode = StoreOrderPricingMode.normalize(
      pricingMode,
    );
    for (final item in items) {
      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: item.productVariantId,
          productId: item.productId,
          itemName: item.itemName,
          tableId: tableId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          sellPrice: item.unitPrice,
          mrpPrice: item.unitPrice,
          pricingMode: resolvedDraftPricingMode,
          finalPrice: item.lineTotal ?? (item.unitPrice * item.quantity),
          createdBy: createdBy,
          createdOn: timestamp,
          addons: [
            for (final addon in item.addons)
              StoreAddOrderItemAddonRequest(
                addonGroupId: addon.addonGroupId,
                addonGroupName: addon.addonGroupName,
                minSelections: addon.minSelections,
                maxSelections: addon.maxSelections,
                addonItemId: addon.addonItemId,
                addonItemName: addon.addonItemName,
                quantity: addon.quantity,
                sellPrice: addon.unitPrice,
                mrpPrice: addon.unitPrice,
                unitPrice: addon.unitPrice,
                createdOn: timestamp,
              ),
          ],
        ),
        refreshTotals: false,
      );
    }
    final refreshed = await store.orders.refreshTotals(store.scope, orderId);
    final itemsTotal = refreshed['finalValue'] ?? 0;
    final offerDiscount = refreshed['offerAppliedValue'] ?? 0;
    final itemsSubtotal = refreshed['totalValue'] ?? itemsTotal;
    final manualDiscount = discountAmount > 0 ? discountAmount : 0.0;
    final adjustedTotalValue = double.parse(
      (itemsTotal +
              (deliveryCharge > 0 ? deliveryCharge : 0) +
              (serviceTaxAmount > 0 ? serviceTaxAmount : 0) +
              (tipsAmount > 0 ? tipsAmount : 0))
          .toStringAsFixed(2),
    );
    final adjustedOffer = double.parse(
      (offerDiscount + manualDiscount).toStringAsFixed(2),
    );
    final amountDue = double.parse(
      (adjustedTotalValue - manualDiscount)
          .clamp(0, double.infinity)
          .toStringAsFixed(2),
    );
    if ((tipsAmount + serviceTaxAmount + deliveryCharge + manualDiscount)
            .abs() >
        0.0001) {
      await store.orders.setAmounts(
        store.scope,
        orderId,
        totalValue: double.parse(
          (itemsSubtotal > 0 ? itemsSubtotal : itemsTotal).toStringAsFixed(2),
        ),
        offerAppliedValue: adjustedOffer,
        finalValue: amountDue,
      );
    }
    await store.orders.updateStatus(
      store.scope,
      orderId,
      StoreOrderStatus.draft,
    );
    return orderId;
  }

  /// Estimates catalogue offer discount for the current cart (core offer engine).
  ///
  /// Uses billable package count × product package price. Add-ons are excluded.
  Future<({double amount, List<String> labels})> previewCartOffers(
    List<CheckoutLineItem> items,
  ) async {
    final store = _requireStore();
    if (items.isEmpty) {
      return (amount: 0.0, labels: const <String>[]);
    }
    final offers = await store.offers.list(store.scope, activeOnly: true);
    final evalItems = <StoreOfferEvaluationItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final entered = item.quantity <= 0 ? 1.0 : item.quantity;
      final baseQty = item.sellUnitBaseQty;
      final billable = (baseQty != null && baseQty > 0)
          ? (entered / baseQty).ceil().clamp(1, 999999)
          : entered.round().clamp(1, 999999);
      evalItems.add(
        StoreOfferEvaluationItem(
          orderItemId: i + 1,
          productTargetIds: [
            item.productVariantId,
            item.productId,
            if (item.productVariantId.startsWith('pv_'))
              item.productVariantId.substring(3),
            if (item.productId.startsWith('p_')) item.productId.substring(2),
          ].where((id) => id.trim().isNotEmpty).toSet().toList(),
          categoryTargetIds: const [],
          quantity: billable,
          // Product variant package price only — never fold in add-ons.
          unitPrice: item.unitPrice,
        ),
      );
    }
    final result = StoreOfferEngine.calculate(offers: offers, items: evalItems);
    return (
      amount: double.parse(result.totalDiscount.toStringAsFixed(2)),
      labels: [
        for (final offer in result.appliedOffers)
          if (offer.name.trim().isNotEmpty) offer.name.trim(),
      ],
    );
  }

  /// Persists (or extends) an open order and marks pending lines as sent to kitchen.
  Future<KotSendResult> sendKotFromCart({
    int? existingOrderId,
    required List<CheckoutLineItem> items,
    required String orderType,
    String pricingMode = StoreOrderPricingMode.selling,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUniqueId,
    String? tableId,
    double tipsAmount = 0,
    double serviceTaxAmount = 0,
    double discountAmount = 0,
    double deliveryCharge = 0,
  }) async {
    final store = _requireStore();
    if (items.isEmpty) {
      throw StateError('Cannot send KOT for an empty cart.');
    }

    final timestamp = DateTime.now().toIso8601String();
    final sessionCustomer = await store.auth.currentCustomer();
    final staffName = (sessionCustomer?.name ?? '').trim().isNotEmpty
        ? sessionCustomer!.name.trim()
        : (sessionCustomer?.email ?? sessionCustomer?.customerId ?? 'POS');
    final staffReg = (sessionCustomer?.usrRegNum ?? '').trim();
    final createdBy = PosCheckoutMeta(
      staffName: staffName,
      staffReg: staffReg,
      tips: tipsAmount,
      serviceTax: serviceTaxAmount,
      discount: discountAmount,
      delivery: deliveryCharge,
    ).encode();

    String? resolvedCustomerId = customerUniqueId?.trim();
    final hasCustomerDetails =
        customerName != null &&
        customerName.trim().isNotEmpty &&
        customerPhone != null &&
        customerPhone.trim().isNotEmpty;
    if (hasCustomerDetails) {
      if (resolvedCustomerId == null || resolvedCustomerId.isEmpty) {
        final created = await createDirectoryCustomer(
          name: customerName.trim(),
          phone: customerPhone.trim(),
          email: customerEmail,
        );
        resolvedCustomerId = created?.customerId;
      } else {
        resolvedCustomerId = await store.customers.recordDirectoryCustomer(
          scope: store.scope,
          name: customerName.trim(),
          phone: customerPhone.trim(),
          email: customerEmail,
          uniqueId: resolvedCustomerId,
        );
      }
    }

    var orderId = existingOrderId;
    if (orderId != null) {
      final existing = await store.orders.getById(store.scope, orderId);
      if (existing == null) {
        orderId = null;
      } else {
        await store.orders.alignPricingMode(
          store.scope,
          orderId,
          StoreOrderPricingMode.normalize(pricingMode),
        );
        if (StoreOrderStatus.isDraft(existing.statusName)) {
          await store.orders.updateStatus(
            store.scope,
            orderId,
            StoreOrderStatus.pending,
          );
        }
      }
    }

    if (orderId == null) {
      orderId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: (customerName != null && customerName.trim().isNotEmpty)
              ? customerName.trim()
              : 'Walk-in Customer',
          mobile: (customerPhone != null && customerPhone.trim().isNotEmpty)
              ? customerPhone.trim()
              : '+1000000000',
          customerUniqueId: resolvedCustomerId,
          statusName: StoreOrderStatus.pending,
          total: 0,
          serviceInstance: store.serviceInstanceId,
          createdBy: createdBy,
          createdOn: timestamp,
          paymentStatus: 'Unpaid',
          orderType: _mapOrderType(orderType),
          pricingMode: StoreOrderPricingMode.normalize(pricingMode),
        ),
      );
      final resolvedPricingMode = StoreOrderPricingMode.normalize(pricingMode);
      for (final item in items) {
        await store.orders.addItem(
          store.scope,
          StoreAddOrderItemRequest(
            orderId: orderId,
            productVariantId: item.productVariantId,
            productId: item.productId,
            itemName: item.itemName,
            tableId: tableId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            sellPrice: item.unitPrice,
            mrpPrice: item.unitPrice,
            pricingMode: resolvedPricingMode,
            finalPrice: item.lineTotal ?? (item.unitPrice * item.quantity),
            createdBy: createdBy,
            createdOn: timestamp,
            addons: [
              for (final addon in item.addons)
                StoreAddOrderItemAddonRequest(
                  addonGroupId: addon.addonGroupId,
                  addonGroupName: addon.addonGroupName,
                  minSelections: addon.minSelections,
                  maxSelections: addon.maxSelections,
                  addonItemId: addon.addonItemId,
                  addonItemName: addon.addonItemName,
                  quantity: addon.quantity,
                  sellPrice: addon.unitPrice,
                  mrpPrice: addon.unitPrice,
                  unitPrice: addon.unitPrice,
                  createdOn: timestamp,
                ),
            ],
          ),
          refreshTotals: false,
        );
      }
    } else {
      final existingItems = await store.orders.listItems(store.scope, orderId);
      final qtyByVariant = <String, double>{};
      for (final row in existingItems) {
        final key = row.productVariantId.trim().isNotEmpty
            ? row.productVariantId
            : row.productId;
        qtyByVariant[key] = (qtyByVariant[key] ?? 0) + row.quantity.toDouble();
      }
      for (final item in items) {
        final key = item.productVariantId.trim().isNotEmpty
            ? item.productVariantId
            : item.productId;
        final have = qtyByVariant[key] ?? 0;
        final want = item.quantity;
        final delta = want - have;
        if (delta <= 0.0001) continue;
        await store.orders.addItem(
          store.scope,
          StoreAddOrderItemRequest(
            orderId: orderId,
            productVariantId: item.productVariantId,
            productId: item.productId,
            itemName: item.itemName,
            tableId: tableId,
            quantity: delta,
            unitPrice: item.unitPrice,
            sellPrice: item.unitPrice,
            mrpPrice: item.unitPrice,
            finalPrice: item.unitPrice * delta,
            createdBy: createdBy,
            createdOn: timestamp,
            addons: [
              for (final addon in item.addons)
                StoreAddOrderItemAddonRequest(
                  addonGroupId: addon.addonGroupId,
                  addonGroupName: addon.addonGroupName,
                  minSelections: addon.minSelections,
                  maxSelections: addon.maxSelections,
                  addonItemId: addon.addonItemId,
                  addonItemName: addon.addonItemName,
                  quantity: addon.quantity,
                  sellPrice: addon.unitPrice,
                  mrpPrice: addon.unitPrice,
                  unitPrice: addon.unitPrice,
                  createdOn: timestamp,
                ),
            ],
          ),
          refreshTotals: false,
        );
        qtyByVariant[key] = have + delta;
      }
    }

    final refreshed = await store.orders.refreshTotals(store.scope, orderId);
    final itemsTotal = refreshed['finalValue'] ?? 0;
    final offerDiscount = refreshed['offerAppliedValue'] ?? 0;
    final itemsSubtotal = refreshed['totalValue'] ?? itemsTotal;
    final manualDiscount = discountAmount > 0 ? discountAmount : 0.0;
    final adjustedTotalValue = double.parse(
      (itemsTotal +
              (deliveryCharge > 0 ? deliveryCharge : 0) +
              (serviceTaxAmount > 0 ? serviceTaxAmount : 0) +
              (tipsAmount > 0 ? tipsAmount : 0))
          .toStringAsFixed(2),
    );
    final adjustedOffer = double.parse(
      (offerDiscount + manualDiscount).toStringAsFixed(2),
    );
    final amountDue = double.parse(
      (adjustedTotalValue - manualDiscount)
          .clamp(0, double.infinity)
          .toStringAsFixed(2),
    );
    await store.orders.setAmounts(
      store.scope,
      orderId,
      totalValue: double.parse(
        (itemsSubtotal > 0 ? itemsSubtotal : itemsTotal).toStringAsFixed(2),
      ),
      offerAppliedValue: adjustedOffer,
      finalValue: amountDue,
    );

    final printers = await store.listAvailablePrinters();
    String printerId = 'kitchen-printer-01';
    for (final printer in printers) {
      if (printer.purpose == StorePrinterPurpose.kitchen) {
        printerId = printer.id;
        break;
      }
    }
    if (printers.isNotEmpty && !printers.any((p) => p.id == printerId)) {
      printerId = printers.first.id;
    }
    final printResult = await store.sendToKitchen(printerId, orderId);
    return KotSendResult(
      orderId: orderId,
      batchNumber: printResult.kitchenBatchNumber ?? 1,
      itemsMarked: 1,
    );
  }

  Future<void> deleteDraftOrder(int orderId) {
    final store = _requireStore();
    return store.orders.deleteDraft(store.scope, orderId);
  }

  Future<void> promoteDraftToPending(int orderId) async {
    final store = _requireStore();
    final details = await store.orders.getById(store.scope, orderId);
    if (details == null) {
      throw StateError('Order $orderId was not found.');
    }
    if (!StoreOrderStatus.isDraft(details.statusName)) {
      return;
    }
    await store.orders.updateStatus(
      store.scope,
      orderId,
      StoreOrderStatus.pending,
    );
  }

  Future<void> updateOrderStatus(int orderId, String status) {
    final store = _requireStore();
    return store.orders.updateStatus(store.scope, orderId, status);
  }

  /// Derives order-level payment status from net payments after refunds.
  Future<String> _syncOrderPaymentStatus(int orderId) async {
    final store = _requireStore();
    final details = await store.orders.getById(store.scope, orderId);
    if (details == null) {
      throw StateError('Order $orderId was not found.');
    }
    final payments = await store.orders.listPayments(store.scope, orderId);
    final String paymentStatus;
    if (payments.isEmpty) {
      paymentStatus = 'Unpaid';
    } else if (payments.every((payment) => payment.isFullyRefunded)) {
      paymentStatus = 'Refunded';
    } else {
      final netPaid = double.parse(
        payments
            .fold<double>(0, (sum, payment) => sum + payment.refundableAmount)
            .toStringAsFixed(2),
      );
      final orderTotal = details.finalValue > 0
          ? details.finalValue
          : details.total;
      final balance = double.parse(
        (orderTotal - netPaid).clamp(0, orderTotal).toStringAsFixed(2),
      );
      if (netPaid <= 0.0001) {
        paymentStatus = 'Unpaid';
      } else if (balance <= 0.0001) {
        paymentStatus = 'Paid';
      } else {
        paymentStatus = 'Partial';
      }
    }
    await store.orders.updatePaymentStatus(store.scope, orderId, paymentStatus);
    return paymentStatus;
  }

  /// Cancels an order after all payments are fully refunded (or never paid).
  Future<void> cancelOrder(int orderId, {String? reason}) async {
    final store = _requireStore();
    final details = await store.orders.getById(store.scope, orderId);
    if (details == null) {
      throw StateError('Order $orderId was not found.');
    }
    if (!StoreOrderStatus.canCancel(details.statusName)) {
      throw StateError(
        'Order cannot be cancelled in status ${details.statusName}.',
      );
    }
    final payments = await store.orders.listPayments(store.scope, orderId);
    final outstanding = payments.where((p) => !p.isFullyRefunded).toList();
    if (outstanding.isNotEmpty) {
      throw StateError(
        'Refund all payments before cancelling. '
        '${outstanding.length} payment(s) still have a refundable balance.',
      );
    }
    await store.orders.updateStatus(
      store.scope,
      orderId,
      StoreOrderStatus.cancelled,
    );
    // Paid → refunded on cancel; unpaid cancel stays Unpaid.
    await _syncOrderPaymentStatus(orderId);
  }

  /// Refunds every remaining balance on the order, then cancels.
  Future<void> refundAllAndCancelOrder(int orderId, {String? reason}) async {
    final store = _requireStore();
    final payments = await store.orders.listPayments(store.scope, orderId);
    for (final payment in payments) {
      if (payment.refundableAmount <= 0.0001) continue;
      await store.orders.addRefund(
        store.scope,
        orderId,
        StoreCreateOrderRefundRequest(
          paymentId: payment.id,
          amount: payment.refundableAmount,
          reason: reason ?? 'Order cancelled',
        ),
      );
    }
    await cancelOrder(orderId, reason: reason);
  }

  Future<int> refundPayment({
    required int orderId,
    required int paymentId,
    required double amount,
    String? reason,
  }) async {
    final store = _requireStore();
    final refundId = await store.orders.addRefund(
      store.scope,
      orderId,
      StoreCreateOrderRefundRequest(
        paymentId: paymentId,
        amount: amount,
        reason: reason,
      ),
    );
    await _syncOrderPaymentStatus(orderId);
    return refundId;
  }

  Future<List<StoreOrderRefundRecord>> listRefunds({int? orderId}) {
    final store = _requireStore();
    return store.orders.listRefunds(store.scope, orderId: orderId);
  }

  Future<List<String>> loadProductNames() {
    final store = _requireStore();
    return store.products.listNames(store.scope);
  }

  Future<List<StoreProductVariantRecord>> loadProductVariants(int categoryId) {
    final store = _requireStore();
    return store.products.listVariantsByCategory(store.scope, categoryId);
  }

  Future<List<StoreProductAddonGroupRecord>> loadAddonGroupsForVariant(
    String productVariantId,
  ) {
    final store = _requireStore();
    return store.products.listAddonGroupsForVariant(
      store.scope,
      productVariantId,
    );
  }

  /// Map of catalogue product/variant id → short offer badge text.
  Future<Map<String, String>> loadProductOfferTags() async {
    final store = _requireStore();
    final offers = await store.offers.list(store.scope, activeOnly: true);
    final byTarget = <String, String>{};
    for (final offer in offers) {
      if (offer.offerType == StoreOfferType.totalOffer) continue;
      final label = _offerBadgeLabel(offer);
      if (label.isEmpty) continue;
      for (final targetId in offer.targetIds) {
        final key = targetId.trim();
        if (key.isEmpty) continue;
        byTarget.putIfAbsent(key, () => label);
      }
    }
    if (byTarget.isEmpty) return const {};

    final catalogue = await loadCatalogue();
    final tags = <String, String>{};
    for (final product in catalogue.products) {
      final label =
          byTarget[product.id] ??
          (product.variantId == null ? null : byTarget['${product.variantId}']);
      if (label != null) {
        tags[product.id] = label;
        if (product.variantId != null) {
          tags['${product.variantId}'] = label;
        }
      }
    }
    // Keep raw target keys too for any direct id matches.
    tags.addAll(byTarget);
    return tags;
  }

  String _offerBadgeLabel(StoreOfferRecord offer) {
    switch (offer.offerType) {
      case StoreOfferType.percentage:
        final pct = offer.percentageValue ?? 0;
        if (pct <= 0) return offer.name.trim();
        return '-${pct == pct.roundToDouble() ? pct.toInt() : pct}%';
      case StoreOfferType.flat:
        final flat = offer.flatValue ?? 0;
        if (flat <= 0) return offer.name.trim();
        return '-${PosCurrency.format(flat, decimals: flat == flat.roundToDouble() ? 0 : 2)}';
      case StoreOfferType.buyNGetM:
        final buy = offer.buyQuantity ?? 0;
        final get = offer.getQuantity ?? 0;
        if (buy <= 0 || get <= 0) return offer.name.trim();
        return 'B$buy G$get';
      default:
        return offer.name.trim();
    }
  }

  /// Full on-device catalogue for the open store: categories and their product
  /// variants, as synced from the remote. Empty categories are dropped.
  Future<PosCatalogue> loadCatalogue() async {
    final store = _requireStore();
    final scope = store.scope;
    final categoryRows = await store.products.listCategories(scope);

    final categories = <PosCatalogCategory>[];
    final products = <PosCatalogProduct>[];
    final seenIds = <String>{};

    PosCatalogProduct mapVariant(
      StoreProductVariantRecord variant, {
      required int categoryId,
      required String categoryName,
    }) {
      final packageName = variant.productVariantName.trim();
      final productName = variant.productName.trim();
      final id = variant.uniqueId?.isNotEmpty == true
          ? variant.uniqueId!
          : (variant.variantId?.toString() ?? variant.localId);
      return PosCatalogProduct(
        id: id,
        localId: variant.localId,
        name: packageName.isNotEmpty
            ? packageName
            : (productName.isEmpty ? 'Item' : productName),
        productName: productName,
        packageName: packageName,
        price: variant.sellPrice,
        mrpPrice: variant.mrpPrice > 0 ? variant.mrpPrice : null,
        buyPrice: variant.buyPrice,
        barcode: variant.barcode,
        categoryId: categoryId,
        categoryName: categoryName,
        variantId: variant.variantId,
        sellUnitCode: variant.sellUnitCode,
        sellUnitShort: variant.sellUnitShort,
        sellUnitLabel: variant.sellUnitLabel,
        sellUnitBaseQty: variant.sellUnitBaseQty,
      );
    }

    for (final category in categoryRows) {
      // Prefer localId lookup so offline-created categories (null categoryId) still resolve.
      List<StoreProductVariantRecord> variants;
      if (category.localId.trim().isNotEmpty) {
        variants = await store.products.listVariantsByCategoryLocalId(
          scope,
          category.localId,
        );
      } else {
        variants = await store.products.listVariantsByCategory(
          scope,
          category.categoryId,
        );
      }
      if (variants.isEmpty) continue;
      final stableCategoryId = category.categoryId != 0
          ? category.categoryId
          : category.localId.hashCode.abs();
      categories.add(
        PosCatalogCategory(id: stableCategoryId, name: category.name),
      );
      for (final variant in variants) {
        final mapped = mapVariant(
          variant,
          categoryId: stableCategoryId,
          categoryName: category.name,
        );
        if (!seenIds.add(mapped.id)) continue;
        products.add(mapped);
      }
    }

    // Catch packages whose categoryLocalId did not resolve via categoryId.
    if (products.isEmpty || categoryRows.isNotEmpty) {
      final all = await store.products.searchDetails(scope: scope, limit: 5000);
      for (final variant in all) {
        final id = variant.uniqueId?.isNotEmpty == true
            ? variant.uniqueId!
            : (variant.variantId?.toString() ?? variant.localId);
        if (seenIds.contains(id)) continue;
        var categoryId = variant.categoryId;
        var categoryName = '';
        final catLocal = variant.categoryLocalId.trim();
        for (final category in categoryRows) {
          if ((catLocal.isNotEmpty && category.localId == catLocal) ||
              category.categoryId == categoryId ||
              category.localId == 'cat_${variant.categoryId}' ||
              category.localId.endsWith('_${variant.categoryId}')) {
            categoryId = category.categoryId != 0
                ? category.categoryId
                : category.localId.hashCode.abs();
            categoryName = category.name;
            break;
          }
        }
        if (categoryName.isEmpty && catLocal.isNotEmpty) {
          final resolved = await store.products.findCategoryById(
            scope,
            catLocal,
          );
          if (resolved != null) {
            categoryId = resolved.categoryId != 0
                ? resolved.categoryId
                : resolved.localId.hashCode.abs();
            categoryName = resolved.name;
          }
        }
        if (categoryName.isEmpty && categoryId != 0) {
          for (final category in categoryRows) {
            if (category.categoryId == categoryId) {
              categoryName = category.name;
              break;
            }
          }
        }
        if (categoryName.isEmpty) categoryName = 'Uncategorized';
        if (categories.every((c) => c.id != categoryId)) {
          categories.add(
            PosCatalogCategory(id: categoryId, name: categoryName),
          );
        }
        seenIds.add(id);
        products.add(
          mapVariant(
            variant,
            categoryId: categoryId,
            categoryName: categoryName,
          ),
        );
      }
    }

    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return PosCatalogue(categories: categories, products: products);
  }

  /// Active offers for the open store (full records for catalog detail).
  Future<List<StoreOfferRecord>> loadOffers({bool activeOnly = true}) {
    final store = _requireStore();
    return store.offers.list(store.scope, activeOnly: activeOnly);
  }

  /// Addon groups keyed by package/variant id for catalog browsing.
  Future<Map<String, List<StoreProductAddonGroupRecord>>> loadCatalogAddonMap(
    List<PosCatalogProduct> products,
  ) async {
    if (products.isEmpty) return const {};
    final entries = await Future.wait(
      products.map((product) async {
        try {
          final groups = await loadAddonGroupsForVariant(product.id);
          return MapEntry(product.id, groups);
        } catch (_) {
          return MapEntry(product.id, const <StoreProductAddonGroupRecord>[]);
        }
      }),
    );
    return {
      for (final entry in entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  /// Order types synced from the backend for the open store (cached
  /// on-device; falls back to Pickup / Dine-In before the first sync).
  Future<List<PosOrderType>> loadOrderTypes() {
    final store = _requireStore();
    return OrderTypesRepository.load(
      orgId: store.orgId,
      storeId: store.storeId,
    );
  }

  Future<List<StoreCustomer>> searchCustomers(
    String query, {
    List<String>? roles,
  }) {
    final store = _requireStore();
    return store.customers.searchDirectoryDetails(
      scope: store.scope,
      nameQuery: query,
      limit: 50,
      roles: roles,
    );
  }

  /// Creates (or reuses) a directory party via the gateway and stores them
  /// locally under the backend user id (``user_{id}``).
  Future<StoreCustomer?> createDirectoryCustomer({
    required String name,
    required String phone,
    String? email,
    String customerGroup = 'retail_customer',
  }) async {
    final store = _requireStore();
    final resolvedGroup = customerGroup.trim().isEmpty
        ? 'retail_customer'
        : customerGroup.trim().toLowerCase();
    final uri = Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/customers');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orgId': store.orgId,
        'orgCode': store.orgCode,
        'storeId': store.storeId,
        'name': name.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'customer_group': resolvedGroup,
      }),
    );
    final body = jsonDecode(response.body);
    if (body is! Map || body['ok'] != true) {
      final message = body is Map
          ? (body['message']?.toString() ?? 'Customer create failed')
          : 'Customer create failed';
      throw StateError(message);
    }
    final customer = body['customer'];
    if (customer is! Map) {
      throw StateError('Customer create returned no customer row.');
    }
    final customerId = customer['customerId']?.toString() ?? '';
    if (customerId.isEmpty) {
      throw StateError('Customer create returned no user id.');
    }

    await store.customers.recordDirectoryCustomer(
      scope: store.scope,
      name: customer['name']?.toString() ?? name,
      phone: customer['phone']?.toString() ?? phone,
      email: customer['email']?.toString() ?? email,
      uniqueId: customerId,
      role: resolvedGroup,
    );
    return store.customers.getById(customerId);
  }

  Future<List<StoreCustomer>> loadCustomers({int limit = 200, int offset = 0}) {
    final store = _requireStore();
    return store.customers.listDirectoryDetails(
      scope: store.scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<StoreCustomer?> loadCustomerById(String customerId) {
    final store = _requireStore();
    return store.customers.getById(customerId.trim());
  }

  /// Resolve customer display fields across ``user_{id}`` / bare-id variants.
  Future<({String name, String regNum, String customerId})>
  resolveCustomerDisplay(String customerId) async {
    final raw = customerId.trim();
    if (raw.isEmpty) {
      return (name: 'Customer', regNum: '', customerId: '');
    }
    final candidates = <String>{
      raw,
      if (raw.startsWith('user_')) raw.substring(5),
      if (!raw.startsWith('user_') && int.tryParse(raw) != null) 'user_$raw',
    };
    for (final id in candidates) {
      if (id.isEmpty) continue;
      final customer = await loadCustomerById(id);
      if (customer == null) continue;
      final name = customer.name.trim();
      final looksLikeId =
          name.toLowerCase() == id.toLowerCase() ||
          name.toLowerCase().startsWith('user_');
      if (name.isNotEmpty && !looksLikeId) {
        return (
          name: name,
          regNum: customer.usrRegNum.trim(),
          customerId: customer.customerId,
        );
      }
      if (name.isNotEmpty) {
        return (
          name: name,
          regNum: customer.usrRegNum.trim(),
          customerId: customer.customerId,
        );
      }
      return (
        name: 'Customer',
        regNum: customer.usrRegNum.trim(),
        customerId: customer.customerId,
      );
    }
    return (
      name: raw.startsWith('user_') ? 'Customer' : raw,
      regNum: '',
      customerId: raw,
    );
  }

  Future<List<StoreCustomerCreditSummary>> loadCreditSummaries({
    String sortBy = StoreCreditCustomerSortBy.amount,
    bool descending = true,
  }) {
    final store = _requireStore();
    return store.credits.listCreditorsByCustomer(
      store.scope,
      sortBy: sortBy,
      descending: descending,
    );
  }

  Future<List<StoreCreditRecord>> loadCreditRecords({String? customerId}) {
    final store = _requireStore();
    return store.credits.listRecords(store.scope, customerId: customerId);
  }

  Future<StoreCreditAccountRecord?> loadCreditAccount(String customerId) {
    final store = _requireStore();
    return store.credits.getAccountByCustomer(store.scope, customerId);
  }

  Future<List<StoreCreditInstallmentRecord>> loadCreditInstallments({
    int? creditId,
  }) {
    final store = _requireStore();
    return store.credits.listInstallments(store.scope, creditId: creditId);
  }

  Future<List<StoreCreditRepaymentRecord>> loadCreditRepayments({
    String? customerId,
    bool includeDeleted = false,
  }) {
    final store = _requireStore();
    return store.credits.listRepayments(
      store.scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );
  }

  Future<double> loadCustomerAdvanceBalance(String customerId) {
    final store = _requireStore();
    return store.credits.getCustomerAdvanceBalance(store.scope, customerId);
  }

  Future<int> recordCustomerAdvance({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
  }) {
    final store = _requireStore();
    return store.credits.recordCustomerAdvance(
      store.scope,
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceId: referenceId,
    );
  }

  Future<List<StoreCustomerLedgerEntry>> loadCustomerCreditLedger({
    required String customerId,
    bool includeDeleted = false,
  }) {
    final store = _requireStore();
    return store.credits.customerLedger(
      store.scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );
  }

  Future<int> voidCreditRepayment({
    required int repaymentId,
    required String reason,
  }) async {
    final store = _requireStore();
    final session = await store.auth.currentCustomer();
    final deletedBy = session?.customerId ?? session?.email ?? 'pos-tablet';
    return store.credits.deleteRepayment(
      store.scope,
      repaymentId,
      StoreDeleteCreditRepaymentRequest(
        deletedByCustomerId: deletedBy,
        reason: reason,
      ),
    );
  }

  Future<List<StoreScheduledCreditRepayment>> loadScheduledCreditRepayments({
    String? customerId,
    bool includeClosed = false,
  }) {
    final store = _requireStore();
    return store.credits.listScheduledRepayments(
      store.scope,
      customerId: customerId,
      includeClosed: includeClosed,
    );
  }

  Future<int> scheduleCreditRepayment({
    required String customerId,
    required double amount,
    required String dueDate,
  }) {
    final store = _requireStore();
    return store.credits.scheduleRepayment(
      store.scope,
      StoreCreateScheduledCreditRepaymentRequest(
        customerId: customerId,
        amount: amount,
        dueDate: dueDate,
      ),
    );
  }

  Future<int> cancelScheduledCreditRepayment(int scheduleId) {
    final store = _requireStore();
    return store.credits.cancelScheduledRepayment(store.scope, scheduleId);
  }

  Future<int> collectScheduledCreditRepayment({
    required int scheduleId,
    required String paymentMode,
    String? referenceId,
    double? amount,
  }) {
    final store = _requireStore();
    return store.credits.collectScheduledRepayment(
      store.scope,
      scheduleId: scheduleId,
      paymentMode: paymentMode,
      referenceId: referenceId,
      amount: amount,
    );
  }

  Future<List<StoreWalletRecord>> loadWallets({bool includeInactive = false}) {
    final store = _requireStore();
    return store.wallets.list(store.scope, includeInactive: includeInactive);
  }

  /// Collect a full or partial credit repayment (FIFO across open lines).
  Future<int> collectCreditPayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    int? preferCreditId,
  }) {
    final store = _requireStore();
    return store.credits.recordRepaymentFifo(
      store.scope,
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceId: referenceId,
      preferCreditId: preferCreditId,
    );
  }

  /// Builds dashboard metrics for [filter] from the on-device SQLite store.
  ///
  /// [filter] is one of: All Time, Yesterday, Today, This Week,
  /// This Month, This Year.
  /// Date ranges and hourly buckets use the organisation / store timezone.
  /// [pricingMode] keeps sell and buy dashboards separate (default selling).
  Future<PosDashboardSnapshot> loadDashboardSnapshot(
    String filter, {
    String pricingMode = StoreOrderPricingMode.selling,
  }) async {
    final store = _requireStore();
    final scope = store.scope;
    final tzName = _orgTimezoneName;
    final range = _dashboardDateRange(filter, tzName);
    final resolvedPricingMode = StoreOrderPricingMode.normalize(pricingMode);
    final orders = await store.orders.listSummaries(scope);
    final orderTypes = await loadOrderTypes();
    final inRange = orders
        .where((order) {
          if (StoreOrderStatus.isDraft(order.statusName)) return false;
          if (StoreOrderPricingMode.normalize(order.pricingMode) !=
              resolvedPricingMode) {
            return false;
          }
          final created = OrgTimezone.tryParseWallClock(
            order.createdOn,
            tzName,
          );
          if (created == null) return false;
          return !created.isBefore(range.start) && created.isBefore(range.end);
        })
        .toList(growable: false);

    final typeCounts = <String, int>{};
    for (final type in orderTypes) {
      typeCounts[type.key] = 0;
    }
    var cancelled = 0;
    var totalSales = 0.0;
    var pendingAmount = 0.0;
    var pendingCount = 0;
    final bucketTotals = <int, double>{};
    final bucketCounts = <int, int>{};
    for (final order in inRange) {
      final resolved = _resolveDashboardOrderType(order.orderType, orderTypes);
      typeCounts[resolved.key] = (typeCounts[resolved.key] ?? 0) + 1;

      final status = order.statusName.trim().toLowerCase();
      if (status.contains('cancel')) cancelled++;

      final amount = order.finalValue != 0 ? order.finalValue : order.total;
      totalSales += amount;

      final refunded = order.paymentStatus.trim().toLowerCase() == 'refunded';
      if (!status.contains('cancel') && !refunded && order.balanceDue > 0) {
        pendingAmount += order.balanceDue;
        pendingCount++;
      }

      final created =
          OrgTimezone.tryParseWallClock(order.createdOn, tzName) ?? range.start;
      final bucket = _dashboardBucketIndex(created);
      bucketTotals[bucket] = (bucketTotals[bucket] ?? 0) + amount;
      bucketCounts[bucket] = (bucketCounts[bucket] ?? 0) + 1;
    }

    final orderTypeCounts = <PosDashboardOrderTypeCount>[
      for (final type in orderTypes)
        PosDashboardOrderTypeCount(
          key: type.key,
          label: type.label,
          count: typeCounts[type.key] ?? 0,
        ),
      // Include any custom keys seen on orders that are not in the synced list.
      for (final entry in typeCounts.entries)
        if (!orderTypes.any((t) => t.key == entry.key))
          PosDashboardOrderTypeCount(
            key: entry.key,
            label: entry.key,
            count: entry.value,
          ),
    ];

    var cash = 0.0;
    var card = 0.0;
    var online = 0.0;
    var credit = 0.0;
    final categoryCounts = <String, int>{};
    final categoryLabels = <String, String>{};
    final productCounts = <String, int>{};
    final productLabels = <String, String>{};
    final staffTotals = <String, PosDashboardStaffSales>{};
    final catalogue = await loadCatalogue();
    final productsById = <String, PosCatalogProduct>{};
    void indexCatalogueProduct(PosCatalogProduct product) {
      void put(String? key) {
        final k = (key ?? '').trim();
        if (k.isEmpty) return;
        productsById.putIfAbsent(k, () => product);
      }

      put(product.id);
      put(product.localId);
      if (product.variantId != null) put('${product.variantId}');
    }

    for (final product in catalogue.products) {
      indexCatalogueProduct(product);
    }

    PosCatalogProduct? matchCatalogueProduct(
      String variantKey,
      String productKey,
    ) {
      final direct =
          productsById[variantKey.trim()] ?? productsById[productKey.trim()];
      if (direct != null) return direct;
      for (final product in catalogue.products) {
        if (variantKey.isNotEmpty &&
            (product.id == variantKey ||
                product.localId == variantKey ||
                '${product.variantId ?? ''}' == variantKey)) {
          return product;
        }
        if (productKey.isNotEmpty &&
            (product.id == productKey || product.localId == productKey)) {
          return product;
        }
      }
      return null;
    }

    Future<String?> resolveCategoryDisplayName(
      String variantKey,
      String productKey,
    ) async {
      final matched = matchCatalogueProduct(variantKey, productKey);
      final fromCatalogue = (matched?.categoryName ?? '').trim();
      if (fromCatalogue.isNotEmpty) return fromCatalogue;
      if (matched != null && matched.categoryId != 0) {
        return 'Category ${matched.categoryId}';
      }

      for (final key in [variantKey, productKey]) {
        final trimmed = key.trim();
        if (trimmed.isEmpty) continue;
        final variant = await store.products.findVariantById(scope, trimmed);
        if (variant == null) continue;
        final catLocal = variant.categoryLocalId.trim();
        if (catLocal.isNotEmpty) {
          final category = await store.products.findCategoryById(
            scope,
            catLocal,
          );
          final name = (category?.name ?? '').trim();
          if (name.isNotEmpty) return name;
        }
        if (variant.categoryId != 0) {
          return 'Category ${variant.categoryId}';
        }
      }
      return null;
    }

    Future<String> resolveProductDisplayName({
      required String variantKey,
      required String productKey,
      required String itemName,
    }) async {
      final named = itemName.trim();
      if (named.isNotEmpty) return named;
      final matched = matchCatalogueProduct(variantKey, productKey);
      final fromCatalogue = (matched?.name ?? '').trim().isNotEmpty
          ? matched!.name.trim()
          : (matched?.productName ?? '').trim();
      if (fromCatalogue.isNotEmpty) return fromCatalogue;

      for (final key in [variantKey, productKey]) {
        final trimmed = key.trim();
        if (trimmed.isEmpty) continue;
        final variant = await store.products.findVariantById(scope, trimmed);
        if (variant == null) continue;
        final package = variant.productVariantName.trim();
        if (package.isNotEmpty) return package;
        final product = variant.productName.trim();
        if (product.isNotEmpty) return product;
      }
      if (variantKey.trim().isNotEmpty) return variantKey.trim();
      if (productKey.trim().isNotEmpty) return productKey.trim();
      return 'Item';
    }

    ({String name, String reg}) resolveStaff(StoreOrderSummary order) {
      final meta = PosCheckoutMeta.parse(order.createdBy);
      var name = meta.staffName.trim().isNotEmpty
          ? meta.staffName.trim()
          : order.createdBy.trim();
      final lowered = name.toLowerCase();
      if (lowered.isEmpty ||
          lowered == 'import' ||
          lowered == 'pos' ||
          lowered == 'system' ||
          lowered == '—' ||
          lowered == '-' ||
          lowered == 'none' ||
          lowered == 'null') {
        name = 'Unassigned';
      }
      return (name: name, reg: meta.staffReg.trim());
    }

    for (final order in inRange) {
      final amount = order.finalValue != 0 ? order.finalValue : order.total;
      final staff = resolveStaff(order);
      final staffKey = staff.name.toLowerCase();
      final existingStaff = staffTotals[staffKey];
      if (existingStaff == null) {
        staffTotals[staffKey] = PosDashboardStaffSales(
          staffName: staff.name,
          staffReg: staff.reg,
          orderCount: 1,
          amount: amount,
        );
      } else {
        staffTotals[staffKey] = PosDashboardStaffSales(
          staffName: existingStaff.staffName,
          staffReg: existingStaff.staffReg.isNotEmpty
              ? existingStaff.staffReg
              : staff.reg,
          orderCount: existingStaff.orderCount + 1,
          amount: existingStaff.amount + amount,
          creditAmount: existingStaff.creditAmount,
        );
      }

      final payments = await store.orders.listPayments(scope, order.orderId);
      var orderCredit = 0.0;
      for (final payment in payments) {
        final mode = payment.paymentMode.trim().toLowerCase();
        if (mode.contains('cash')) {
          cash += payment.amount;
        } else if (mode.contains('card')) {
          card += payment.amount;
        } else if (mode.contains('credit') ||
            mode.contains('pay_later') ||
            mode.contains('pay later')) {
          credit += payment.amount;
          orderCredit += payment.amount;
        } else {
          online += payment.amount;
        }
      }
      if (orderCredit > 0) {
        final current = staffTotals[staffKey]!;
        staffTotals[staffKey] = PosDashboardStaffSales(
          staffName: current.staffName,
          staffReg: current.staffReg,
          orderCount: current.orderCount,
          amount: current.amount,
          creditAmount: current.creditAmount + orderCredit,
        );
      }

      final items = await store.orders.listItems(scope, order.orderId);
      for (final item in items) {
        final qty = item.quantity;
        if (qty <= 0) continue;

        final productName = await resolveProductDisplayName(
          variantKey: item.productVariantId,
          productKey: item.productId,
          itemName: item.itemName,
        );
        final productKey = item.productVariantId.trim().isNotEmpty
            ? item.productVariantId.trim()
            : (item.productId.trim().isNotEmpty
                  ? item.productId.trim()
                  : productName.toLowerCase());
        productCounts[productKey] = (productCounts[productKey] ?? 0) + qty;
        productLabels.putIfAbsent(productKey, () => productName);

        final categoryName = (await resolveCategoryDisplayName(
          item.productVariantId,
          item.productId,
        ))?.trim();
        if (categoryName == null || categoryName.isEmpty) continue;

        final rollupKey = categoryName.toLowerCase();
        categoryCounts[rollupKey] = (categoryCounts[rollupKey] ?? 0) + qty;
        categoryLabels.putIfAbsent(rollupKey, () => categoryName);
      }
    }

    final paymentTotal = cash + card + online + credit;
    double share(double part) =>
        paymentTotal <= 0 ? 0 : (part / paymentTotal) * 100;

    final labels = _dashboardBucketLabels();
    final salesPoints = <PosDashboardSalesPoint>[
      for (var i = 0; i < labels.length; i++)
        PosDashboardSalesPoint(
          label: labels[i],
          amount: bucketTotals[i] ?? 0,
          count: bucketCounts[i] ?? 0,
        ),
    ];

    final topCategories = categoryCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return (categoryLabels[a.key] ?? a.key).toLowerCase().compareTo(
          (categoryLabels[b.key] ?? b.key).toLowerCase(),
        );
      });
    final topCategoryRows = topCategories
        .take(8)
        .map(
          (entry) => (
            name: categoryLabels[entry.key] ?? entry.key,
            count: entry.value,
          ),
        )
        .toList(growable: false);

    final topProducts = productCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return (productLabels[a.key] ?? a.key).toLowerCase().compareTo(
          (productLabels[b.key] ?? b.key).toLowerCase(),
        );
      });
    final topProductRows = topProducts
        .take(8)
        .map(
          (entry) =>
              (name: productLabels[entry.key] ?? entry.key, count: entry.value),
        )
        .toList(growable: false);

    final staffSalesRows = staffTotals.values.toList()
      ..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        if (byAmount != 0) return byAmount;
        final byCount = b.orderCount.compareTo(a.orderCount);
        if (byCount != 0) return byCount;
        return a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase());
      });

    final creditRecords = await store.credits.listRecords(scope);
    final openCredits = creditRecords
        .where((row) => !row.settled && row.outstandingAmount > 0)
        .toList(growable: false);
    final creditCustomers = <String>{};
    var creditOutstanding = 0.0;
    for (final row in openCredits) {
      creditOutstanding += row.outstandingAmount;
      final customerKey = row.customerId.trim().isNotEmpty
          ? row.customerId.trim()
          : row.customerName.trim();
      if (customerKey.isNotEmpty) creditCustomers.add(customerKey);
    }

    final creditOrders = openCredits
        .take(12)
        .map(
          (row) => (
            customerName: row.customerName.isEmpty
                ? 'Customer'
                : row.customerName,
            amount: row.outstandingAmount,
            date: _formatDashboardTime(row.createdOn, tzName),
          ),
        )
        .toList(growable: false);

    final repayments = await store.credits.listRepayments(scope);
    var repaymentsAmount = 0.0;
    for (final row in repayments) {
      if (row.deleted) continue;
      final paidAt =
          OrgTimezone.tryParseWallClock(row.paidOn, tzName) ??
          OrgTimezone.tryParseWallClock(row.createdOn, tzName);
      if (paidAt == null) continue;
      if (paidAt.isBefore(range.start) || !paidAt.isBefore(range.end)) continue;
      // Count only the portion applied to open credit. Unallocated remainder
      // is customer advance, not a repayment.
      repaymentsAmount += row.allocatedAmount;
    }

    final refunds = await store.orders.listRefunds(scope);
    var refundsCount = 0;
    var refundsAmount = 0.0;
    for (final row in refunds) {
      final when = OrgTimezone.tryParseWallClock(row.createdOn, tzName);
      if (when == null) continue;
      if (when.isBefore(range.start) || !when.isBefore(range.end)) continue;
      refundsCount += 1;
      refundsAmount += row.amount;
    }

    return PosDashboardSnapshot(
      orderTypeCounts: orderTypeCounts,
      cancelledCount: cancelled,
      totalOrders: inRange.length,
      totalSales: totalSales,
      pendingAmount: double.parse(pendingAmount.toStringAsFixed(2)),
      pendingCount: pendingCount,
      cashShare: share(cash),
      cardShare: share(card),
      onlineShare: share(online),
      creditShare: share(credit),
      creditCount: creditCustomers.isEmpty
          ? openCredits.length
          : creditCustomers.length,
      creditOutstandingAmount: creditOutstanding,
      repaymentsAmount: repaymentsAmount,
      refundsCount: refundsCount,
      refundsAmount: refundsAmount,
      salesPoints: salesPoints,
      topCategories: topCategoryRows,
      topProducts: topProductRows,
      staffSales: staffSalesRows,
      creditOrders: creditOrders,
    );
  }

  ({String key, String label}) _resolveDashboardOrderType(
    String raw,
    List<PosOrderType> types,
  ) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    for (final type in types) {
      final keyNorm = type.key.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final labelNorm = type.label.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (keyNorm == normalized || labelNorm == normalized) {
        return (key: type.key, label: type.label);
      }
    }
    if (normalized.isEmpty) {
      return (key: 'UNKNOWN', label: 'Unknown');
    }
    final key = raw.trim().isEmpty ? 'UNKNOWN' : raw.trim().toUpperCase();
    return (key: key, label: raw.trim().isEmpty ? 'Unknown' : raw.trim());
  }

  /// IANA timezone for the open store (org/store config), if known.
  String? get _orgTimezoneName {
    try {
      final prefs = getIt<SharedPreferences>();
      return DeviceSetupStore(prefs).timezoneForStore(_store?.storeId);
    } catch (_) {
      return null;
    }
  }

  /// Public date window used by dashboard metrics and deep-linked list screens.
  ({DateTime start, DateTime end}) dashboardDateRangeForFilter(String filter) {
    return _dashboardDateRange(filter, _orgTimezoneName);
  }

  ({DateTime start, DateTime end}) _dashboardDateRange(
    String filter, [
    String? tzName,
  ]) {
    final now = OrgTimezone.nowWallClock(tzName);
    final today = OrgTimezone.startOfDay(now);
    switch (filter) {
      case 'All Time':
        return (
          start: DateTime(1970, 1, 1),
          end: today.add(const Duration(days: 1)),
        );
      case 'Yesterday':
        final start = today.subtract(const Duration(days: 1));
        return (start: start, end: today);
      case 'This Week':
        final weekday = today.weekday; // Mon=1
        final start = today.subtract(Duration(days: weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      case 'This Month':
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 1);
        return (start: start, end: end);
      case 'This Year':
        final start = DateTime(today.year, 1, 1);
        final end = DateTime(today.year + 1, 1, 1);
        return (start: start, end: end);
      case 'Today':
      default:
        return (start: today, end: today.add(const Duration(days: 1)));
    }
  }

  int _dashboardBucketIndex(DateTime when) {
    // Hour-of-day buckets (0–23) in organisation local time.
    return when.hour.clamp(0, 23);
  }

  List<String> _dashboardBucketLabels() {
    return [
      for (var hour = 0; hour < 24; hour++) _formatDashboardHourLabel(hour),
    ];
  }

  String _formatDashboardHourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'p' : 'a';
    return '$h12$suffix';
  }

  String _formatDashboardTime(String raw, [String? tzName]) {
    return OrgTimezone.formatTime(raw, tzName ?? _orgTimezoneName);
  }

  Future<StoreSyncBatchResult> runSyncNow() async {
    return syncFromRemote();
  }

  Future<void> refreshAccessControl() async {
    // No remote access refresh — device uses access seeded at setup.
    return;
  }

  Future<StoreSyncBatchResult> runSyncNowWithCallbacks({
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int exportBatchSize = StoreSyncService.defaultExportBatchSize,
  }) async {
    return syncFromRemote(onProgress: onProgress);
  }

  /// Full two-way sync for the open store; safe any time the operator taps
  /// Sync. Uploads pending local customers/orders/credits first, then downloads
  /// catalogue + watermarked order drifts (not a full order rebuild).
  Future<StoreSyncBatchResult> syncFromRemote({
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    // Concurrent imports into the same SQLite store fail mid-way (e.g. the
    // auto-sync kicked off by [openStore] racing the first catalogue sync).
    final previous = _syncInFlight;
    final done = Completer<void>();
    _syncInFlight = done.future;
    try {
      if (previous != null) await previous;
      return await _syncFromRemoteNow(onProgress: onProgress);
    } finally {
      done.complete();
      if (identical(_syncInFlight, done.future)) _syncInFlight = null;
    }
  }

  Future<StoreSyncBatchResult> _syncFromRemoteNow({
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    try {
      final store = _requireStore();
      // Ensure local tables/columns exist before any sync SQL runs.
      try {
        await store.ensureLocalSchema();
      } catch (_) {}
      // Repair older sealed configs (missing offers/wallets/export URLs) and
      // push them into the live store so this sync run uses the fixed endpoints.
      try {
        final prefs = getIt<SharedPreferences>();
        final setup = DeviceSetupStore(prefs);
        final repairedJson = setup.loadCachedConfigJson();
        if (repairedJson != null) {
          final repaired = StoreConfig.fromJson(repairedJson);
          _config = repaired;
          store.applyConfig(repaired);
          // Persist repaired export/import URLs so credits sync stops skipping.
          await setup.persistCachedConfig(repairedJson);
        }
      } catch (_) {}
      // Also refreshes the login lease length (ops can change it).
      try {
        await ensureDeviceAllowed();
      } on DeviceAccessDeniedException {
        _deviceSyncBlocked = true;
        rethrow;
      }
      if (_deviceSyncBlocked) {
        _deviceSyncBlocked = false;
        if (_deviceAutoSyncTimer == null) unawaited(applyDeviceAutoSync());
      }

      // Push local drifts before download so LWW cannot wipe them.
      final customerUpload = await store.sync.exportCustomers(
        store.scope,
        onProgress: onProgress,
      );
      final orderUpload = await store.sync.exportOrders(
        store.scope,
        onProgress: onProgress,
      );
      final creditUpload = await store.sync.exportCredits(
        store.scope,
        onProgress: onProgress,
      );
      // Store Setup catalogue (categories/products/offers) uploads before import.
      final productUpload = await store.sync.exportProducts(
        store.scope,
        onProgress: onProgress,
      );

      final download = await store.sync.importConfiguredCatalogue(
        store.scope,
        onProgress: onProgress,
        fullOrderRestore: false,
      );

      // Credits import carries store_settings + per-customer accounts.
      try {
        final importedSettings = store.credits.takeImportedStoreSettings();
        if (importedSettings != null && importedSettings.isNotEmpty) {
          final prefs = getIt<SharedPreferences>();
          final setup = DeviceSetupStore(prefs);
          await setup.mergeCreditSettings(importedSettings);
        }
      } catch (_) {}
      // Best-effort: cached order types keep working when the gateway is
      // unreachable, so a failure here must not fail the whole sync.
      try {
        final deviceId = await store.registeredDeviceId;
        await OrderTypesRepository.refresh(
          orgId: store.orgId,
          storeId: store.storeId,
          deviceId: deviceId,
        );
      } catch (_) {}

      final batch = StoreSyncBatchResult(
        operations: [
          customerUpload,
          orderUpload,
          creditUpload,
          productUpload,
          ...download.operations,
        ],
      );
      final hardFailure = batch.operations.any(
        (op) => !op.success && !op.skipped,
      );
      if (!hardFailure) {
        final settingsStore = await DeviceSettingsStore.open();
        await settingsStore.markSyncSucceeded();
        autoSyncFailed.value = false;
      } else {
        autoSyncFailed.value = true;
      }
      return batch;
    } catch (error) {
      autoSyncFailed.value = true;
      rethrow;
    }
  }

  /// Count of local orders not yet uploaded to the backend.
  Future<int> countPendingUploadOrders() async {
    final store = _requireStore();
    final summaries = await store.orders.listSummaries(store.scope);
    return summaries.where((order) => !order.exported).length;
  }

  /// Alias used by first-launch / store-open flows.
  Future<StoreSyncBatchResult> initialCatalogSync({
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    return syncFromRemote(onProgress: onProgress);
  }

  /// Explicit full rebuild (orders ignore watermark). Prefer [syncFromRemote]
  /// for routine Sync.
  Future<StoreSyncBatchResult> restoreFromRemote({
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) async {
    try {
      final store = _requireStore();
      final customerUpload = await store.sync.exportCustomers(
        store.scope,
        onProgress: onProgress,
      );
      final orderUpload = await store.sync.exportOrders(
        store.scope,
        onProgress: onProgress,
      );
      final creditUpload = await store.sync.exportCredits(
        store.scope,
        onProgress: onProgress,
      );
      final productUpload = await store.sync.exportProducts(
        store.scope,
        onProgress: onProgress,
      );
      final download = await store.sync.importConfiguredCatalogue(
        store.scope,
        onProgress: onProgress,
        fullOrderRestore: true,
      );
      try {
        final importedSettings = store.credits.takeImportedStoreSettings();
        if (importedSettings != null && importedSettings.isNotEmpty) {
          final prefs = getIt<SharedPreferences>();
          final setup = DeviceSetupStore(prefs);
          await setup.mergeCreditSettings(importedSettings);
        }
      } catch (_) {}
      return StoreSyncBatchResult(
        operations: [
          customerUpload,
          orderUpload,
          creditUpload,
          productUpload,
          ...download.operations,
        ],
      );
    } catch (error) {
      autoSyncFailed.value = true;
      rethrow;
    }
  }

  Future<List<StoreSyncAttemptRecord>> loadSyncHistory({int limit = 500}) {
    final store = _requireStore();
    return store.sync.history(store.scope, limit: limit);
  }

  /// Current on-device sync preferences (auto sync + interval).
  Future<DeviceSyncSettings> loadDeviceSyncSettings() async {
    final store = await DeviceSettingsStore.open();
    return store.load();
  }

  Future<DateTime?> lastSuccessfulSyncAt() async {
    final store = await DeviceSettingsStore.open();
    return store.lastSuccessfulSyncAt();
  }

  /// Throws [DeviceAccessDeniedException] unless the organisation has this
  /// device approved. Asks the gateway when reachable; offline it trusts the
  /// last status the gateway reported.
  Future<void> ensureDeviceAllowed({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    DeviceApproval? approval;
    try {
      approval = await refreshLoginLeaseFromServer().timeout(timeout);
    } catch (_) {}

    if (approval != null) {
      if (approval.approved) return;
      stopDeviceAutoSync();
      throw DeviceAccessDeniedException(approval.status);
    }

    await ensureDeviceAllowedOffline();
  }

  /// Device check from the last known status only; never touches the network.
  Future<void> ensureDeviceAllowedOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = (prefs.getString(DeviceApprovalService.statusKey) ?? '')
        .trim()
        .toLowerCase();
    if (cached.isNotEmpty && cached != 'active' && cached != 'unknown') {
      stopDeviceAutoSync();
      throw DeviceAccessDeniedException(cached);
    }
  }

  /// Pulls `login_lease_minutes` from the gateway device status endpoint.
  ///
  /// Returns the approval so callers can stop work for suspended devices.
  Future<DeviceApproval?> refreshLoginLeaseFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final orgRef =
        prefs.getString('orgCode') ??
        prefs.getString(DeviceApprovalService.orgIdKey) ??
        _organisation?.orgCode ??
        _organisation?.orgId ??
        '';
    if (orgRef.trim().isEmpty) return null;

    final deviceId = posDeviceId(prefs);
    final approval = await DeviceApprovalService(
      prefs,
    ).check(orgRef: orgRef.trim(), deviceId: deviceId);
    final lease = approval.loginLeaseMinutes;
    if (lease != null && lease > 0) {
      final leaseStore = await LoginLeaseStore.open();
      await leaseStore.setLeaseMinutes(lease);
    }
    return approval;
  }

  /// Snapshot used by Device Settings (POS code, hardware id, sync prefs).
  Future<DeviceSettingsSnapshot> loadDeviceSettingsSnapshot() async {
    final store = _requireStore();
    final settingsStore = await DeviceSettingsStore.open();
    final settings = settingsStore.load();
    final leaseStore = await LoginLeaseStore.open();
    final deviceId = await store.registeredDeviceId;
    final registration = _deviceRegistration;
    var posCode = (_organisation?.posCode ?? '').trim();
    if (posCode.isEmpty) {
      posCode = organisationPosCode.trim();
    }
    return DeviceSettingsSnapshot(
      posCode: posCode,
      deviceId: deviceId ?? registration?.deviceId ?? '',
      make: registration?.make ?? '',
      model: registration?.model ?? '',
      storeName: store.storeName,
      storeId: store.storeId,
      orgName: _organisation?.orgName ?? store.orgName,
      orgCode: _organisation?.orgCode ?? store.orgCode,
      syncSettings: settings,
      lastSuccessfulSyncAt: settingsStore.lastSuccessfulSyncAt(),
      autoSyncRunning: _deviceAutoSyncTimer?.isActive ?? false,
      loginLeaseDays: leaseStore.leaseDays,
      loginLeaseMinutes: leaseStore.leaseMinutes,
      lastOnlineLoginAt: leaseStore.lastOnlineLoginAt,
      onlineLoginValidUntil: leaseStore.validUntil,
    );
  }

  /// Persist sync prefs and (re)start the on-device auto-sync timer.
  Future<void> updateDeviceSyncSettings(DeviceSyncSettings settings) async {
    final store = await DeviceSettingsStore.open();
    await store.save(settings);
    await applyDeviceAutoSync();
  }

  /// Start / stop periodic sync from device settings (independent of gateway
  /// config ``auto_sync_enabled``, which stays off for offline-first setups).
  Future<void> applyDeviceAutoSync() async {
    _deviceAutoSyncTimer?.cancel();
    _deviceAutoSyncTimer = null;

    if (_store == null) return;

    final settingsStore = await DeviceSettingsStore.open();
    final settings = settingsStore.load();
    if (!settings.autoSyncEnabled) return;

    // Run once immediately so enabling auto-sync does not wait a full interval.
    unawaited(_runDeviceAutoSync());
    _deviceAutoSyncTimer = Timer.periodic(
      Duration(seconds: settings.intervalSeconds),
      (_) {
        unawaited(_runDeviceAutoSync());
      },
    );
  }

  Future<void> _runDeviceAutoSync() async {
    if (_deviceAutoSyncInProgress || _syncInFlight != null || _store == null) {
      return;
    }
    final reachable = await NetworkReachability.canReachGateway();
    if (!reachable) return;
    _deviceAutoSyncInProgress = true;
    try {
      await syncFromRemote();
    } catch (_) {
      // Flag set inside syncFromRemote; keep auto-sync running.
    } finally {
      _deviceAutoSyncInProgress = false;
    }
  }

  Future<void> logout() async {
    stopDeviceAutoSync();
    final store = _requireStore();
    await store.auth.logout();
  }

  /// Stops sync, closes the offline store, and wipes local DB + settings.
  ///
  /// Use for from-scratch device testing. Does not call the remote revoke API.
  Future<DeviceLocalResetResult> resetAllLocalData({
    bool keepSavedServers = true,
    Set<String> preserveKeys = const {},
  }) async {
    stopDeviceAutoSync();
    try {
      await _store?.close();
    } catch (_) {}
    _store = null;
    _config = null;
    _organisation = null;
    _organisationLogin = null;
    _bootstrap = null;
    _deviceRegistration = null;

    final prefs = await SharedPreferences.getInstance();
    return DeviceLocalResetService(prefs).resetAllLocalData(
      keepSavedServers: keepSavedServers,
      preserveKeys: preserveKeys,
    );
  }

  void stopDeviceAutoSync() {
    _deviceAutoSyncTimer?.cancel();
    _deviceAutoSyncTimer = null;
  }

  Future<void> dispose() async {
    stopDeviceAutoSync();
    autoSyncFailed.dispose();
    await _store?.close();
    _store = null;
  }

  StoreConfig _requireConfig() {
    final config = _config;
    if (config == null) {
      throw StateError('Controller is not booted. Call boot() first.');
    }
    return config;
  }

  StoreOrganisationLoginResult _requireOrganisationLogin() {
    final login = _organisationLogin;
    if (login == null) {
      throw StateError(
        'Organisation login is required before selecting a store.',
      );
    }
    return login;
  }

  StoreOrganisation _requireOrganisation() {
    final organisation = _organisation;
    if (organisation == null) {
      throw StateError(
        'Organisation must be resolved before registering the device.',
      );
    }
    return organisation;
  }

  StoreDeviceRegistrationRequest _requireDeviceRegistration() {
    final deviceRegistration = _deviceRegistration;
    if (deviceRegistration == null) {
      throw StateError('Register the device before selecting a store.');
    }
    return deviceRegistration;
  }

  Store _requireStore() {
    final store = _store;
    if (store == null) {
      throw StateError('Store is not initialized. Call boot() first.');
    }
    return store;
  }
}

class StaffUnlockResult {
  final bool ok;
  final String? storeId;
  final String? message;
  final bool needsStorePicker;
  final bool needsOnlineRenew;

  const StaffUnlockResult({
    required this.ok,
    this.storeId,
    this.message,
    this.needsStorePicker = false,
    this.needsOnlineRenew = false,
  });
}

/// One local operator shown on the staff unlock screen.
class PosStaffOption {
  final String customerId;
  final String name;

  /// Preferred unlock login: reg number, else email.
  final String identifier;

  const PosStaffOption({
    required this.customerId,
    required this.name,
    required this.identifier,
  });
}
