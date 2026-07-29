class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final String? offerTag;
  final String? sellUnitShort;
  final String? sellUnitLabel;
  final double? sellUnitBaseQty;
  final int? sellUnitCode;

  /// Free-text POS line (no catalogue variant required).
  final bool isMisc;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.offerTag,
    this.sellUnitShort,
    this.sellUnitLabel,
    this.sellUnitBaseQty,
    this.sellUnitCode,
    this.isMisc = false,
  });

  bool get hasSellUnit =>
      sellUnitCode != null &&
      sellUnitShort != null &&
      sellUnitShort!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
