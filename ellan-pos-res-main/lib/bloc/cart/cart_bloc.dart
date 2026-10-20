import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/checkout_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'cart_event.dart';
import 'cart_state.dart';
import '../../data/models/product_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/cart_discount_line.dart';
import '../../data/models/category_model.dart';
import '../../data/models/order_history_model.dart';
import 'dart:math';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<LoadInitialData>(_onLoadInitialData);
    on<SelectCategory>(_onSelectCategory);
    on<AddProductToCart>(_onAddProductToCart);
    on<UpdateCartItemQuantity>(_onUpdateCartItemQuantity);
    on<RemoveProductFromCart>(_onRemoveProductFromCart);
    on<ClearCart>(_onClearCart);
    on<MarkCartKotSent>(_onMarkCartKotSent);
    on<RefreshCartOffers>(_onRefreshCartOffers);
    on<ToggleCheckoutTab>(_onToggleCheckoutTab);
    on<SendToKOT>(_onSendToKOT);
    on<ApplyDiscount>(_onApplyDiscount);
    on<RemoveDiscount>(_onRemoveDiscount);
    on<ApplyServiceTax>(_onApplyServiceTax);
    on<RemoveServiceTax>(_onRemoveServiceTax);
    on<ApplyTips>(_onApplyTips);
    on<RemoveTips>(_onRemoveTips);
    on<SelectPaymentMethod>(_onSelectPaymentMethod);
  }

  void _onLoadInitialData(
    LoadInitialData event,
    Emitter<CartState> emit,
  ) async {
    final pricingMode = StoreOrderPricingMode.normalize(event.pricingMode);
    final isBuying = pricingMode == StoreOrderPricingMode.buying;
    emit(state.copyWith(isLoading: true, pricingMode: pricingMode));

    try {
      final controller = getIt<UiStoreController>();
      final catalogue = await controller.loadCatalogue();
      final offerTags = isBuying
          ? const <String, String>{}
          : await controller.loadProductOfferTags();

      final categories = <CategoryModel>[
        const CategoryModel(id: 'all', name: 'All Items', imageUrl: ''),
        for (final category in catalogue.categories)
          CategoryModel(
            id: category.id.toString(),
            name: category.name.isEmpty
                ? 'Category ${category.id}'
                : category.name,
            imageUrl: '',
          ),
      ];

      final products = <Product>[
        for (final product in catalogue.products)
          Product(
            id: product.id,
            name: product.checkoutName,
            productName: product.productName.trim(),
            variantName: product.packageName.trim().isNotEmpty
                ? product.packageName.trim()
                : product.name.trim(),
            description: '',
            price: isBuying
                ? (product.buyPrice != null && product.buyPrice! > 0
                      ? product.buyPrice!
                      : product.price)
                : product.price,
            imageUrl: product.imagePath,
            categoryId: product.categoryId.toString(),
            offerTag: isBuying ? null : offerTags[product.id],
            sellUnitCode: product.sellUnitCode,
            sellUnitShort: product.sellUnitShort,
            sellUnitLabel: product.sellUnitLabel,
            sellUnitBaseQty: product.sellUnitBaseQty,
          ),
      ];

      emit(
        state.copyWith(
          isLoading: false,
          pricingMode: pricingMode,
          categories: categories,
          products: products,
          selectedCategoryId: 'all',
          cartItems: event.draft?.items ?? const [],
          discounts: event.draft?.discounts ?? const [],
          serviceTaxPercentage: event.draft?.serviceTaxPercentage ?? 0,
          tipsAmount: event.draft?.tipsAmount ?? 0,
          deliveryCharge: event.draft?.deliveryCharge ?? 0,
          offerAppliedAmount: 0,
          offerLabels: const [],
        ),
      );
      await _refreshOffers(emit);
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          pricingMode: pricingMode,
          categories: const [
            CategoryModel(id: 'all', name: 'All Items', imageUrl: ''),
          ],
          products: const [],
          selectedCategoryId: 'all',
        ),
      );
    }
  }

  void _onSelectCategory(SelectCategory event, Emitter<CartState> emit) {
    emit(state.copyWith(selectedCategoryId: event.categoryId));
  }

  Future<void> _onAddProductToCart(
    AddProductToCart event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = List<CartItem>.from(state.cartItems);
    final incoming = CartItem(
      product: event.product,
      quantity: event.quantity <= 0 ? 1.0 : event.quantity,
      addons: event.addons,
    );
    final existingIndex = event.product.isMisc
        ? -1
        : updatedCart.indexWhere(
            (item) => item.lineSignature == incoming.lineSignature,
          );
    final addQty = incoming.quantity;

    if (existingIndex >= 0) {
      final existingItem = updatedCart[existingIndex];
      updatedCart[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + addQty,
      );
    } else {
      updatedCart.add(incoming);
    }

    emit(state.copyWith(cartItems: updatedCart, isHistoryTabActive: false));
    await _refreshOffers(emit);
  }

  Future<void> _onUpdateCartItemQuantity(
    UpdateCartItemQuantity event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = List<CartItem>.from(state.cartItems);
    final index = updatedCart.indexWhere(
      (item) => item.lineSignature == event.cartItem.lineSignature,
    );

    if (index >= 0) {
      if (event.quantity <= 0) {
        updatedCart.removeAt(index);
      } else {
        final current = updatedCart[index];
        final nextKot = event.quantity < current.kotSentQuantity
            ? event.quantity
            : current.kotSentQuantity;
        updatedCart[index] = current.copyWith(
          quantity: event.quantity,
          kotSentQuantity: nextKot,
        );
      }
      final pruned = _pruneOrphanItemDiscounts(updatedCart, state.discounts);
      emit(state.copyWith(cartItems: updatedCart, discounts: pruned));
      await _refreshOffers(emit);
    }
  }

  Future<void> _onRemoveProductFromCart(
    RemoveProductFromCart event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = List<CartItem>.from(state.cartItems);
    updatedCart.removeWhere(
      (item) => item.lineSignature == event.cartItem.lineSignature,
    );
    final pruned = _pruneOrphanItemDiscounts(updatedCart, state.discounts);
    emit(state.copyWith(cartItems: updatedCart, discounts: pruned));
    await _refreshOffers(emit);
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) {
    emit(
      state.copyWith(
        cartItems: const [],
        discounts: const [],
        offerAppliedAmount: 0,
        offerLabels: const [],
        serviceTaxPercentage: 0.0,
        tipsAmount: 0.0,
        clearPaymentMethod: true,
      ),
    );
  }

  void _onToggleCheckoutTab(ToggleCheckoutTab event, Emitter<CartState> emit) {
    emit(state.copyWith(isHistoryTabActive: event.isHistoryActive));
  }

  String? _orgTimezoneName() {
    try {
      return getIt<UiStoreController>().orgTimezoneName;
    } catch (_) {
      return null;
    }
  }

  void _onMarkCartKotSent(MarkCartKotSent event, Emitter<CartState> emit) {
    if (state.cartItems.isEmpty) return;
    final updated = [
      for (final item in state.cartItems)
        item.copyWith(kotSentQuantity: item.quantity),
    ];
    final batch = event.batchNumber;
    final history = OrderHistoryModel(
      id: batch != null
          ? 'KOT #$batch'
          : '#KOT-${Random().nextInt(99999).toString().padLeft(5, '0')}',
      orderId: event.orderId,
      kotBatch: batch,
      items: List.from(updated),
      totalAmount: state.netTotal,
      timestamp: OrgTimezone.nowWallClock(_orgTimezoneName()),
    );
    // KOT sends kitchen instructions; the same basket is still due for billing.
    final priorForOrder = event.orderId == null
        ? const <OrderHistoryModel>[]
        : state.orderHistory
              .where((row) => row.orderId == event.orderId)
              .toList(growable: false);
    emit(
      state.copyWith(
        cartItems: updated,
        isHistoryTabActive: true,
        orderHistory: [history, ...priorForOrder],
      ),
    );
  }

  /// Legacy event for marking the current basket as sent to kitchen.
  void _onSendToKOT(SendToKOT event, Emitter<CartState> emit) {
    _onMarkCartKotSent(const MarkCartKotSent(), emit);
  }

  Future<void> _onRefreshCartOffers(
    RefreshCartOffers event,
    Emitter<CartState> emit,
  ) async {
    await _refreshOffers(emit);
  }

  Future<void> _refreshOffers(Emitter<CartState> emit) async {
    if (state.isBuying || state.cartItems.isEmpty) {
      emit(state.copyWith(offerAppliedAmount: 0, offerLabels: const []));
      return;
    }
    try {
      final preview = await getIt<UiStoreController>().previewCartOffers([
        for (final item in state.cartItems)
          CheckoutLineItem(
            productId: item.product.id,
            productVariantId: item.product.id,
            quantity: item.quantity,
            unitPrice: item.product.price,
            lineTotal: item.totalPrice,
            itemName: item.product.name,
            addons: item.addons,
            sellUnitBaseQty: item.product.sellUnitBaseQty,
            sellUnitShort: item.product.sellUnitShort,
          ),
      ]);
      emit(
        state.copyWith(
          offerAppliedAmount: preview.amount,
          offerLabels: preview.labels,
        ),
      );
    } catch (_) {
      // Offer preview is best-effort while browsing the cart.
    }
  }

  void _onApplyDiscount(ApplyDiscount event, Emitter<CartState> emit) {
    if (event.percentage <= 0 || event.percentage > 100) return;
    final title = event.title.trim().isEmpty ? 'Discount' : event.title.trim();
    final line = CartDiscountLine(
      id: 'disc-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      title: title,
      percentage: event.percentage,
      targetLineSignature: event.targetLineSignature,
      targetItemName: event.targetItemName,
    );
    emit(state.copyWith(discounts: [...state.discounts, line]));
  }

  void _onRemoveDiscount(RemoveDiscount event, Emitter<CartState> emit) {
    if (event.discountId == null || event.discountId!.isEmpty) {
      emit(state.copyWith(discounts: const []));
      return;
    }
    emit(
      state.copyWith(
        discounts: state.discounts
            .where((d) => d.id != event.discountId)
            .toList(growable: false),
      ),
    );
  }

  void _onApplyServiceTax(ApplyServiceTax event, Emitter<CartState> emit) {
    if (event.percentage > 0 && event.percentage <= 100) {
      emit(state.copyWith(serviceTaxPercentage: event.percentage));
    }
  }

  void _onRemoveServiceTax(RemoveServiceTax event, Emitter<CartState> emit) {
    emit(state.copyWith(serviceTaxPercentage: 0.0));
  }

  void _onApplyTips(ApplyTips event, Emitter<CartState> emit) {
    if (event.amount >= 0) {
      emit(state.copyWith(tipsAmount: event.amount));
    }
  }

  void _onRemoveTips(RemoveTips event, Emitter<CartState> emit) {
    emit(state.copyWith(tipsAmount: 0.0));
  }

  void _onSelectPaymentMethod(
    SelectPaymentMethod event,
    Emitter<CartState> emit,
  ) {
    emit(state.copyWith(selectedPaymentMethod: event.method));
  }

  List<CartDiscountLine> _pruneOrphanItemDiscounts(
    List<CartItem> items,
    List<CartDiscountLine> discounts,
  ) {
    final signatures = items.map((i) => i.lineSignature).toSet();
    return discounts
        .where(
          (d) =>
              !d.isItemDiscount || signatures.contains(d.targetLineSignature),
        )
        .toList(growable: false);
  }
}
