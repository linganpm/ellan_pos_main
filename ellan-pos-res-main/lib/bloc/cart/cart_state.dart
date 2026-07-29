import 'package:equatable/equatable.dart';
import '../../data/models/product_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/cart_discount_line.dart';
import '../../data/models/category_model.dart';
import '../../data/models/order_history_model.dart';

class CartState extends Equatable {
  final bool isLoading;
  final List<CategoryModel> categories;
  final List<Product> products;
  final String selectedCategoryId;
  final List<CartItem> cartItems;
  final double deliveryCharge;
  final List<OrderHistoryModel> orderHistory;
  final bool isHistoryTabActive;

  /// Named discounts (order-level and/or per basket item). Additive.
  final List<CartDiscountLine> discounts;

  /// Catalogue offer amount estimated from core offer engine.
  final double offerAppliedAmount;
  final List<String> offerLabels;
  final double serviceTaxPercentage;
  final double tipsAmount;
  final String? selectedPaymentMethod;

  const CartState({
    this.isLoading = true,
    this.categories = const [],
    this.products = const [],
    this.selectedCategoryId = 'all',
    this.cartItems = const [],
    this.deliveryCharge = 0.0,
    this.orderHistory = const [],
    this.isHistoryTabActive = false,
    this.discounts = const [],
    this.offerAppliedAmount = 0.0,
    this.offerLabels = const [],
    this.serviceTaxPercentage = 0.0,
    this.tipsAmount = 0.0,
    this.selectedPaymentMethod,
  });

  List<Product> get filteredProducts {
    if (selectedCategoryId == 'all') {
      return products;
    }
    return products.where((p) => p.categoryId == selectedCategoryId).toList();
  }

  double get subTotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get itemDiscountValue {
    var sum = 0.0;
    for (final discount in discounts) {
      if (!discount.isItemDiscount) continue;
      CartItem? match;
      for (final item in cartItems) {
        if (item.lineSignature == discount.targetLineSignature) {
          match = item;
          break;
        }
      }
      if (match == null) continue;
      sum += match.totalPrice * (discount.percentage / 100);
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get orderDiscountBase {
    final base =
        subTotal - itemDiscountValue + (subTotal > 0 ? deliveryCharge : 0);
    return base < 0 ? 0.0 : double.parse(base.toStringAsFixed(2));
  }

  double get orderDiscountValue {
    var sum = 0.0;
    for (final discount in discounts) {
      if (discount.isItemDiscount) continue;
      sum += orderDiscountBase * (discount.percentage / 100);
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get discountValue =>
      double.parse((itemDiscountValue + orderDiscountValue).toStringAsFixed(2));

  double amountForDiscount(CartDiscountLine discount) {
    if (discount.isItemDiscount) {
      for (final item in cartItems) {
        if (item.lineSignature == discount.targetLineSignature) {
          return double.parse(
            (item.totalPrice * (discount.percentage / 100)).toStringAsFixed(2),
          );
        }
      }
      return 0;
    }
    return double.parse(
      (orderDiscountBase * (discount.percentage / 100)).toStringAsFixed(2),
    );
  }

  /// Legacy single-% view: sum of order-level percentages (UI badges).
  double get discountPercentage => discounts
      .where((d) => !d.isItemDiscount)
      .fold<double>(0, (sum, d) => sum + d.percentage);

  double get baseTotal => subTotal > 0 ? subTotal + deliveryCharge : 0.0;

  double get serviceTaxValue =>
      (baseTotal - offerAppliedAmount - discountValue).clamp(
        0,
        double.infinity,
      ) *
      (serviceTaxPercentage / 100);

  double get netTotal {
    if (subTotal == 0) return 0.0;
    return double.parse(
      (baseTotal -
              offerAppliedAmount -
              discountValue +
              serviceTaxValue +
              tipsAmount)
          .clamp(0, double.infinity)
          .toStringAsFixed(2),
    );
  }

  int get totalItems {
    return cartItems.fold<int>(0, (sum, item) => sum + item.quantity.ceil());
  }

  CartState copyWith({
    bool? isLoading,
    List<CategoryModel>? categories,
    List<Product>? products,
    String? selectedCategoryId,
    List<CartItem>? cartItems,
    double? deliveryCharge,
    List<OrderHistoryModel>? orderHistory,
    bool? isHistoryTabActive,
    List<CartDiscountLine>? discounts,
    double? offerAppliedAmount,
    List<String>? offerLabels,
    double? serviceTaxPercentage,
    double? tipsAmount,
    String? selectedPaymentMethod,
    bool clearPaymentMethod = false,
  }) {
    return CartState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      cartItems: cartItems ?? this.cartItems,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      orderHistory: orderHistory ?? this.orderHistory,
      isHistoryTabActive: isHistoryTabActive ?? this.isHistoryTabActive,
      discounts: discounts ?? this.discounts,
      offerAppliedAmount: offerAppliedAmount ?? this.offerAppliedAmount,
      offerLabels: offerLabels ?? this.offerLabels,
      serviceTaxPercentage: serviceTaxPercentage ?? this.serviceTaxPercentage,
      tipsAmount: tipsAmount ?? this.tipsAmount,
      selectedPaymentMethod: clearPaymentMethod
          ? null
          : (selectedPaymentMethod ?? this.selectedPaymentMethod),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    categories,
    products,
    selectedCategoryId,
    cartItems,
    deliveryCharge,
    orderHistory,
    isHistoryTabActive,
    discounts,
    offerAppliedAmount,
    offerLabels,
    serviceTaxPercentage,
    tipsAmount,
    selectedPaymentMethod,
  ];
}
