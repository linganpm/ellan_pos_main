import 'package:equatable/equatable.dart';
import '../../data/models/product_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/cart_discount_line.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class LoadInitialData extends CartEvent {
  final CartDraftSnapshot? draft;
  final String pricingMode;

  const LoadInitialData({
    this.draft,
    this.pricingMode = 'selling',
  });

  @override
  List<Object?> get props => [draft, pricingMode];
}

/// Snapshot applied after catalogue load to restore a saved draft cart.
class CartDraftSnapshot {
  final List<CartItem> items;
  final List<CartDiscountLine> discounts;
  final double serviceTaxPercentage;
  final double tipsAmount;
  final double deliveryCharge;

  const CartDraftSnapshot({
    required this.items,
    this.discounts = const [],
    this.serviceTaxPercentage = 0,
    this.tipsAmount = 0,
    this.deliveryCharge = 0,
  });
}

class SelectCategory extends CartEvent {
  final String categoryId;

  const SelectCategory(this.categoryId);

  @override
  List<Object> get props => [categoryId];
}

class AddProductToCart extends CartEvent {
  final Product product;
  final double quantity;
  final List<CartAddonSelection> addons;

  const AddProductToCart(
    this.product, {
    this.quantity = 1,
    this.addons = const [],
  });

  @override
  List<Object> get props => [product, quantity, addons];
}

class UpdateCartItemQuantity extends CartEvent {
  final CartItem cartItem;
  final double quantity;

  const UpdateCartItemQuantity(this.cartItem, this.quantity);

  @override
  List<Object> get props => [cartItem, quantity];
}

class RemoveProductFromCart extends CartEvent {
  final CartItem cartItem;

  const RemoveProductFromCart(this.cartItem);

  @override
  List<Object> get props => [cartItem];
}

class ClearCart extends CartEvent {}

class MarkCartKotSent extends CartEvent {
  final int? orderId;
  final int? batchNumber;

  const MarkCartKotSent({this.orderId, this.batchNumber});

  @override
  List<Object?> get props => [orderId, batchNumber];
}

class RefreshCartOffers extends CartEvent {}

class ToggleCheckoutTab extends CartEvent {
  final bool isHistoryActive;

  const ToggleCheckoutTab(this.isHistoryActive);

  @override
  List<Object> get props => [isHistoryActive];
}

class SendToKOT extends CartEvent {}

class ApplyDiscount extends CartEvent {
  final double percentage;
  final String title;
  final String? targetLineSignature;
  final String? targetItemName;

  const ApplyDiscount(
    this.percentage, {
    this.title = 'Discount',
    this.targetLineSignature,
    this.targetItemName,
  });

  @override
  List<Object?> get props => [
    percentage,
    title,
    targetLineSignature,
    targetItemName,
  ];
}

class RemoveDiscount extends CartEvent {
  final String? discountId;

  /// When [discountId] is null, removes every discount.
  const RemoveDiscount({this.discountId});

  @override
  List<Object?> get props => [discountId];
}

class ApplyServiceTax extends CartEvent {
  final double percentage;
  const ApplyServiceTax(this.percentage);
  @override
  List<Object> get props => [percentage];
}

class RemoveServiceTax extends CartEvent {}

class ApplyTips extends CartEvent {
  final double amount;
  const ApplyTips(this.amount);
  @override
  List<Object> get props => [amount];
}

class RemoveTips extends CartEvent {}

class SelectPaymentMethod extends CartEvent {
  final String method;
  const SelectPaymentMethod(this.method);
  @override
  List<Object> get props => [method];
}
