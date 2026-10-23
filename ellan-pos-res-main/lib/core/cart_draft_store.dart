import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/data/models/cart_discount_line.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
import 'package:pos_tablet/data/models/order_history_model.dart';
import 'package:pos_tablet/data/models/product_model.dart';

class CartDraftArgs {
  final String orderType;
  final String? orderTypeKey;
  final String pricingMode;
  final String? name;
  final String? phone;
  final String? email;
  final String? customerUniqueId;
  final String? floor;
  final String? table;
  final String? tableId;
  final int? openOrderId;

  const CartDraftArgs({
    required this.orderType,
    this.orderTypeKey,
    this.pricingMode = 'selling',
    this.name,
    this.phone,
    this.email,
    this.customerUniqueId,
    this.floor,
    this.table,
    this.tableId,
    this.openOrderId,
  });

  Map<String, dynamic> toJson() => {
    'orderType': orderType,
    'orderTypeKey': orderTypeKey,
    'pricingMode': pricingMode,
    'name': name,
    'phone': phone,
    'email': email,
    'customerUniqueId': customerUniqueId,
    'floor': floor,
    'table': table,
    'tableId': tableId,
    'openOrderId': openOrderId,
  };

  factory CartDraftArgs.fromJson(Map<String, dynamic> json) {
    return CartDraftArgs(
      orderType: '${json['orderType'] ?? 'Pickup'}',
      orderTypeKey: json['orderTypeKey'] as String?,
      pricingMode: '${json['pricingMode'] ?? 'selling'}',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      customerUniqueId: json['customerUniqueId'] as String?,
      floor: json['floor'] as String?,
      table: json['table'] as String?,
      tableId: json['tableId'] as String?,
      openOrderId: (json['openOrderId'] as num?)?.toInt(),
    );
  }
}

/// One saved cart draft that can reopen the order screen.
class CartDraft {
  final String id;
  final DateTime savedAt;
  final CartDraftArgs args;
  final List<CartItem> items;
  final List<CartDiscountLine> discounts;
  final double serviceTaxPercentage;
  final double tipsAmount;
  final double deliveryCharge;
  final double netTotal;
  final List<OrderHistoryModel> orderHistory;

  const CartDraft({
    required this.id,
    required this.savedAt,
    required this.args,
    required this.items,
    this.discounts = const [],
    this.serviceTaxPercentage = 0,
    this.tipsAmount = 0,
    this.deliveryCharge = 0,
    required this.netTotal,
    this.orderHistory = const [],
  });

  String get title {
    final name = (args.name ?? '').trim();
    if (name.isNotEmpty) return name;
    final table = (args.table ?? '').trim();
    if (table.isNotEmpty) {
      return '${args.orderType} · $table';
    }
    return args.orderType;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'args': args.toJson(),
    'items': [for (final item in items) _itemToJson(item)],
    'orderHistory': [
      for (final ticket in orderHistory)
        {
          'id': ticket.id,
          'orderId': ticket.orderId,
          'kotBatch': ticket.kotBatch,
          'totalAmount': ticket.totalAmount,
          'timestamp': ticket.timestamp.toUtc().toIso8601String(),
          'items': [for (final item in ticket.items) _itemToJson(item)],
        },
    ],
    'discounts': [
      for (final d in discounts)
        {
          'id': d.id,
          'title': d.title,
          'percentage': d.percentage,
          'flatAmount': d.flatAmount,
          'targetLineSignature': d.targetLineSignature,
          'targetItemName': d.targetItemName,
        },
    ],
    'serviceTaxPercentage': serviceTaxPercentage,
    'tipsAmount': tipsAmount,
    'deliveryCharge': deliveryCharge,
    'netTotal': netTotal,
  };

