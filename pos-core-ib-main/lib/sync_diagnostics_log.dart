import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'store_models.dart';

/// Append-only JSONL sync diagnostics kept beside the SQLite DB.
///
/// Retention is time-based (default 45 days). Selling offline never depends on
/// this file — failures here are swallowed.
class StoreSyncDiagnosticsLog {
  StoreSyncDiagnosticsLog._();

  static const int keepDays = 45;
  static const String fileName = 'sync_diagnostics.jsonl';

  static Future<void> append(
    StoreSyncOperationResult result, {
    required String dbFilePath,
  }) async {
    try {
      final dir = Directory(p.dirname(dbFilePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, fileName));
      final line = jsonEncode({
        'entity': result.entity,
        'direction': result.direction,
        'started_at': result.startedAt,
        'completed_at': result.completedAt,
        'processed_count': result.processedCount,
        'success_count': result.successCount,
        'failure_count': result.failureCount,
        'skipped': result.skipped,
        'success': result.success,
        'message': result.message,
        'logged_at': DateTime.now().toUtc().toIso8601String(),
      });
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      await _prune(file);
    } catch (_) {
      // Diagnostics must never break sync.
    }
  }

  static Future<void> _prune(File file) async {
    if (!await file.exists()) return;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: keepDays));
    final lines = await file.readAsLines();
    if (lines.length < 50) {
      // Cheap path: only rewrite when the file has grown.
      return;
    }
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final row = jsonDecode(trimmed);
        if (row is! Map) continue;
        final raw = '${row['logged_at'] ?? row['started_at'] ?? ''}'.trim();
        final when = DateTime.tryParse(raw)?.toUtc();
        if (when == null || !when.isBefore(cutoff)) {
          kept.add(trimmed);
        }
      } catch (_) {
        // Drop corrupt lines.
      }
    }
    if (kept.length != lines.where((l) => l.trim().isNotEmpty).length) {
      await file.writeAsString(
        kept.isEmpty ? '' : '${kept.join('\n')}\n',
        flush: true,
      );
    }
  }
}
