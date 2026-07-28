import 'package:pos_tablet/core/sell_unit.dart';

import 'product_model.dart';

/// One selected add-on line on a cart item.
class CartAddonSelection {
  final String addonGroupId;
  final String addonGroupName;
  final int minSelections;
  final int? maxSelections;
  final String addonItemId;
  final String addonItemName;
  final int quantity;
  final double unitPrice;

  const CartAddonSelection({
    required this.addonGroupId,
    required this.addonGroupName,
    this.minSelections = 0,
    this.maxSelections,
    required this.addonItemId,
    required this.addonItemName,
    this.quantity = 1,
    required this.unitPrice,
  });

  String get signature => '$addonGroupId:$addonItemId:$quantity';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartAddonSelection &&
          runtimeType == other.runtimeType &&
          addonGroupId == other.addonGroupId &&
          addonItemId == other.addonItemId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice;

  @override
  int get hashCode =>
      Object.hash(addonGroupId, addonItemId, quantity, unitPrice);
}

class CartItem {
  final Product product;
  final double quantity;
  final List<CartAddonSelection> addons;
  /// Quantity already sent to kitchen (KOT) for this line.
  final double kotSentQuantity;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.addons = const [],
    this.kotSentQuantity = 0,
  });

  SellUnitInfo? get sellUnit {
    if (!product.hasSellUnit) return null;
    return SellUnitInfo(
      unitCode: product.sellUnitCode!,
      unitLabel: product.sellUnitLabel ?? product.sellUnitShort!,
      unitShort: product.sellUnitShort!,
      baseQty: product.sellUnitBaseQty ?? 1,
    );
  }

  double get addonUnitTotal =>
      addons.fold(0.0, (sum, addon) => sum + (addon.unitPrice * addon.quantity));

  String get lineSignature {
    final addonKey = addons.map((a) => a.signature).toList()..sort();
    return '${product.id}|${addonKey.join(',')}';
  }

  double get totalPrice =>
      computeSellLineTotal(product.price + addonUnitTotal, quantity, sellUnit);

  double get pendingKotQuantity {
    final pending = quantity - kotSentQuantity;
    return pending <= 0 ? 0 : pending;
  }

  CartItem copyWith({
    Product? product,
    double? quantity,
    List<CartAddonSelection>? addons,
    double? kotSentQuantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addons: addons ?? this.addons,
      kotSentQuantity: kotSentQuantity ?? this.kotSentQuantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          lineSignature == other.lineSignature &&
          quantity == other.quantity &&
          kotSentQuantity == other.kotSentQuantity;

  @override
  int get hashCode => Object.hash(lineSignature, quantity, kotSentQuantity);
}
