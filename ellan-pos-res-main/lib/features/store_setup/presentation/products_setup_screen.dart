import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/pos_tax_label_defaults.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';

class ProductsSetupScreen extends StatefulWidget {
  const ProductsSetupScreen({super.key});

  @override
  State<ProductsSetupScreen> createState() => _ProductsSetupScreenState();
}

class _ProductsSetupScreenState extends State<ProductsSetupScreen> {
  static const _accent = StoreSetupUi.productsAccent;

  List<StoreProductVariantRecord> _variants = [];
  List<StoreProductCategoryRecord> _categories = [];
  List<Map<String, dynamic>> _masters = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _taxes = List<Map<String, dynamic>>.from(
    PosTaxLabelDefaults.common,
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Map<String, String> _storeRefs() {
    final controller = context.read<UiStoreController>();
    final store = controller.store!;
    final login = controller.organisationLogin;
    final orgInstance = (login?.serviceInstanceId ?? '').trim().isNotEmpty
        ? login!.serviceInstanceId!.trim()
        : (login?.organisation.orgId.trim() ?? store.orgId);
    final remote = (store.storeRemoteId ?? '').trim();
    final storeSi = store.serviceInstanceId > 0
        ? '${store.serviceInstanceId}'
        : (RegExp(r'^\d+$').hasMatch(remote)
            ? remote
            : (RegExp(r'^\d+$').hasMatch(store.scope.storeId)
                ? store.scope.storeId
                : (remote.isNotEmpty ? remote : store.uniqueId)));
    return {
      'orgId': orgInstance,
      'storeId': storeSi,
      'store_service_instance': storeSi,
    };
  }

  Future<void> _loadTaxes() async {
    try {
      final origin = discoveryOrigin(kDiscoveryUrl);
      final refs = _storeRefs();
      final uri = Uri.parse('$origin/api/pos/store/taxes').replace(
        queryParameters: {
          for (final e in refs.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map) return;
      final raw = body['taxes'];
      if (raw is! List || raw.isEmpty) return;
      final taxes = <Map<String, dynamic>>[];
      for (final row in raw.whereType<Map>()) {
        taxes.add(Map<String, dynamic>.from(row));
      }
      if (!mounted || taxes.isEmpty) return;
      setState(() => _taxes = taxes);
    } catch (_) {
      // Keep offline fallback catalogue.
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final store = context.read<UiStoreController>().store!;
    final cats = await store.products.listCategories(store.scope);
    final variants = await store.products.searchDetails(scope: store.scope);
    final masters = await store.products.listMasterProducts();
    final offers = await store.products.listOffers(store.scope);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _variants = variants;
      _masters = masters;
      _offers = offers;
      _loading = false;
    });
    await _loadTaxes();
  }

  String _taxDisplayName(Map<String, dynamic> tax) {
    final name = '${tax['name'] ?? ''}'.trim();
    final pct = tax['total_percentage'];
    if (name.isEmpty) {
      return pct == null ? 'Tax' : 'Tax $pct%';
    }
    if (pct is num && !name.contains('%')) {
      return '$name (${_formatPct(pct)}%)';
    }
    return name;
  }

  String _formatPct(num value) {
    final asDouble = value.toDouble();
    if (asDouble == asDouble.roundToDouble()) {
      return asDouble.toStringAsFixed(0);
    }
    return asDouble.toStringAsFixed(2);
  }

  Widget _buildTaxPicker({
    required String? selectedName,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSetupUi.sectionLabel('Tax for this package', accent: _accent),
        Text(
          'Company tax bands from setup. Leave none if this package is tax-free / unset.',
          style: FontUtility.body.copyWith(
            fontSize: 12,
            color: StoreSetupUi.muted,
          ),
        ),
        const SizedBox(height: 8),
        RadioListTile<String?>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          value: null,
          groupValue: selectedName,
          title: Text(
            'No tax / unset',
            style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
          ),
          onChanged: onChanged,
        ),
        if (_taxes.isEmpty)
          Text(
            'No taxes yet — they are added automatically when the company is set up.',
            style: FontUtility.body.copyWith(color: StoreSetupUi.muted),
          )
        else
          ..._taxes.map((tax) {
            final name = '${tax['name'] ?? ''}'.trim();
            if (name.isEmpty) return const SizedBox.shrink();
            final pct = tax['total_percentage'];
            final components = tax['components'];
            String? subtitle;
            if (components is List && components.isNotEmpty) {
              subtitle = components
                  .whereType<Map>()
                  .map((c) {
                    final n = '${c['name'] ?? ''}'.trim();
                    final v = c['value'];
                    if (n.isEmpty) return null;
                    return v == null ? n : '$n ${_formatPct(v as num)}%';
                  })
                  .whereType<String>()
                  .join(' + ');
            } else if (pct is num) {
              subtitle = '${_formatPct(pct)}% total';
            }
            return RadioListTile<String?>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: _accent,
              value: name,
              groupValue: selectedName,
              title: Text(
                _taxDisplayName(tax),
                style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: subtitle == null || subtitle.isEmpty
                  ? null
                  : Text(
                      subtitle,
                      style: FontUtility.body.copyWith(
                        fontSize: 12,
                        color: StoreSetupUi.muted,
                      ),
                    ),
              onChanged: onChanged,
            );
          }),
      ],
    );
  }

