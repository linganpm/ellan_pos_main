import 'package:shared_preferences/shared_preferences.dart';

/// On-device POS settings that operators can change without re-registering.
class DeviceSyncSettings {
  final bool autoSyncEnabled;
  final int intervalSeconds;

  const DeviceSyncSettings({
    required this.autoSyncEnabled,
    required this.intervalSeconds,
  });

  static const defaults = DeviceSyncSettings(
    autoSyncEnabled: true,
    intervalSeconds: 300,
  );

  /// Presets shown in Device Settings.
  static const intervalOptions = <({int seconds, String label})>[
    (seconds: 60, label: 'Every 1 minute'),
    (seconds: 300, label: 'Every 5 minutes'),
    (seconds: 900, label: 'Every 15 minutes'),
    (seconds: 1800, label: 'Every 30 minutes'),
    (seconds: 3600, label: 'Every 1 hour'),
  ];

  String get intervalLabel {
    for (final option in intervalOptions) {
      if (option.seconds == intervalSeconds) return option.label;
    }
    final minutes = intervalSeconds ~/ 60;
    if (minutes >= 1) return 'Every $minutes minute${minutes == 1 ? '' : 's'}';
    return 'Every $intervalSeconds seconds';
  }

  DeviceSyncSettings copyWith({
    bool? autoSyncEnabled,
    int? intervalSeconds,
  }) {
    return DeviceSyncSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }
}

/// Read-only snapshot for the Device Settings screen.
class DeviceSettingsSnapshot {
  final String posCode;
  final String deviceId;
  final String make;
  final String model;
  final String storeName;
  final String storeId;
  final String orgName;
  final String orgCode;
  final DeviceSyncSettings syncSettings;
  final DateTime? lastSuccessfulSyncAt;
  final bool autoSyncRunning;
  final double loginLeaseDays;
  final int loginLeaseMinutes;
  final DateTime? lastOnlineLoginAt;
  final DateTime? onlineLoginValidUntil;

  const DeviceSettingsSnapshot({
    required this.posCode,
    required this.deviceId,
    required this.make,
    required this.model,
    required this.storeName,
    required this.storeId,
    required this.orgName,
    required this.orgCode,
    required this.syncSettings,
    required this.lastSuccessfulSyncAt,
    required this.autoSyncRunning,
    this.loginLeaseDays = 7,
    this.loginLeaseMinutes = 7 * 24 * 60,
    this.lastOnlineLoginAt,
    this.onlineLoginValidUntil,
  });
}

/// Persists device sync preferences in SharedPreferences.
class DeviceSettingsStore {
  static const _autoSyncKey = 'pos_device_auto_sync_enabled';
  static const _intervalKey = 'pos_device_sync_interval_seconds';
  static const lastSyncAtKey = 'posLastSuccessfulSyncAt';
  static const cashDenominationsKey = 'pos_cash_denominations';
  static const defaultCashDenominations = '5, 10, 20, 50, 100, 500';

  final SharedPreferences _prefs;

  DeviceSettingsStore(this._prefs);

  static Future<DeviceSettingsStore> open() async {
    return DeviceSettingsStore(await SharedPreferences.getInstance());
  }

  DeviceSyncSettings load() {
    final enabled = _prefs.getBool(_autoSyncKey);
    final interval = _prefs.getInt(_intervalKey);
    return DeviceSyncSettings(
      autoSyncEnabled: enabled ?? DeviceSyncSettings.defaults.autoSyncEnabled,
      intervalSeconds: _normalizeInterval(
        interval ?? DeviceSyncSettings.defaults.intervalSeconds,
      ),
    );
  }

  Future<void> save(DeviceSyncSettings settings) async {
    await _prefs.setBool(_autoSyncKey, settings.autoSyncEnabled);
    await _prefs.setInt(
      _intervalKey,
      _normalizeInterval(settings.intervalSeconds),
    );
  }

  String loadCashDenominationsRaw() {
    final raw = (_prefs.getString(cashDenominationsKey) ?? '').trim();
    return raw.isEmpty ? defaultCashDenominations : raw;
  }

  List<double> loadCashDenominations() {
    return parseCashDenominations(loadCashDenominationsRaw());
  }

  Future<void> saveCashDenominationsRaw(String raw) async {
    final cleaned = raw.trim().isEmpty ? defaultCashDenominations : raw.trim();
    await _prefs.setString(cashDenominationsKey, cleaned);
  }

  static List<double> parseCashDenominations(String raw) {
    final values = <double>[];
    for (final part in raw.split(',')) {
      final n = double.tryParse(part.trim());
      if (n != null && n > 0) values.add(n);
    }
    if (values.isEmpty) {
      return parseCashDenominations(defaultCashDenominations);
    }
    return values;
  }

  DateTime? lastSuccessfulSyncAt() {
    final raw = _prefs.getString(lastSyncAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markSyncSucceeded([DateTime? when]) async {
    await _prefs.setString(
      lastSyncAtKey,
      (when ?? DateTime.now()).toIso8601String(),
    );
  }

  static int _normalizeInterval(int seconds) {
    if (seconds < 60) return 60;
    if (seconds > 86400) return 86400;
    return seconds;
  }
}
