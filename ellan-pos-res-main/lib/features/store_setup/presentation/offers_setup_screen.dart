import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';

class OffersSetupScreen extends StatefulWidget {
  const OffersSetupScreen({super.key});

  @override
  State<OffersSetupScreen> createState() => _OffersSetupScreenState();
}

class _OffersSetupScreenState extends State<OffersSetupScreen> {
  static const _accent = StoreSetupUi.offersAccent;

  List<Map<String, dynamic>> _offers = [];
  List<StoreProductVariantRecord> _variants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final store = context.read<UiStoreController>().store!;
    final offers = await store.products.listOffers(store.scope);
    final variants = await store.products.searchDetails(scope: store.scope);
    if (!mounted) return;
    setState(() {
      _offers = offers;
      _variants = variants;
      _loading = false;
    });
  }

  Future<void> _upsert({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: '${existing?['name'] ?? ''}');
    final pctCtrl = TextEditingController(
      text: '${existing?['percentage_value'] ?? ''}',
    );
    final minCtrl = TextEditingController(
      text: existing?['minimum_bill_amount'] == null
          ? ''
          : '${existing?['minimum_bill_amount']}',
    );
    final selected = <String>{};
    if (existing != null) {
      final store = context.read<UiStoreController>().store!;
      final localId =
          '${existing['local_id'] ?? existing['localId'] ?? ''}'.trim();
      if (localId.isNotEmpty) {
        final targets = await store.products.listOfferTargetVariantIds(
          store.scope,
          localId,
        );
        selected.addAll(targets);
      }
    }

    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: existing == null ? 'New offer' : 'Edit offer',
      accent: _accent,
      width: 480,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Lunch special',
                label: 'Name *',
                icon: Icons.local_offer_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pctCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: 'e.g. 10',
                label: 'Percent off',
                icon: Icons.percent_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: 'Optional minimum bill',
                label: 'Min bill',
                icon: Icons.shopping_bag_outlined,
                accent: _accent,
              ),
            ),
            StoreSetupUi.sectionLabel(
              'Link to packages (optional)',
              accent: StoreSetupUi.productsAccent,
            ),
            Text(
              'Leave empty for a whole-bill offer. Select packages to limit where it applies.',
              style: FontUtility.body.copyWith(
                fontSize: 12,
                color: StoreSetupUi.muted,
              ),
            ),
            const SizedBox(height: 8),
            if (_variants.isEmpty)
              Text(
                'No packages yet — create products first.',
                style: FontUtility.body.copyWith(color: StoreSetupUi.muted),
              )
            else
              ..._variants.map((v) {
                final checked = selected.contains(v.localId);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  value: checked,
                  title: Text(
                    '${v.productName} · ${v.productVariantName}',
                    style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  onChanged: (value) {
                    setLocal(() {
                      if (value == true) {
                        selected.add(v.localId);
                      } else {
                        selected.remove(v.localId);
                      }
                    });
                  },
                );
              }),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final store = context.read<UiStoreController>().store!;
    final localId =
        '${existing?['local_id'] ?? existing?['localId'] ?? ''}'.trim();
    await store.products.upsertOffer(
      scope: store.scope,
      localId: localId.isEmpty ? null : localId,
      name: nameCtrl.text.trim(),
      offerType: 'percentage',
      percentageValue: double.tryParse(pctCtrl.text.trim()) ?? 10,
      minimumBillAmount: double.tryParse(minCtrl.text.trim()),
      targetVariantLocalIds: selected.toList(growable: false),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Offer saved offline' : 'Offer updated offline',
        ),
      ),
    );
    await _reload();
  }

  Future<void> _delete(Map<String, dynamic> offer) async {
    final localId = '${offer['local_id'] ?? offer['localId'] ?? ''}'.trim();
    if (localId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete offer?'),
        content: Text('Remove "${offer['name']}". Sync to export.'),
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
    await store.products.softDeleteOffer(
      scope: store.scope,
      offerLocalId: localId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer deleted offline. Sync to export.')),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(title: 'Offers', accent: _accent),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsert(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add offer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _offers.isEmpty
              ? StoreSetupUi.emptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'No offers yet',
                  accent: _accent,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _offers.length,
                  itemBuilder: (_, i) {
                    final o = _offers[i];
                    final targetType = '${o['target_type'] ?? 'bill'}';
                    final pending = o['exported'] == 0;
                    return StoreSetupUi.cardTile(
                      accent: _accent,
                      icon: Icons.local_offer_rounded,
                      title: '${o['name']}',
                      subtitle:
                          '${o['percentage_value'] ?? o['flat_value'] ?? ''}% · '
                          '${targetType == 'product' ? 'Linked packages' : 'Whole bill'}',
                      onTap: () => _upsert(existing: o),
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
                            onPressed: () => _delete(o),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
