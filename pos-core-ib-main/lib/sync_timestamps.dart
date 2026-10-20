/// Timestamp keys whose values are instants (not calendar dates).
const Set<String> syncInstantTimestampKeys = {
  'created_on',
  'updated_on',
  'createdOn',
  'updatedOn',
  'created_at',
  'updated_at',
  'createdAt',
  'updatedAt',
  'paid_on',
  'paid_at',
  'settled_on',
  'settled_at',
  'voided_on',
  'voided_at',
  'cancelled_on',
  'cancelled_at',
  'refunded_on',
  'kitchen_sent_at',
  'kitchenSentAt',
  'repaid_on',
  'repayment_on',
};

final RegExp _explicitZone = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$');
final RegExp _hasTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');

/// Rewrites a naive (device-local) ISO timestamp as UTC `…Z`.
///
/// The server interprets naive values as UTC, so local wall-clock strings
/// written with `DateTime.now().toIso8601String()` would shift by the device
/// offset. Values that already carry a zone, or date-only values, are kept.
String normalizeSyncTimestamp(String raw) {
  final value = raw.trim();
  if (!_hasTime.hasMatch(value) || _explicitZone.hasMatch(value)) {
    return raw;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.isUtc) return raw;
  return parsed.toUtc().toIso8601String();
}

/// Deep-copies an export payload, normalizing instant timestamp fields to UTC.
Object? normalizeSyncPayloadTimestamps(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        '${entry.key}':
            syncInstantTimestampKeys.contains('${entry.key}') &&
                entry.value is String
            ? normalizeSyncTimestamp(entry.value as String)
            : normalizeSyncPayloadTimestamps(entry.value),
    };
  }
  if (value is List) {
    return value.map(normalizeSyncPayloadTimestamps).toList(growable: false);
  }
  return value;
}
