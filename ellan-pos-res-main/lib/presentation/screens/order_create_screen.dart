import 'package:flutter/material.dart';
import '../widgets/adaptive_checkout_panels.dart';
import 'package:pos_tablet/core/sell_unit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/checkout_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';
import 'package:pos_tablet/data/models/product_model.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_event.dart';
import '../../bloc/cart/cart_state.dart';
import '../widgets/category_card.dart';
import '../widgets/product_item_card.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/checkout_tab_bar.dart';
import '../widgets/checkout_footer_buttons.dart';
import '../widgets/pos_home_button.dart';
import '../widgets/order_history_card.dart';
import 'billing_summary_screen.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

class OrderCreateScreenArgs {
  final String orderType; // Display label (Pickup, On-Site, …)
  /// Stable synced key (PICKUP, ONSITE, …) used for checkout/export.
  final String? orderTypeKey;

  /// Trade direction: selling | buying.
  final String pricingMode;
  final String? name;
  final String? phone;
  final String? email;

  /// Stable unique sync id — never a local SQLite PK.
  final String? customerUniqueId;
  final String? floor;
  final String? table;
  final String? tableId;

  String? get resolvedTableId => tableId ?? table;

  /// When restoring a saved cart draft.
  final String? draftId;
  final CartDraftSnapshot? draftSnapshot;

  /// Open kitchen order id when continuing after KOT.
  final int? openOrderId;

  OrderCreateScreenArgs({
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
    this.draftId,
    this.draftSnapshot,
    this.openOrderId,
  });

  OrderCreateScreenArgs withPricingMode(String value) {
    return OrderCreateScreenArgs(
      orderType: orderType,
      orderTypeKey: orderTypeKey,
      pricingMode: StoreOrderPricingMode.requireSupported(value),
      name: name,
      phone: phone,
      email: email,
      customerUniqueId: customerUniqueId,
      floor: floor,
      table: table,
      tableId: tableId,
      draftId: draftId,
      draftSnapshot: draftSnapshot,
      openOrderId: openOrderId,
    );
  }
}

class SalesOrderScreen extends StatelessWidget {
  final OrderCreateScreenArgs args;

  const SalesOrderScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) => OrderCreateScreen(
    args: args.withPricingMode(StoreOrderPricingMode.selling),
  );
}

class PurchaseOrderScreen extends StatelessWidget {
  final OrderCreateScreenArgs args;

  const PurchaseOrderScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) => OrderCreateScreen(
    args: args.withPricingMode(StoreOrderPricingMode.buying),
  );
}

class OrderCreateScreen extends StatefulWidget {
  final OrderCreateScreenArgs args;

  const OrderCreateScreen({super.key, required this.args});

  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  String? _draftId;
  int? _openOrderId;
  bool _kotBusy = false;

  OrderCreateScreenArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    _draftId = args.draftId;
    _openOrderId = args.openOrderId;
  }

  Future<void> _sendKot(BuildContext context, CartState state) async {
    if (_kotBusy || state.cartItems.isEmpty) return;
    final pending = state.cartItems.any((i) => i.pendingKotQuantity > 0.0001);
    if (!pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.orderAllItemsSentKitchen)),
      );
      return;
    }
    setState(() => _kotBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    final cartBloc = context.read<CartBloc>();
    final controller = getIt<UiStoreController>();
    try {
      final snapshotItems = List<CartItem>.from(state.cartItems);
      final snapshotTips = state.tipsAmount;
      final snapshotDelivery = state.deliveryCharge;
      final result = await controller.sendKotFromCart(
        existingOrderId: _openOrderId,
        items: [
          for (final item in snapshotItems)
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
        ],
        orderType:
            (args.orderTypeKey != null && args.orderTypeKey!.trim().isNotEmpty)
            ? args.orderTypeKey!.trim()
            : args.orderType,
        pricingMode: args.pricingMode,
        customerName: args.name,
        customerPhone: args.phone,
        customerEmail: args.email,
        customerUniqueId: args.customerUniqueId,
        tableId: args.resolvedTableId,
        tipsAmount: snapshotTips,
        serviceTaxAmount: state.serviceTaxValue,
        discountAmount: state.discountValue,
        deliveryCharge: snapshotDelivery,
      );
      if (!mounted) return;
      setState(() => _openOrderId = result.orderId);
      final marked = cartBloc.stream.firstWhere(
        (next) => next.orderHistory.any(
          (ticket) =>
              ticket.orderId == result.orderId &&
              ticket.kotBatch == result.batchNumber,
        ),
      );
      cartBloc.add(
        MarkCartKotSent(
          orderId: result.orderId,
          batchNumber: result.batchNumber,
        ),
      );
      final after = await marked;
      if (!mounted) return;
      // Save after the new ticket is on the cart so a later retrieve
      // brings back every KOT, including the one just sent.
      final draft = await CartDraftStore.save(
        existingId: _draftId,
        args: CartDraftArgs(
          orderType: args.orderType,
          orderTypeKey: args.orderTypeKey,
          pricingMode: args.pricingMode,
          name: args.name,
          phone: args.phone,
          email: args.email,
          customerUniqueId: args.customerUniqueId,
          floor: args.floor,
          table: args.table,
          tableId: args.tableId,
          openOrderId: result.orderId,
        ),
        items: after.cartItems,
        discounts: after.discounts,
        serviceTaxPercentage: after.serviceTaxPercentage,
        tipsAmount: after.tipsAmount,
        deliveryCharge: after.deliveryCharge,
        netTotal: after.netTotal,
        orderHistory: after.orderHistory,
      );
      if (!mounted) return;
      setState(() => _draftId = draft.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.orderCreateKotSent(result.batchNumber, result.orderId),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.orderKotFailed(error.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _kotBusy = false);
    }
  }

  Future<void> _saveDraft(BuildContext context, CartState state) async {
    if (state.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.orderCreateAddItemsBeforeDraft)),
      );
      return;
    }
    try {
      final draft = await CartDraftStore.save(
        existingId: _draftId,
        args: CartDraftArgs(
          orderType: args.orderType,
          orderTypeKey: args.orderTypeKey,
          pricingMode: args.pricingMode,
          name: args.name,
          phone: args.phone,
          email: args.email,
          customerUniqueId: args.customerUniqueId,
          floor: args.floor,
          table: args.table,
          tableId: args.tableId,
          openOrderId: _openOrderId,
        ),
        items: state.cartItems,
        discounts: state.discounts,
        serviceTaxPercentage: state.serviceTaxPercentage,
        tipsAmount: state.tipsAmount,
        deliveryCharge: state.deliveryCharge,
        netTotal: state.netTotal,
        orderHistory: state.orderHistory,
      );
      if (!mounted) return;
      setState(() => _draftId = draft.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.orderDraftSaved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorCouldNotSaveDraft(error.toString())),
        ),
      );
    }
  }

  /// Deletes the whole order: cart, saved cart draft and any open SQLite order
  /// (freeing its table). A fresh, untouched order is simply dismissed.
  Future<void> _deleteOrder(BuildContext context, CartState state) async {
    final navigator = Navigator.of(context);
    final draftId = _draftId;
    final openOrderId = _openOrderId;
    final hasDraft = draftId != null && draftId.isNotEmpty;
    if (state.cartItems.isEmpty && !hasDraft && openOrderId == null) {
      navigator.pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.orderDeleteOrderQuestion),
        content: Text(context.l10n.orderDeleteOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
            ),
            child: Text(context.l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final cartBloc = context.read<CartBloc>();
    final l10n = context.l10n;
    var deleted = true;
    try {
      if (openOrderId != null) {
        deleted = await getIt<UiStoreController>().discardOrder(openOrderId);
      }
      if (hasDraft) {
        await CartDraftStore.delete(draftId);
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.errorCouldNotDeleteOrder(error.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    if (!mounted) return;
    cartBloc.add(ClearCart());
    setState(() {
      _draftId = null;
      _openOrderId = null;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted ? l10n.orderDeletedTableFreed : l10n.orderCancelledTableFreed,
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CartBloc()
        ..add(
          LoadInitialData(
            draft: args.draftSnapshot,
            pricingMode: args.pricingMode,
          ),
        ),
      child: Builder(
        builder: (context) {
          return Theme(
            data: Theme.of(context).copyWith(
              snackBarTheme: const SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                insetPadding: EdgeInsets.fromLTRB(16, 8, 16, 108),
              ),
            ),
            child: Scaffold(
              backgroundColor: const Color(0xFFF3F0FA),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: PosBrandTitle(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.pricingMode == 'buying'
                          ? (Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase().startsWith('ta')
                                ? 'கொள்முதல் ஆர்டர்'
                                : 'Purchase order')
                          : (Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase().startsWith('ta')
                                ? 'விற்பனை ஆர்டர்'
                                : 'Sales order'),
                      style: FontUtility.heading.copyWith(fontSize: 22),
                    ),
                    if (args.name != null && args.name!.isNotEmpty)
                      Text(
                        [
                              args.name,
                              if (args.phone != null && args.phone!.isNotEmpty)
                                args.phone,
                              if (args.table != null && args.table!.isNotEmpty)
                                '${args.floor ?? ''} ${args.table}'.trim(),
                            ]
                            .whereType<String>()
                            .where((part) => part.isNotEmpty)
                            .join(' · '),
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else if (args.table != null)
                      Text(
                        context.l10n.orderCreateFloorTable(
                          args.floor ?? '',
                          args.table ?? '',
                        ),
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                ),
                centerTitle: false,
                actions: [
                  const PosHomeButton(),
                  BlocBuilder<CartBloc, CartState>(
                    builder: (context, state) {
                      return IconButton(
                        tooltip: context.l10n.orderCreateSaveDraftTooltip,
                        iconSize: 34,
                        onPressed: state.cartItems.isEmpty
                            ? null
                            : () => _saveDraft(context, state),
                        icon: const Icon(
                          Icons.save_rounded,
                          size: 34,
                          color: Color(0xFF4A00E0),
                        ),
                      );
                    },
                  ),
                  BlocBuilder<CartBloc, CartState>(
                    builder: (context, state) {
                      return IconButton(
                        key: const ValueKey('order-create-delete'),
                        tooltip: context.l10n.orderDeleteOrder,
                        onPressed: _kotBusy
                            ? null
                            : () => _deleteOrder(context, state),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF512F),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: SafeArea(
                child: AdaptiveCheckoutPanels(
                  primaryLabel: context.l10n.commonItem,
                  secondaryLabel: context.l10n.commonOrderLabel,
                  primaryFlex: 65,
                  secondaryFlex: 35,
                  primary: _buildLeftPanel(),
                  secondary: _buildRightPanel(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categories List
            Container(
              height: 72,
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 12 : 18,
                10,
                MediaQuery.sizeOf(context).width < 600 ? 12 : 18,
                6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.categories.length,
                      itemBuilder: (context, index) {
                        final category = state.categories[index];
                        return CategoryCard(
                          category: category,
                          isSelected: state.selectedCategoryId == category.id,
                          onTap: () {
                            context.read<CartBloc>().add(
                              SelectCategory(category.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showMiscItemDialog(context),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: Text(
                      context.l10n.orderMisc,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A00E0),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE6E8EE)),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.sizeOf(context).width < 600
                            ? 12
                            : 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Products Grid — spacing/columns adapt to the available panel size.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = _ProductGridLayout.fromConstraints(
                    constraints,
                  );
                  return _buildProductGrid(context, state, layout);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    CartState state,
    _ProductGridLayout layout,
  ) {
    final products = state.filteredProducts;
    final productCount = products.length;
    final inCart = <String, double>{};
    for (final item in state.cartItems) {
      inCart[item.product.id] = (inCart[item.product.id] ?? 0) + item.quantity;
    }

    return productCount == 0
        ? Center(
            child: Text(
              context.l10n.catalogEmpty,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : GridView.builder(
            key: PageStorageKey('grid-${state.selectedCategoryId}'),
            padding: EdgeInsets.fromLTRB(
              layout.padding,
              8,
              layout.padding,
              layout.padding,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.crossAxisCount,
              mainAxisSpacing: layout.spacing,
              crossAxisSpacing: layout.spacing,
              childAspectRatio: layout.childAspectRatio,
            ),
            itemCount: productCount,
            itemBuilder: (context, index) {
              final product = products[index];
              return _StaggeredTileIn(
                key: ValueKey('${state.selectedCategoryId}-${product.id}'),
                index: index,
                child: ProductItemCard(
                  product: product,
                  onTap: () => _onProductTap(context, product),
                  compact: layout.compact,
                  cartQuantity: inCart[product.id] ?? 0,
                ),
              );
            },
          );
  }

  Future<void> _showMiscItemDialog(BuildContext context) async {
    final nameController = TextEditingController(
      text: context.l10n.orderMisc.toLowerCase(),
    );
    final priceController = TextEditingController();
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.orderCreateAddMiscItem),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RubberPush(child: TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.orderCreateProductName,
                  ),
                )),
                const SizedBox(height: 12),
                Text(
                  context.l10n.commonPrice,
                  style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                RubberPush(child: TextField(
                  controller: priceController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: PosFields.border,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.actionCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.orderCreateEnterValidPrice),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': nameController.text,
                  'price': price,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                foregroundColor: Colors.white,
              ),
              child: Text(context.l10n.actionAdd),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    priceController.dispose();
    if (result == null || !context.mounted) return;

    final name = (result['name'] as String?)?.trim() ?? '';
    final price = ((result['price'] as num?) ?? 0).toDouble();
    if (price <= 0) return;

    final product = Product(
      id: 'misc-${DateTime.now().microsecondsSinceEpoch}',
      name: name.isEmpty ? context.l10n.orderMisc.toLowerCase() : name,
      description: context.l10n.commonMiscItem,
      price: price,
      imageUrl: '',
      categoryId: 'misc',
      isMisc: true,
    );
    context.read<CartBloc>().add(AddProductToCart(product));
  }

  Future<void> _onProductTap(BuildContext context, dynamic product) async {
    final productModel = product is Product
        ? product
        : Product(
            id: '${product.id}',
            name: '${product.name}',
            description: '',
            price: (product.price as num?)?.toDouble() ?? 0,
            imageUrl: '${product.imagePath}',
            categoryId: '${product.categoryId}',
            sellUnitCode: product.sellUnitCode as int?,
            sellUnitShort: product.sellUnitShort?.toString(),
            sellUnitLabel: product.sellUnitLabel?.toString(),
            sellUnitBaseQty: (product.sellUnitBaseQty as num?)?.toDouble(),
          );

    final addons = await _pickAddons(context, productModel);
    if (addons == null || !context.mounted) return;

    if (productModel.hasSellUnit != true) {
      context.read<CartBloc>().add(
        AddProductToCart(productModel, addons: addons),
      );
      return;
    }
    final base = productModel.sellUnitBaseQty ?? 1.0;
    final unitShort = productModel.sellUnitShort ?? '';
    final unitPrice = productModel.price;
    final sellUnit = SellUnitInfo(
      unitCode: productModel.sellUnitCode ?? 0,
      unitLabel: productModel.sellUnitLabel ?? unitShort,
      unitShort: unitShort,
      baseQty: base > 0 ? base : 1,
    );

    final qty = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(text: formatSellQty(base));
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final entered = double.tryParse(controller.text.trim()) ?? 0;
            final lineTotal = entered > 0
                ? computeSellLineTotal(
                    unitPrice +
                        addons.fold<double>(
                          0,
                          (sum, a) => sum + a.unitPrice * a.quantity,
                        ),
                    entered,
                    sellUnit,
                  )
                : 0.0;
            final blocks = entered > 0
                ? sellUnitBillableQty(entered, sellUnit).toInt()
                : 0;
            return AlertDialog(
              title: Text(context.l10n.orderCreateHowMany(unitShort)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${productModel.name} · ${PosCurrency.format(unitPrice)} / ${formatSellQty(base)} $unitShort',
                    style: FontUtility.body.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  RubberPush(child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: context.l10n.orderCreateQuantityUnit(
                        unitShort,
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                  Text(
                    entered > 0
                        ? '${context.l10n.commonLineTotal(PosCurrency.format(lineTotal))}'
                              ' ($blocks × ${PosCurrency.format(unitPrice + addons.fold<double>(0, (s, a) => s + a.unitPrice * a.quantity))})'
                        : context.l10n.commonEnterQuantityGtZero,
                    style: FontUtility.subheading.copyWith(
                      fontSize: 15,
                      color: const Color(0xFF4A00E0),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.actionCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    if (value == null || value <= 0) return;
                    Navigator.pop(dialogContext, value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A00E0),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.l10n.actionAdd),
                ),
              ],
            );
          },
        );
      },
    );
    if (qty == null || !context.mounted) return;
    context.read<CartBloc>().add(
      AddProductToCart(productModel, quantity: qty, addons: addons),
    );
  }

  /// Returns selected add-ons, or ``null`` if the user cancelled.
  /// Empty list means the product has no add-on groups (or none selected
  /// when all groups are optional).
  Future<List<CartAddonSelection>?> _pickAddons(
    BuildContext context,
    Product product,
  ) async {
    final controller = getIt<UiStoreController>();
    List<StoreProductAddonGroupRecord> groups;
    try {
      groups = await controller.loadAddonGroupsForVariant(product.id);
    } catch (_) {
      groups = const [];
    }
    if (groups.isEmpty) return const [];

    final selected = <String, CartAddonSelection>{};
    for (final group in groups) {
      for (final item in group.items.where(
        (i) => i.active && i.defaultSelected,
      )) {
        selected[item.addonItemId] = CartAddonSelection(
          addonGroupId: group.addonGroupId,
          addonGroupName: group.addonGroupName,
          minSelections: group.minSelections,
          maxSelections: group.maxSelections,
          addonItemId: item.addonItemId,
          addonItemName: item.addonItemName,
          unitPrice: item.sellPrice,
        );
      }
    }

    return showDialog<List<CartAddonSelection>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? validationError;
            for (final group in groups) {
              final count = selected.values
                  .where((a) => a.addonGroupId == group.addonGroupId)
                  .fold<int>(0, (sum, a) => sum + a.quantity);
              if (count < group.minSelections) {
                validationError =
                    'Select at least ${group.minSelections} in ${group.addonGroupName}';
                break;
              }
              if (group.maxSelections != null && count > group.maxSelections!) {
                validationError =
                    'Select at most ${group.maxSelections} in ${group.addonGroupName}';
                break;
              }
            }

            return AlertDialog(
              title: Text(product.name),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final group in groups) ...[
                        Text(
                          '${group.addonGroupName}'
                          '${group.minSelections > 0 ? ' (min ${group.minSelections})' : ''}'
                          '${group.maxSelections != null ? ' · max ${group.maxSelections}' : ''}',
                          style: FontUtility.subheading.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        for (final item in group.items.where((i) => i.active))
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selected.containsKey(item.addonItemId),
                            title: Text(item.addonItemName),
                            subtitle: Text(PosCurrency.format(item.sellPrice)),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  final max = group.maxSelections;
                                  final current = selected.values
                                      .where(
                                        (a) =>
                                            a.addonGroupId ==
                                            group.addonGroupId,
                                      )
                                      .length;
                                  if (max != null && current >= max) {
                                    String? first;
                                    for (final entry in selected.entries) {
                                      if (entry.value.addonGroupId ==
                                          group.addonGroupId) {
                                        first = entry.key;
                                        break;
                                      }
                                    }
                                    if (first != null) selected.remove(first);
                                  }
                                  selected[item.addonItemId] =
                                      CartAddonSelection(
                                        addonGroupId: group.addonGroupId,
                                        addonGroupName: group.addonGroupName,
                                        minSelections: group.minSelections,
                                        maxSelections: group.maxSelections,
                                        addonItemId: item.addonItemId,
                                        addonItemName: item.addonItemName,
                                        unitPrice: item.sellPrice,
                                      );
                                } else {
                                  selected.remove(item.addonItemId);
                                }
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (validationError != null)
                        Text(
                          validationError,
                          style: FontUtility.body.copyWith(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.actionCancel),
                ),
                ElevatedButton(
                  onPressed: validationError != null
                      ? null
                      : () => Navigator.pop(
                          dialogContext,
                          selected.values.toList(growable: false),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A00E0),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.l10n.actionContinue),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: const Color(0xFFF7F5FC),
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          return Column(
            children: [
              // Top Section (Tabs + List) - 67% height
              Expanded(
                flex: 65,
                child: Column(
                  children: [
                    // Tabs
                    CheckoutTabBar(
                      isHistoryActive: state.isHistoryTabActive,
                      newOrderCount: state.totalItems,
                      onNewOrderTap: () {
                        context.read<CartBloc>().add(
                          const ToggleCheckoutTab(false),
                        );
                      },
                      onHistoryTap: () {
                        context.read<CartBloc>().add(
                          const ToggleCheckoutTab(true),
                        );
                      },
                    ),

                    // List Content
                    Expanded(
                      child: state.isHistoryTabActive
                          ? _buildHistoryList(state, context)
                          : _buildActiveCartList(state, context),
                    ),
                  ],
                ),
              ),

              // Summary Section - 22% height
              Expanded(
                flex: 26,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 150,
                                child: OrderSummaryWidget(
                                  subTotal: state.subTotal,
                                  deliveryCharge: state.cartItems.isEmpty
                                      ? 0
                                      : state.deliveryCharge,
                                  netTotal: state.cartItems.isEmpty
                                      ? 0
                                      : state.netTotal,
                                  discounts: state.discounts,
                                  discountAmounts: {
                                    for (final d in state.discounts)
                                      d.id: state.amountForDiscount(d),
                                  },
                                  offerAppliedAmount: state.offerAppliedAmount,
                                  offerLabels: state.offerLabels,
                                  serviceTaxValue: state.serviceTaxValue,
                                  serviceTaxPercentage:
                                      state.serviceTaxPercentage,
                                  tipsAmount: state.tipsAmount,
                                  cartItems: state.cartItems,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              CheckoutFooterButtons(
                hasItems: state.cartItems.isNotEmpty && !_kotBusy,
                canSendKot: state.cartItems.any(
                  (item) => item.pendingKotQuantity > 0.0001,
                ),
                onKOT: () => _sendKot(context, state),
                onBill: () {
                  final billArgs = OrderCreateScreenArgs(
                    orderType: args.orderType,
                    orderTypeKey: args.orderTypeKey,
                    pricingMode: args.pricingMode,
                    name: args.name,
                    phone: args.phone,
                    email: args.email,
                    customerUniqueId: args.customerUniqueId,
                    floor: args.floor,
                    table: args.table,
                    tableId: args.tableId,
                    draftId: _draftId,
                    openOrderId: _openOrderId,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (navContext) => BlocProvider.value(
                        value: context.read<CartBloc>(),
                        child: args.pricingMode == 'buying'
                            ? PurchaseBillingScreen(orderArgs: billArgs)
                            : SalesBillingScreen(orderArgs: billArgs),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveCartList(CartState state, BuildContext context) {
    if (state.cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.orderCreateCartEmpty,
              style: FontUtility.subheading.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final inset = MediaQuery.sizeOf(context).width < 600 ? 8.0 : 24.0;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: inset),
      itemCount: state.cartItems.length,
      itemBuilder: (context, index) {
        final item = state.cartItems[index];
        return CartItemTile(
          cartItem: item,
          onIncrease: () {
            context.read<CartBloc>().add(
              UpdateCartItemQuantity(item, item.quantity + 1),
            );
          },
          onDecrease: () {
            context.read<CartBloc>().add(
              UpdateCartItemQuantity(item, item.quantity - 1),
            );
          },
          onRemove: () {
            context.read<CartBloc>().add(RemoveProductFromCart(item));
          },
        );
      },
    );
  }

  Widget _buildHistoryList(CartState state, BuildContext context) {
    if (state.orderHistory.isEmpty) {
      return Column(
        children: [
          _buildHistoryHeader(context),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.orderCreateNoOrderHistory,
                    style: FontUtility.subheading.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildHistoryHeader(context),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 8 : 24,
            ),
            itemCount: state.orderHistory.length,
            itemBuilder: (context, index) {
              final order = state.orderHistory[index];
              return OrderHistoryCard(order: order);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    final inset = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.l10n.orderCreatePastOrders,
            style: FontUtility.subheading.copyWith(color: Colors.grey.shade700),
          ),
          IconButton(
            onPressed: () {
              // Optionally trigger a bloc event to reload history if it was from an API
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.orderCreateHistoryRefreshed),
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A00E0)),
            tooltip: context.l10n.actionRefresh,
          ),
        ],
      ),
    );
  }
}

/// Evenly places product tiles for the current panel size (~30 visible).
/// Fades and lifts tiles in one after another when a category opens.
class _StaggeredTileIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredTileIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const baseMs = 240;
    final delayMs = index.clamp(0, 14) * 28;
    final totalMs = baseMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: Transform.scale(scale: 0.96 + value * 0.04, child: child),
        ),
      ),
      child: child,
    );
  }
}

class _ProductGridLayout {
  final int crossAxisCount;
  final double spacing;
  final double padding;
  final double childAspectRatio;
  final bool compact;

  const _ProductGridLayout({
    required this.crossAxisCount,
    required this.spacing,
    required this.padding,
    required this.childAspectRatio,
    required this.compact,
  });

  factory _ProductGridLayout.fromConstraints(BoxConstraints constraints) {
    const maxTile = 240.0;
    const maxGap = 32.0;
    const maxPad = 28.0;
    const targetVisible = 12;

    final rawWidth = constraints.maxWidth;
    final rawHeight = constraints.maxHeight;
    if (rawWidth <= 0 || rawHeight <= 0) {
      return const _ProductGridLayout(
        crossAxisCount: 2,
        spacing: 14,
        padding: 14,
        childAspectRatio: 0.86,
        compact: true,
      );
    }

    final narrowPanel = rawWidth < 560;
    final minTile = narrowPanel ? 132.0 : 176.0;
    final minGap = narrowPanel ? 14.0 : 22.0;
    final minPad = narrowPanel ? 14.0 : 18.0;

    // Outer padding scales with panel width.
    final padding = (rawWidth * 0.015).clamp(minPad, maxPad);
    final width = (rawWidth - padding * 2).clamp(1.0, rawWidth);
    final height = (rawHeight - 4 - padding).clamp(1.0, rawHeight);

    // Start from a comfortable tile width, then clamp column count.
    final maxCols = narrowPanel ? 2 : 4;
    var cols = (width / (narrowPanel ? 168 : 210)).round().clamp(1, maxCols);

    double tileWidthFor(int columnCount, double gap) =>
        (width - (columnCount - 1) * gap) / columnCount;

    var gap = minGap;
    var tileW = tileWidthFor(cols, gap);

    while (tileW > maxTile && cols < maxCols) {
      cols += 1;
      tileW = tileWidthFor(cols, gap);
    }
    while (tileW < minTile && cols > 1) {
      cols -= 1;
      tileW = tileWidthFor(cols, gap);
    }

    // Spread leftover width into gaps so the row fills evenly.
    if (cols > 1) {
      final leftover = width - cols * tileW.clamp(minTile, maxTile);
      gap = (leftover / (cols - 1)).clamp(minGap, maxGap);
      tileW = tileWidthFor(cols, gap);
    } else {
      tileW = width;
      gap = minGap;
    }

    // Fewer, taller cards so the name, variant and price stay readable.
    final targetRows = (targetVisible / cols).ceil().clamp(2, 3);
    final tileH = ((height - (targetRows - 1) * gap) / targetRows).clamp(
      tileW * 1.05,
      tileW * 1.4,
    );
    final aspect = tileW / tileH;

    return _ProductGridLayout(
      crossAxisCount: cols,
      spacing: gap,
      padding: padding,
      childAspectRatio: aspect,
      compact: tileW < 190,
    );
  }
}
