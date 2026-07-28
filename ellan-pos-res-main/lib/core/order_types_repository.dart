import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/discovery_constants.dart';

/// One order type synced from the backend (`store_order_types`).
class PosOrderType {
  final String key;
  final String label;
  final int sortingOrder;
  final bool addressRequired;

  const PosOrderType({
    required this.key,
    required this.label,
    this.sortingOrder = 0,
    this.addressRequired = false,
  });

  /// Dine-in types drive the floor/table selection flow on the tablet.
  bool get isDineIn => key.replaceAll(RegExp(r'[^A-Z]'), '') == 'DINEIN';

  factory PosOrderType.fromJson(Map<String, dynamic> json) {
    return PosOrderType(
      key: (json['key'] ?? '').toString().trim().toUpperCase(),
      label: (json['label'] ?? '').toString().trim(),
      sortingOrder: int.tryParse('${json['sorting_order'] ?? 0}') ?? 0,
      addressRequired: json['address_required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'sorting_order': sortingOrder,
        'address_required': addressRequired,
      };
}

/// Fetches order types from the POS gateway and caches them on-device so the
/// order-creation sheet works offline.
class OrderTypesRepository {
  static const _prefsPrefix = 'pos_order_types_';

  /// Used until the first successful sync (and as an offline fallback).
  static const List<PosOrderType> defaults = [
    PosOrderType(key: 'PICKUP', label: 'Pickup', sortingOrder: 2),
    PosOrderType(key: 'DINEIN', label: 'Dine-In', sortingOrder: 3),
  ];

  static String _cacheKey(String orgId, String storeId) =>
      '$_prefsPrefix${orgId}_$storeId';

  /// Cached order types for the store, or [defaults] when nothing synced yet.
  static Future<List<PosOrderType>> load({
    required String orgId,
    required String storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(orgId, storeId));
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return defaults;
      final types = decoded
          .whereType<Map>()
          .map((row) => PosOrderType.fromJson(row.cast<String, dynamic>()))
          .where((type) => type.key.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortingOrder.compareTo(b.sortingOrder));
      return types.isEmpty ? defaults : types;
    } catch (_) {
      return defaults;
    }
  }

  /// Downloads order types from the gateway and refreshes the local cache.
  /// Returns the fetched list; throws on network/HTTP failure.
  static Future<List<PosOrderType>> refresh({
    required String orgId,
    required String storeId,
    String? deviceId,
  }) async {
    final queryParameters = <String, String>{
      'orgId': orgId,
      'storeId': storeId,
      'limit': '100',
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      queryParameters['deviceId'] = deviceId;
    }
    final uri = Uri.parse(kDiscoveryUrl).replace(
      path: '/api/pos/order_types/import',
      queryParameters: queryParameters,
    );
    final response = await http.get(
      uri,
      headers: {
        if (deviceId != null && deviceId.isNotEmpty) 'X-Pos-Device-Id': deviceId,
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Order types sync failed with status ${response.statusCode}.',
      );
    }
    final body = jsonDecode(response.body);
    final rows = body is Map ? body['data'] : null;
    if (rows is! List) {
      throw StateError('Order types sync returned no data.');
    }
    final types = rows
        .whereType<Map>()
        .map((row) => PosOrderType.fromJson(row.cast<String, dynamic>()))
        .where((type) => type.key.isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortingOrder.compareTo(b.sortingOrder));

    final prefs = await SharedPreferences.getInstance();
    if (types.isEmpty) {
      // Keep whatever was cached; an empty backend list must not wipe the UI.
      return load(orgId: orgId, storeId: storeId);
    }
    await prefs.setString(
      _cacheKey(orgId, storeId),
      jsonEncode(types.map((type) => type.toJson()).toList()),
    );
    return types;
  }
}
