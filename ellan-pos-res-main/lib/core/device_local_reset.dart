import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pos_orders_offline/sqflite_ffi_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wipes on-device POS state so the tablet can be tested from a clean first launch.
///
/// Clears:
/// - SQLite databases under the app-support `databases/` folder
/// - `pos_device_setup/` JSON caches (bootstrap, config, customers)
/// - All SharedPreferences (auth, device approval, sync settings, setup flags)
class DeviceLocalResetService {
  final SharedPreferences prefs;

  const DeviceLocalResetService(this.prefs);

  /// Destructive full wipe. Caller must stop auto-sync and close any open Store first.
  Future<DeviceLocalResetResult> resetAllLocalData({
    bool keepSavedServers = false,
  }) async {
    final keptServers = keepSavedServers ? _snapshotServerEntries() : null;
    final keptActiveServer = keepSavedServers
        ? prefs.getString('posActiveServerUrl')
        : null;
    final keptActiveOrg = keepSavedServers
        ? prefs.getString('posActiveOrgInstanceId')
        : null;

    final deletedDatabases = await _deleteDatabases();
    final deletedSetupFiles = await _deleteSetupDirectory();
    await prefs.clear();

    if (keepSavedServers && keptServers != null) {
      if (keptServers.isNotEmpty) {
        await prefs.setString('posServerEntries', keptServers);
      }
      if (keptActiveServer != null && keptActiveServer.trim().isNotEmpty) {
        await prefs.setString('posActiveServerUrl', keptActiveServer);
      }
      if (keptActiveOrg != null && keptActiveOrg.trim().isNotEmpty) {
        await prefs.setString('posActiveOrgInstanceId', keptActiveOrg);
      }
    }

    return DeviceLocalResetResult(
      deletedDatabaseCount: deletedDatabases,
      deletedSetupDirectory: deletedSetupFiles,
      preferencesCleared: true,
      keptSavedServers: keepSavedServers,
    );
  }

  String? _snapshotServerEntries() => prefs.getString('posServerEntries');

  Future<int> _deleteDatabases() async {
    var deleted = 0;
    try {
      final dbPath = await databaseFactory.getDatabasesPath();
      final dir = Directory(dbPath);
      if (!await dir.exists()) {
        return 0;
      }
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;
        final lower = name.toLowerCase();
        if (!lower.endsWith('.db') && !lower.endsWith('.db-journal') && !lower.endsWith('.db-wal') && !lower.endsWith('.db-shm')) {
          continue;
        }
        try {
          if (lower.endsWith('.db')) {
            await databaseFactory.deleteDatabase(entity.path);
          } else if (await entity.exists()) {
            await entity.delete();
          }
          deleted += 1;
        } catch (_) {
          try {
            if (await entity.exists()) {
              await entity.delete();
              deleted += 1;
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Fall through — prefs/setup wipe still useful.
    }
    return deleted;
  }

  Future<bool> _deleteSetupDirectory() async {
    try {
      final root = await getApplicationSupportDirectory();
      final dir = Directory('${root.path}/pos_device_setup');
      if (!await dir.exists()) return false;
      await dir.delete(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class DeviceLocalResetResult {
  final int deletedDatabaseCount;
  final bool deletedSetupDirectory;
  final bool preferencesCleared;
  final bool keptSavedServers;

  const DeviceLocalResetResult({
    required this.deletedDatabaseCount,
    required this.deletedSetupDirectory,
    required this.preferencesCleared,
    required this.keptSavedServers,
  });
}
