import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/data/models/cart_discount_line.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
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
    'items': [
      for (final item in items)
        {
          'product': {
            'id': item.product.id,
            'name': item.product.name,
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
        },
    ],
    'discounts': [
      for (final d in discounts)
        {
          'id': d.id,
          'title': d.title,
          'percentage': d.percentage,
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
    return CartDraft(
      id: '${json['id'] ?? ''}',
      savedAt:
          DateTime.tryParse('${json['savedAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      args: CartDraftArgs.fromJson(argsMap),
      items: [
        for (final row in itemsRaw)
          if (row is Map)
            CartItem(
              product: Product(
                id: '${(row['product'] as Map?)?['id'] ?? ''}',
                name: '${(row['product'] as Map?)?['name'] ?? ''}',
                description:
                    '${(row['product'] as Map?)?['description'] ?? ''}',
                price:
                    ((row['product'] as Map?)?['price'] as num?)?.toDouble() ??
                    0,
                imageUrl: '${(row['product'] as Map?)?['imageUrl'] ?? ''}',
                categoryId:
                    '${(row['product'] as Map?)?['categoryId'] ?? 'all'}',
                offerTag: (row['product'] as Map?)?['offerTag'] as String?,
                sellUnitCode:
                    ((row['product'] as Map?)?['sellUnitCode'] as num?)
                        ?.toInt(),
                sellUnitShort:
                    (row['product'] as Map?)?['sellUnitShort'] as String?,
                sellUnitLabel:
                    (row['product'] as Map?)?['sellUnitLabel'] as String?,
                sellUnitBaseQty:
                    ((row['product'] as Map?)?['sellUnitBaseQty'] as num?)
                        ?.toDouble(),
                isMisc: (row['product'] as Map?)?['isMisc'] == true,
              ),
              quantity: (row['quantity'] as num?)?.toDouble() ?? 1,
              kotSentQuantity:
                  (row['kotSentQuantity'] as num?)?.toDouble() ?? 0,
              addons: [
                for (final addon in (row['addons'] as List? ?? const []))
                  if (addon is Map)
                    CartAddonSelection(
                      addonGroupId: '${addon['addonGroupId'] ?? ''}',
                      addonGroupName: '${addon['addonGroupName'] ?? ''}',
                      minSelections:
                          (addon['minSelections'] as num?)?.toInt() ?? 0,
                      maxSelections: (addon['maxSelections'] as num?)?.toInt(),
                      addonItemId: '${addon['addonItemId'] ?? ''}',
                      addonItemName: '${addon['addonItemName'] ?? ''}',
                      quantity: (addon['quantity'] as num?)?.toInt() ?? 1,
                      unitPrice: (addon['unitPrice'] as num?)?.toDouble() ?? 0,
                    ),
              ],
            ),
      ],
      discounts: [
        for (final d in discountsRaw)
          if (d is Map)
            CartDiscountLine(
              id: '${d['id'] ?? ''}',
              title: '${d['title'] ?? 'Discount'}',
              percentage: (d['percentage'] as num?)?.toDouble() ?? 0,
              targetLineSignature: d['targetLineSignature'] as String?,
              targetItemName: d['targetItemName'] as String?,
            ),
      ],
      serviceTaxPercentage:
          (json['serviceTaxPercentage'] as num?)?.toDouble() ?? 0,
      tipsAmount: (json['tipsAmount'] as num?)?.toDouble() ?? 0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0,
      netTotal: (json['netTotal'] as num?)?.toDouble() ?? 0,
    );
  }
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
    final current = await list();
    final next = current.where((row) => row.id != trimmed).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final row in next) row.toJson()]),
    );
  }
}