  Future<void> _refreshSellCatalogue() async {
    try {
      await context.read<UiStoreController>().loadCatalogue();
    } catch (_) {}
  }

  Future<void> _create() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add and link a category first')),
      );
      return;
    }
    final productCtrl = TextEditingController();
    final packageCtrl = TextEditingController(text: 'Regular');
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    final qtyCtrl = TextEditingController(text: '1');
    String categoryLocalId = _categories.first.localId;
    String? selectedTaxName;

    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: 'New product / package',
      accent: _accent,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: categoryLocalId,
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c.localId, child: Text(c.name)),
              ],
              onChanged: (v) =>
                  setLocal(() => categoryLocalId = v ?? categoryLocalId),
              decoration: StoreSetupUi.field(
                hint: 'Choose category',
                label: 'Category',
                icon: Icons.folder_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: productCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Chicken Biryani',
                label: 'Product / service name *',
                icon: Icons.restaurant_menu_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: packageCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Regular, Large, Family',
                label: 'Package name *',
                icon: Icons.inventory_2_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: '0.00',
                label: 'Sell price *',
                icon: Icons.payments_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: StoreSetupUi.field(
                      hint: 'pcs, kg…',
                      label: 'Unit *',
                      accent: _accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: StoreSetupUi.field(
                      hint: '1',
                      label: 'Unit qty *',
                      accent: _accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaxPicker(
              selectedName: selectedTaxName,
              onChanged: (value) => setLocal(() => selectedTaxName = value),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
    if (productCtrl.text.trim().isEmpty ||
        packageCtrl.text.trim().isEmpty ||
        unitCtrl.text.trim().isEmpty ||
        price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, package, unit and price are required'),
        ),
      );
      return;
    }
    final store = context.read<UiStoreController>().store!;
    await store.products.createSellableItem(
      scope: store.scope,
      categoryLocalId: categoryLocalId,
      productName: productCtrl.text.trim(),
      packageName: packageCtrl.text.trim(),
      sellPrice: price,
      unitLabel: unitCtrl.text.trim(),
      unitQty: qty,
      taxLabel: selectedTaxName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved offline. Sync to export to master + store.'),
      ),
    );
    await _reload();
    await _refreshSellCatalogue();
  }

  Future<void> _edit(StoreProductVariantRecord variant) async {
    final productCtrl = TextEditingController(text: variant.productName);
    final packageCtrl =
        TextEditingController(text: variant.productVariantName);
    final priceCtrl = TextEditingController(text: '${variant.sellPrice}');
    final unitCtrl = TextEditingController(
      text: variant.sellUnitLabel ?? variant.sellUnitShort ?? 'pcs',
    );
    final qtyCtrl = TextEditingController(
      text: '${variant.sellUnitBaseQty ?? 1}',
    );
    final existingTax = (variant.taxLabel ?? '').trim();
    String? selectedTaxName = existingTax.isEmpty ? null : existingTax;
    // If package has a free-text tax that isn't in the company list, keep it selectable.
    final knownNames = {
      for (final tax in _taxes) '${tax['name'] ?? ''}'.trim(),
    }..removeWhere((n) => n.isEmpty);
    if (selectedTaxName != null && !knownNames.contains(selectedTaxName)) {
      _taxes = [
        ..._taxes,
        {
          'local_id': 'tax-custom',
          'name': selectedTaxName,
          'total_percentage': null,
        },
      ];
    }

    final store = context.read<UiStoreController>().store!;
    final selectedOffers = <String>{};
    for (final offer in _offers) {
      final offerId = '${offer['local_id'] ?? offer['localId'] ?? ''}'.trim();
      if (offerId.isEmpty) continue;
      final targets = await store.products.listOfferTargetVariantIds(
        store.scope,
        offerId,
      );
      if (targets.contains(variant.localId)) {
        selectedOffers.add(offerId);
      }
    }
    if (!mounted) return;

    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: 'Edit package',
      accent: _accent,
      width: 480,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: productCtrl,
              decoration: StoreSetupUi.field(
                hint: 'Product / service name',
                label: 'Product / service name *',
                icon: Icons.restaurant_menu_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: packageCtrl,
              decoration: StoreSetupUi.field(
                hint: 'Package name',
                label: 'Package name *',
                icon: Icons.inventory_2_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: '0.00',
                label: 'Sell price *',
                icon: Icons.payments_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: StoreSetupUi.field(
                      hint: 'pcs',
                      label: 'Unit *',
                      accent: _accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: StoreSetupUi.field(
                      hint: '1',
                      label: 'Unit qty *',
                      accent: _accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaxPicker(
              selectedName: selectedTaxName,
              onChanged: (value) => setLocal(() => selectedTaxName = value),
            ),
            StoreSetupUi.sectionLabel('Offers for this package', accent: StoreSetupUi.offersAccent),
            Text(
              'Select offers that should apply to this package. Leave none for no package-specific offers.',
              style: FontUtility.body.copyWith(
                fontSize: 12,
                color: StoreSetupUi.muted,
              ),
            ),
            const SizedBox(height: 8),
            if (_offers.isEmpty)
              Text(
                'No offers yet — create some in Offers setup.',
                style: FontUtility.body.copyWith(color: StoreSetupUi.muted),
              )
            else
              ..._offers.map((offer) {
                final offerId =
                    '${offer['local_id'] ?? offer['localId'] ?? ''}'.trim();
                final name = '${offer['name'] ?? 'Offer'}';
                final pct = offer['percentage_value'];
                final checked = selectedOffers.contains(offerId);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: StoreSetupUi.offersAccent,
                  value: checked,
                  title: Text(
                    name,
                    style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    pct == null ? 'Offer' : '$pct% off',
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: StoreSetupUi.muted,
                    ),
                  ),
                  onChanged: offerId.isEmpty
                      ? null
                      : (value) {
                          setLocal(() {
                            if (value == true) {
                              selectedOffers.add(offerId);
                            } else {
                              selectedOffers.remove(offerId);
                            }
                          });
                        },
                );
              }),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
    if (productCtrl.text.trim().isEmpty ||
        packageCtrl.text.trim().isEmpty ||
        unitCtrl.text.trim().isEmpty ||
        price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, package, unit and price are required'),
        ),
      );
      return;
    }
    await store.products.updateVariant(
      scope: store.scope,
      variantLocalId: variant.localId,
      productName: productCtrl.text.trim(),
      packageName: packageCtrl.text.trim(),
      sellPrice: price,
      unitLabel: unitCtrl.text.trim(),
      unitQty: qty,
      taxLabel: selectedTaxName ?? '',
    );
    await store.products.setVariantOfferLinks(
      scope: store.scope,
      variantLocalId: variant.localId,
      selectedOfferLocalIds: selectedOffers,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updated offline. Sync to export.')),
    );
    await _reload();
    await _refreshSellCatalogue();
  }

  Future<void> _delete(StoreProductVariantRecord variant) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete package?'),
        content: Text(
          'Remove "${variant.productName} · ${variant.productVariantName}" from this store. Sync to push the delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final store = context.read<UiStoreController>().store!;
    await store.products.softDeleteVariant(
      scope: store.scope,
      variantLocalId: variant.localId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted offline. Sync to export tombstone.')),
    );
    await _reload();
    await _refreshSellCatalogue();
  }

  Future<void> _linkMaster() async {
    if (_masters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No master products yet. Sync after another store exports.',
          ),
        ),
      );
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link a category first')),
      );
      return;
    }
    String masterId = '${_masters.first['localId']}';
    String categoryLocalId = _categories.first.localId;
    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: 'Add master product',
      accent: _accent,
      confirmLabel: 'Add',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: masterId,
              items: [
                for (final m in _masters)
                  DropdownMenuItem(
                    value: '${m['localId']}',
                    child: Text('${m['name']}'),
                  ),
              ],
              onChanged: (v) => setLocal(() => masterId = v ?? masterId),
              decoration: StoreSetupUi.field(
                hint: 'Master product',
                label: 'Master product',
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categoryLocalId,
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c.localId, child: Text(c.name)),
              ],
              onChanged: (v) =>
                  setLocal(() => categoryLocalId = v ?? categoryLocalId),
              decoration: StoreSetupUi.field(
                hint: 'Store category',
                label: 'Store category',
                accent: _accent,
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final store = context.read<UiStoreController>().store!;
    await store.products.linkMasterProduct(
      scope: store.scope,
      masterLocalId: masterId,
      categoryLocalId: categoryLocalId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Master linked with default package. Edit price, then Sync.'),
      ),
    );
    await _reload();
    await _refreshSellCatalogue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(
        title: 'Products & packages',
        accent: _accent,
        actions: [
          IconButton(
            tooltip: 'Add master to store',
            onPressed: _linkMaster,
            icon: Icon(Icons.link_rounded, color: _accent),
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add sellable item'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _variants.isEmpty
              ? StoreSetupUi.emptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No packages yet',
                  accent: _accent,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _variants.length,
                  itemBuilder: (_, i) {
                    final v = _variants[i];
                    final pending = !v.exported;
                    return StoreSetupUi.cardTile(
                      accent: _accent,
                      icon: Icons.inventory_2_rounded,
                      title: '${v.productName} · ${v.productVariantName}',
                      subtitle:
                          'Price ${v.sellPrice} · ${v.sellUnitLabel ?? v.sellUnitShort ?? 'unit'} × ${v.sellUnitBaseQty ?? 1}',
                      onTap: () => _edit(v),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StoreSetupUi.statusChip(
                            pending ? 'Pending' : 'Synced',
                            pending: pending,
                            accent: _accent,
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _delete(v),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