  factory CartDraft.fromJson(Map<String, dynamic> json) {
    final argsMap = (json['args'] as Map?)?.cast<String, dynamic>() ?? const {};
    final itemsRaw = json['items'] as List? ?? const [];
    final discountsRaw = json['discounts'] as List? ?? const [];
    final savedAt =
        DateTime.tryParse('${json['savedAt'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final args = CartDraftArgs.fromJson(argsMap);
    final items = [
      for (final row in itemsRaw)
        if (row is Map) _itemFromJson(row.cast<String, dynamic>()),
    ];
    return CartDraft(
      id: '${json['id'] ?? ''}',
      savedAt: savedAt,
      args: args,
      items: items,
      discounts: [
        for (final d in discountsRaw)
          if (d is Map)
            CartDiscountLine(
              id: '${d['id'] ?? ''}',
              title: '${d['title'] ?? 'Discount'}',
              percentage: (d['percentage'] as num?)?.toDouble() ?? 0,
              flatAmount: (d['flatAmount'] as num?)?.toDouble() ?? 0,
              targetLineSignature: d['targetLineSignature'] as String?,
              targetItemName: d['targetItemName'] as String?,
            ),
      ],
      serviceTaxPercentage:
          (json['serviceTaxPercentage'] as num?)?.toDouble() ?? 0,
      tipsAmount: (json['tipsAmount'] as num?)?.toDouble() ?? 0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0,
      netTotal: (json['netTotal'] as num?)?.toDouble() ?? 0,
      orderHistory: _historyFromJson(json, items, args, savedAt),
    );
  }
}

Map<String, dynamic> _itemToJson(CartItem item) => {
  'product': {
    'id': item.product.id,
    'name': item.product.name,
    'productName': item.product.productName,
    'variantName': item.product.variantName,
    'description': item.product.description,
    'price': item.product.price,
    'imageUrl': item.product.imageUrl,
    'categoryId': item.product.categoryId,
    'offerTag': item.product.offerTag,
    'sellUnitCode': item.product.sellUnitCode,
    'sellUnitShort': item.product.sellUnitShort,
    'sellUnitLabel': item.product.sellUnitLabel,
    'sellUnitBaseQty': item.product.sellUnitBaseQty,
    'isMisc': item.product.isMisc,
  },
  'quantity': item.quantity,
  'kotSentQuantity': item.kotSentQuantity,
  'addons': [
    for (final addon in item.addons)
      {
        'addonGroupId': addon.addonGroupId,
        'addonGroupName': addon.addonGroupName,
        'minSelections': addon.minSelections,
        'maxSelections': addon.maxSelections,
        'addonItemId': addon.addonItemId,
        'addonItemName': addon.addonItemName,
        'quantity': addon.quantity,
        'unitPrice': addon.unitPrice,
      },
  ],
};

CartItem _itemFromJson(Map<String, dynamic> row) {
  final product =
      (row['product'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  return CartItem(
    product: Product(
      id: '${product['id'] ?? ''}',
      name: '${product['name'] ?? ''}',
      productName: '${product['productName'] ?? ''}',
      variantName: '${product['variantName'] ?? ''}',
      description: '${product['description'] ?? ''}',
      price: (product['price'] as num?)?.toDouble() ?? 0,
      imageUrl: '${product['imageUrl'] ?? ''}',
      categoryId: '${product['categoryId'] ?? 'all'}',
      offerTag: product['offerTag'] as String?,
      sellUnitCode: (product['sellUnitCode'] as num?)?.toInt(),
      sellUnitShort: product['sellUnitShort'] as String?,
      sellUnitLabel: product['sellUnitLabel'] as String?,
      sellUnitBaseQty: (product['sellUnitBaseQty'] as num?)?.toDouble(),
      isMisc: product['isMisc'] == true,
    ),
    quantity: (row['quantity'] as num?)?.toDouble() ?? 1,
    kotSentQuantity: (row['kotSentQuantity'] as num?)?.toDouble() ?? 0,
    addons: [
      for (final addon in (row['addons'] as List? ?? const []))
        if (addon is Map)
          CartAddonSelection(
            addonGroupId: '${addon['addonGroupId'] ?? ''}',
            addonGroupName: '${addon['addonGroupName'] ?? ''}',
            minSelections: (addon['minSelections'] as num?)?.toInt() ?? 0,
            maxSelections: (addon['maxSelections'] as num?)?.toInt(),
            addonItemId: '${addon['addonItemId'] ?? ''}',
            addonItemName: '${addon['addonItemName'] ?? ''}',
            quantity: (addon['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (addon['unitPrice'] as num?)?.toDouble() ?? 0,
          ),
    ],
  );
}

List<OrderHistoryModel> _historyFromJson(
  Map<String, dynamic> json,
  List<CartItem> items,
  CartDraftArgs args,
  DateTime savedAt,
) {
  final raw = json['orderHistory'];
  if (raw is List && raw.isNotEmpty) {
    return [
      for (final row in raw)
        if (row is Map)
          OrderHistoryModel(
            id: '${row['id'] ?? 'KOT'}',
            orderId: (row['orderId'] as num?)?.toInt(),
            kotBatch: (row['kotBatch'] as num?)?.toInt(),
            totalAmount: (row['totalAmount'] as num?)?.toDouble() ?? 0,
            timestamp:
                DateTime.tryParse('${row['timestamp'] ?? ''}')?.toLocal() ??
                savedAt,
            items: [
              for (final item in (row['items'] as List? ?? const []))
                if (item is Map) _itemFromJson(item.cast<String, dynamic>()),
            ],
          ),
    ];
  }
  final sent = [
    for (final item in items)
      if (item.kotSentQuantity > 0.0001)
        item.copyWith(
          quantity: item.kotSentQuantity,
          kotSentQuantity: item.kotSentQuantity,
        ),
  ];
  if (sent.isEmpty) return const [];
  return [
    OrderHistoryModel(
      id: 'KOT',
      orderId: args.openOrderId,
      items: sent,
      totalAmount: sent.fold<double>(0, (sum, item) => sum + item.totalPrice),
      timestamp: savedAt,
    ),
  ];
}

class CartDraftStore {
  CartDraftStore._();

  static const _key = 'posCartDrafts';
  static const _maxDrafts = 20;

  static String _newId() =>
      'draft-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  static Future<List<CartDraft>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final drafts = <CartDraft>[];
      for (final row in decoded) {
        if (row is! Map) continue;
        try {
          drafts.add(CartDraft.fromJson(row.cast<String, dynamic>()));
        } catch (_) {}
      }
      drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return drafts;
    } catch (_) {
      return const [];
    }
  }

  static Future<CartDraft> save({
    String? existingId,
    required CartDraftArgs args,
    required List<CartItem> items,
    required List<CartDiscountLine> discounts,
    required double serviceTaxPercentage,
    required double tipsAmount,
    required double deliveryCharge,
    required double netTotal,
    List<OrderHistoryModel> orderHistory = const [],
  }) async {
    if (items.isEmpty) {
      throw StateError('Cannot save an empty draft.');
    }
    final draft = CartDraft(
      id: (existingId != null && existingId.isNotEmpty) ? existingId : _newId(),
      savedAt: DateTime.now(),
      args: args,
      items: List<CartItem>.from(items),
      discounts: List<CartDiscountLine>.from(discounts),
      serviceTaxPercentage: serviceTaxPercentage,
      tipsAmount: tipsAmount,
      deliveryCharge: deliveryCharge,
      netTotal: netTotal,
      orderHistory: List<OrderHistoryModel>.from(orderHistory),
    );
    final current = await list();
    final next = <CartDraft>[
      draft,
      ...current.where((row) => row.id != draft.id),
    ].take(_maxDrafts).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final row in next) row.toJson()]),
    );
    return draft;
  }

  static Future<void> delete(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _removeWhere((row) => row.id == trimmed);
  }

  static Future<void> deleteForOrder(int orderId) {
    return _removeWhere((row) => row.args.openOrderId == orderId);
  }

  static Future<void> _removeWhere(bool Function(CartDraft row) test) async {
    final current = await list();
    final next = current.where((row) => !test(row)).toList();
    if (next.length == current.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final row in next) row.toJson()]),
    );
  }
}
