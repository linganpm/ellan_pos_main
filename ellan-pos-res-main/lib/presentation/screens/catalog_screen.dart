import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import '../widgets/product_image.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/presentation/widgets/pos_home_button.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF4A00E0);

  late final TabController _tabs;
  PosCatalogue? _catalogue;
  List<StoreOfferRecord> _offers = const [];
  Map<String, List<StoreProductAddonGroupRecord>> _addons = const {};
  Map<String, String> _offerTags = const {};
  int? _selectedCategoryId;
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final catalogue = await controller.loadCatalogue();
      final offers = await controller.loadOffers(activeOnly: true);
      final offerTags = await controller.loadProductOfferTags();
      final addons = await controller.loadCatalogAddonMap(catalogue.products);
      if (!mounted) return;
      setState(() {
        _catalogue = catalogue;
        _offers = offers;
        _offerTags = offerTags;
        _addons = addons;
        _selectedCategoryId = null; // All
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<PosCatalogProduct> get _filteredProducts {
    final catalogue = _catalogue;
    if (catalogue == null) return const [];
    final q = _query.trim().toLowerCase();
    return catalogue.products
        .where((product) {
          if (_selectedCategoryId != null &&
              product.categoryId != _selectedCategoryId) {
            return false;
          }
          if (q.isEmpty) return true;
          return product.name.toLowerCase().contains(q) ||
              product.productName.toLowerCase().contains(q) ||
              product.packageName.toLowerCase().contains(q) ||
              (product.barcode ?? '').toLowerCase().contains(q) ||
              product.categoryName.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: PosBrandTitle(
          child: Text(
          context.l10n.commonCatalogs,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        ),
        leading: IconButton(
          tooltip: context.l10n.actionBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const PosHomeButton(),
          IconButton(
            tooltip: context.l10n.catalogRefreshLocal,
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: _accent),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                labelColor: _accent,
                unselectedLabelColor: Colors.black54,
                indicatorColor: _accent,
                tabs: [
                  Tab(
                    text: _catalogue == null
                        ? context.l10n.commonProducts
                        : context.l10n.catalogPackagesCount(
                            _catalogue?.products.length ?? 0,
                          ),
                  ),
                  Tab(text: context.l10n.catalogOffersCount(_offers.length)),
                ],
              ),
              Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            ],
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: FontUtility.body.copyWith(color: Colors.red)),
            TextButton(onPressed: _load, child: Text(context.l10n.actionRetry)),
          ],
        ),
      );
    }

    final catalogue = _catalogue;
    if (catalogue == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.catalogNoCatalogueDevice,
            textAlign: TextAlign.center,
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
        ),
      );
    }
    if (catalogue.products.isEmpty && _offers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.catalogNoCatalogueDevice,
            style: FontUtility.body.copyWith(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabs,
      children: [_buildPackagesTab(catalogue), _buildOffersTab()],
    );
  }

  Widget _buildPackagesTab(PosCatalogue catalogue) {
    final products = _filteredProducts;
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Container(
            color: Colors.white,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _categoryTile(
                  id: null,
                  name: context.l10n.catalogAllPackages,
                  count: catalogue.products.length,
                ),
                ...catalogue.categories.map((category) {
                  final count = catalogue.products
                      .where((p) => p.categoryId == category.id)
                      .length;
                  return _categoryTile(
                    id: category.id,
                    name: category.name,
                    count: count,
                  );
                }),
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.grey.withValues(alpha: 0.2)),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: RubberPush(child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.l10n.catalogSearchExtended,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: PosFields.border,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                )),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.catalogNoPackagesView,
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final offer =
                              _offerTags[product.id] ??
                              (product.variantId == null
                                  ? null
                                  : _offerTags['${product.variantId}']);
                          final groups = _addons[product.id] ?? const [];
                          return _PackageRow(
                            product: product,
                            offerLabel: offer,
                            onOpen: () => _openPackageDetail(product, groups),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryTile({
    required int? id,
    required String name,
    required int count,
  }) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedCategoryId = id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: FontUtility.subheading.copyWith(
                      color: selected ? _accent : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _accent : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: selected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    if (_offers.isEmpty) {
      return Center(
        child: Text(
          context.l10n.catalogNoActiveOffers,
          style: FontUtility.body.copyWith(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final offer = _offers[index];
        return _OfferDetailCard(
          offer: offer,
          badge: _offerBadge(offer),
          targetNames: _offerTargetNames(offer),
        );
      },
    );
  }

  String _offerBadge(StoreOfferRecord offer) {
    switch (offer.offerType) {
      case StoreOfferType.percentage:
        final pct = offer.percentageValue ?? 0;
        if (pct <= 0) return offer.name;
        return '-${pct == pct.roundToDouble() ? pct.toInt() : pct}%';
      case StoreOfferType.flat:
        final flat = offer.flatValue ?? 0;
        if (flat <= 0) return offer.name;
        return '-${PosCurrency.format(flat, decimals: flat == flat.roundToDouble() ? 0 : 2)}';
      case StoreOfferType.buyNGetM:
        final buy = offer.buyQuantity ?? 0;
        final get = offer.getQuantity ?? 0;
        if (buy <= 0 || get <= 0) return offer.name;
        return 'Buy $buy Get $get';
      case StoreOfferType.buyNGetMDiscount:
        final buy = offer.buyQuantity ?? 0;
        final get = offer.getQuantity ?? 0;
        final pct = offer.percentageValue ?? 0;
        if (buy <= 0 || get <= 0 || pct <= 0) return offer.name;
        return 'Buy $buy Get $get at -${pct == pct.roundToDouble() ? pct.toInt() : pct}%';
      case StoreOfferType.fixedPrice:
        final price = offer.flatValue;
        if (price == null || price < 0) return offer.name;
        final qty = offer.buyQuantity ?? 1;
        final formatted = PosCurrency.format(
          price,
          decimals: price == price.roundToDouble() ? 0 : 2,
        );
        return qty > 1 ? '$qty for $formatted' : 'Now $formatted';
      case StoreOfferType.totalOffer:
        final min = offer.minimumBillAmount;
        if (min != null && min > 0) {
          return 'Bill ≥ ${PosCurrency.format(min)}';
        }
        return context.l10n.catalogBillOffer;
      default:
        return offer.name;
    }
  }

  List<String> _offerTargetNames(StoreOfferRecord offer) {
    final catalogue = _catalogue;
    if (catalogue == null || offer.targetIds.isEmpty) return const [];
    final byId = {
      for (final p in catalogue.products) p.id: p,
      for (final p in catalogue.products)
        if (p.variantId != null) '${p.variantId}': p,
    };
    final names = <String>[];
    for (final raw in offer.targetIds) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      final product = byId[key];
      if (product != null) {
        final label = product.packageName.isNotEmpty
            ? product.packageName
            : product.name;
        if (!names.contains(label)) names.add(label);
      } else {
        names.add(key);
      }
    }
    return names;
  }

  void _openPackageDetail(
    PosCatalogProduct product,
    List<StoreProductAddonGroupRecord> groups,
  ) {
    final matchingOffers = _offers
        .where((offer) {
          if (offer.offerType == StoreOfferType.totalOffer) return true;
          for (final target in offer.targetIds) {
            final key = target.trim();
            if (key == product.id) return true;
            if (product.variantId != null && key == '${product.variantId}') {
              return true;
            }
          }
          return false;
        })
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return _PackageDetailSheet(
              product: product,
              addonGroups: groups,
              offers: matchingOffers,
              offerBadge: _offerBadge,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class _PackageRow extends StatelessWidget {
  final PosCatalogProduct product;
  final String? offerLabel;
  final VoidCallback onOpen;

  const _PackageRow({
    required this.product,
    required this.offerLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A00E0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ProductImage(
                  source: product.imagePath,
                  width: 42,
                  height: 42,
                  iconSize: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.productName.isNotEmpty &&
                        product.productName != product.packageName &&
                        product.productName != product.name)
                      Text(
                        product.productName,
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    Text(
                      product.packageName.isNotEmpty
                          ? product.packageName
                          : product.name,
                      style: FontUtility.subheading.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (product.categoryName.isNotEmpty)
                          _metaChip(product.categoryName),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PosCurrency.format(product.price),
                    style: FontUtility.heading.copyWith(
                      fontSize: 18,
                      color: const Color(0xFF4A00E0),
                    ),
                  ),
                  if (product.mrpPrice != null &&
                      product.mrpPrice! > product.price)
                    Text(
                      context.l10n.catalogMrpPrice(
                        PosCurrency.format(product.mrpPrice!),
                      ),
                      style: FontUtility.body.copyWith(
                        fontSize: 11,
                        color: Colors.black45,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (offerLabel != null && offerLabel!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF512F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offerLabel!,
                        style: FontUtility.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF512F),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: context.l10n.commonDetails,
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpen,
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF4A00E0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: FontUtility.body.copyWith(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}

class _PackageDetailSheet extends StatelessWidget {
  final PosCatalogProduct product;
  final List<StoreProductAddonGroupRecord> addonGroups;
  final List<StoreOfferRecord> offers;
  final String Function(StoreOfferRecord) offerBadge;
  final ScrollController scrollController;

  const _PackageDetailSheet({
    required this.product,
    required this.addonGroups,
    required this.offers,
    required this.offerBadge,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          product.packageName.isNotEmpty ? product.packageName : product.name,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        if (product.productName.isNotEmpty &&
            product.productName != product.packageName &&
            product.productName != product.name) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.catalogProductPrefix(product.productName),
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _detailStat(
              context.l10n.catalogSell,
              PosCurrency.format(product.price),
            ),
            if (product.mrpPrice != null)
              _detailStat('MRP', PosCurrency.format(product.mrpPrice!)),
            if (product.buyPrice != null)
              _detailStat('Buy', PosCurrency.format(product.buyPrice!)),
            if (product.hasSellUnit)
              _detailStat(context.l10n.catalogUnit, product.sellUnitDetail),
            if (product.categoryName.isNotEmpty)
              _detailStat(
                context.l10n.storeSetupCategory,
                product.categoryName,
              ),
            if (product.barcode != null && product.barcode!.trim().isNotEmpty)
              _detailStat(context.l10n.catalogBarcode, product.barcode!.trim()),
            if (product.variantId != null)
              _detailStat('Variant #', '${product.variantId}'),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          context.l10n.commonAddons,
          style: FontUtility.subheading.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (addonGroups.isEmpty)
          Text(
            context.l10n.catalogNoAddonGroups,
            style: FontUtility.body.copyWith(color: Colors.black45),
          )
        else
          ...addonGroups.map((group) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.addonGroupName,
                    style: FontUtility.subheading.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (group.items.isEmpty)
                    Text(
                      context.l10n.catalogNoItemsInGroup,
                      style: FontUtility.body.copyWith(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    )
                  else
                    ...group.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.addonItemName,
                                style: FontUtility.body.copyWith(fontSize: 13),
                              ),
                            ),
                            Text(
                              item.sellPrice > 0
                                  ? '+${PosCurrency.format(item.sellPrice)}'
                                  : 'Included',
                              style: FontUtility.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4A00E0),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        const SizedBox(height: 14),
        Text(
          context.l10n.commonOffers,
          style: FontUtility.subheading.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (offers.isEmpty)
          Text(
            context.l10n.catalogNoOffersTargetPackage,
            style: FontUtility.body.copyWith(color: Colors.black45),
          )
        else
          ...offers.map((offer) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF512F).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF512F).withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.name,
                          style: FontUtility.subheading.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        offerBadge(offer),
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF512F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _detailStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FontUtility.body.copyWith(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
          Text(value, style: FontUtility.subheading.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _OfferDetailCard extends StatelessWidget {
  final StoreOfferRecord offer;
  final String badge;
  final List<String> targetNames;

  const _OfferDetailCard({
    required this.offer,
    required this.badge,
    required this.targetNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.name,
                  style: FontUtility.subheading.copyWith(fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF512F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF512F),
                  ),
                ),
              ),
            ],
          ),
          if (targetNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.catalogAppliesTo,
              style: FontUtility.body.copyWith(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${targetNames.take(12).join(' · ')}'
              '${targetNames.length > 12 ? '…' : ''}',
              style: FontUtility.body.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
