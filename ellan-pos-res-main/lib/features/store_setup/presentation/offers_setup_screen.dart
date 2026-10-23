import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

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
      final localId = '${existing['local_id'] ?? existing['localId'] ?? ''}'
          .trim();
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
      title: existing == null
          ? context.l10n.storeSetupNewOffer
          : context.l10n.storeSetupEditOffer,
      accent: _accent,
      width: 480,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RubberPush(child: TextField(
              controller: nameCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Lunch special',
                label: context.l10n.storeSetupNameRequired,
                icon: Icons.local_offer_rounded,
                accent: _accent,
              ),
            )),
            const SizedBox(height: 12),
            RubberPush(child: TextField(
              controller: pctCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: 'e.g. 10',
                label: context.l10n.storeSetupPercentOff,
                icon: Icons.percent_rounded,
                accent: _accent,
              ),
            )),
            const SizedBox(height: 12),
            RubberPush(child: TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: context.l10n.storeSetupOptionalMinBill,
                label: context.l10n.storeSetupMinBill,
                icon: Icons.shopping_bag_outlined,
                accent: _accent,
              ),
            )),
            StoreSetupUi.sectionLabel(
              context.l10n.storeSetupLinkPackagesOptional,
              accent: StoreSetupUi.productsAccent,
            ),
            const SizedBox(height: 8),
            if (_variants.isEmpty)
              Text(
                context.l10n.storeSetupNoPackagesCreateProducts,
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
                    style: FontUtility.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
    final localId = '${existing?['local_id'] ?? existing?['localId'] ?? ''}'
        .trim();
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
          existing == null
              ? context.l10n.storeSetupOfferSavedOffline
              : context.l10n.storeSetupOfferUpdatedOffline,
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
        title: Text(context.l10n.storeSetupDeleteOffer),
        content: Text(
          context.l10n.storeSetupRemoveEntitySync('${offer['name']}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.actionDelete),
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
      SnackBar(content: Text(context.l10n.storeSetupOfferDeletedOffline)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(
        title: context.l10n.commonOffers,
        accent: _accent,
      ),
      floatingActionButton: StoreSetupUi.addButton(
        label: context.l10n.storeSetupAddOffer,
        onPressed: () => _upsert(),
        accent: _accent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _offers.isEmpty
          ? StoreSetupUi.emptyState(
              icon: Icons.local_offer_outlined,
              title: context.l10n.storeSetupNoOffersEmpty,
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
                        pending
                            ? context.l10n.commonPending
                            : context.l10n.commonSynced,
                        pending: pending,
                        accent: _accent,
                      ),
                      StoreSetupUi.iconAction(
                        label: context.l10n.actionDelete,
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
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
