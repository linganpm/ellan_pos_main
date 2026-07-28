import 'package:json_annotation/json_annotation.dart';

part 'product_models.g.dart';


@JsonSerializable(explicitToJson: true)
class Category {
  final int? categoryId; // remote id, nullable until synced
  final String localId; // always unique locally
  final String? uniqueId;
  final String name;
  final String? slug;
  final String? logo;
  final int? sorting_order;
  final String? description;
  final int? parent_id;
  final String? short_code;
  final int? depth;
  final String? path;
  final List<Category>? children;
  final int? id;
  final List<ProductVariant>? product_variants;

  Category({
    required this.localId,
    this.uniqueId,
    this.categoryId,
    required this.name,
    this.slug,
    this.logo,
    this.sorting_order,
    this.description,
    this.parent_id,
    this.short_code,
    this.depth,
    this.path,
    this.children,
    this.id,
    this.product_variants,
  });

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}


@JsonSerializable(explicitToJson: true)
class ProductVariant {
  final int? variantId; // remote id, nullable until synced
  final String localId;
  final String? uniqueId;
  final bool? exported;
  final String? lastImportedAt;
  final String? lastExportedAt;
  final String? barcode;
  final String product_variant_name;
  final String product_name;
  final bool preorder_product;
  final String? product_variant_description;
  final int product_variant_quantity;
  final String? product_variant_logo;
  final ProductData product_data;
  final CategoryData category_data;
  final List<dynamic>? product_addon_group_data;
  final List<dynamic>? product_variant_addon_group_data;
  final String sell_price;
  final String? buy_price;
  final String mrp_price;
  final List<Proportion>? proportions;
  final List<dynamic>? offer_data;
  final double? review_max_data;
  final double? review_avg_max_data;
  final double? review_value_data;
  final double? review_max_value_data;
  final int? review_count;
  final List<dynamic>? favourite_data;
  final List<dynamic>? gallery_data;
  final List<dynamic>? delivery_slot_data;

  ProductVariant({
    required this.localId,
    this.uniqueId,
    this.variantId,
    this.exported,
    this.lastImportedAt,
    this.lastExportedAt,
    this.barcode,
    required this.product_variant_name,
    required this.product_name,
    required this.preorder_product,
    this.product_variant_description,
    required this.product_variant_quantity,
    this.product_variant_logo,
    required this.product_data,
    required this.category_data,
    this.product_addon_group_data,
    this.product_variant_addon_group_data,
    required this.sell_price,
    this.buy_price,
    required this.mrp_price,
    this.proportions,
    this.offer_data,
    this.review_max_data,
    this.review_avg_max_data,
    this.review_value_data,
    this.review_max_value_data,
    this.review_count,
    this.favourite_data,
    this.gallery_data,
    this.delivery_slot_data,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => _$ProductVariantFromJson(json);
  Map<String, dynamic> toJson() => _$ProductVariantToJson(this);
}


@JsonSerializable()
class ProductData {
  final int? productId; // remote id, nullable until synced
  final String localId;
  final String? uniqueId;
  final String? logo;
  final String name;
  final int? type;
  final String? description;
  final int? is_preorder;
  final int? is_allergens;

  ProductData({
    required this.localId,
    this.uniqueId,
    this.productId,
    this.logo,
    required this.name,
    this.type,
    this.description,
    this.is_preorder,
    this.is_allergens,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) => _$ProductDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProductDataToJson(this);
}

@JsonSerializable()
class CategoryData {
  final int id;
  final String? localId;
  final String? uniqueId;
  final int? remoteId;
  final String name;
  final String slug;
  final int active;
  final int? parent_id;
  final int? is_preorder;
  final String? parent_slug;

  CategoryData({
    required this.id,
    this.localId,
    this.uniqueId,
    this.remoteId,
    required this.name,
    required this.slug,
    required this.active,
    this.parent_id,
    this.is_preorder,
    this.parent_slug,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) => _$CategoryDataFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryDataToJson(this);
}


@JsonSerializable(explicitToJson: true)
class Proportion {
  final int? proportionId; // remote id, nullable until synced
  final String localId;
  final int active;
  final ProportionData proportion_data;

  Proportion({
    required this.localId,
    this.proportionId,
    required this.active,
    required this.proportion_data,
  });

  factory Proportion.fromJson(Map<String, dynamic> json) => _$ProportionFromJson(json);
  Map<String, dynamic> toJson() => _$ProportionToJson(this);
}

@JsonSerializable()
class ProportionData {
  final int id;
  final int unit;
  final String label;
  final dynamic value;
  final int active;
  final int? default_;
  final dynamic quantity;
  final ProportionGroupData? proportion_group_data;

  ProportionData({
    required this.id,
    required this.unit,
    required this.label,
    this.value,
    required this.active,
    this.default_,
    this.quantity,
    this.proportion_group_data,
  });

  factory ProportionData.fromJson(Map<String, dynamic> json) => _$ProportionDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProportionDataToJson(this);
}

@JsonSerializable()
class ProportionGroupData {
  final int id;
  final String name;
  final dynamic type;
  final int active;
  final int is_selected;

  ProportionGroupData({
    required this.id,
    required this.name,
    this.type,
    required this.active,
    required this.is_selected,
  });

  factory ProportionGroupData.fromJson(Map<String, dynamic> json) => _$ProportionGroupDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProportionGroupDataToJson(this);
}
