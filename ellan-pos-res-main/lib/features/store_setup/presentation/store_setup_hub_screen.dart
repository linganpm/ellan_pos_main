import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/features/store_setup/presentation/addons_setup_screen.dart';
import 'package:pos_tablet/features/store_setup/presentation/categories_setup_screen.dart';
import 'package:pos_tablet/features/store_setup/presentation/offers_setup_screen.dart';
import 'package:pos_tablet/features/store_setup/presentation/products_setup_screen.dart';
import 'package:pos_tablet/features/store_setup/presentation/staff_signup_screen.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

/// Offline-first store setup hub. Catalogue edits stay local until Sync exports.
class StoreSetupHubScreen extends StatefulWidget {
  const StoreSetupHubScreen({super.key});

  @override
  State<StoreSetupHubScreen> createState() => _StoreSetupHubScreenState();
}

class _StoreSetupHubScreenState extends State<StoreSetupHubScreen> {
  static const _primary = Color(0xFF4A00E0);
  int? _categories;
  int? _products;
  int? _offers;
  int? _addons;
  int? _staff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCounts();
    });
  }

  Future<void> _loadCounts() async {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    if (store == null) return;
    try {
      final categories = await store.products.listCategories(store.scope);
      final products = await store.products.searchDetails(scope: store.scope);
      final offers = await store.products.listOffers(store.scope);
      final addons = await store.products.listCatalogAddonGroups(store.scope);
      final staff = await controller.listLocalStaffOptions(
        storeId: store.scope.storeId,
      );
      if (!mounted) return;
      setState(() {
        _categories = categories.length;
        _products = products.length;
        _offers = offers.length;
        _addons = addons.length;
        _staff = staff.length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    final hasStore = store != null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        try {
          await controller.loadCatalogue();
        } catch (_) {}
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          title: PosBrandTitle(
            child: Text(
            context.l10n.storeSetupTitle,
            style: FontUtility.heading.copyWith(fontSize: 22),
          ),
          ),
          actions: [
            Tooltip(
              message: context.l10n.storeSetupSyncExport,
              child: Semantics(
                label: context.l10n.storeSetupSyncExport,
                button: true,
                child: IconButton(
                  onPressed: !hasStore
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.commonExporting),
                            ),
                          );
                          try {
                            final batch = await controller.syncFromRemote();
                            final productOps = batch.operations.where(
                              (op) =>
                                  op.entity == 'products' &&
                                  op.direction == 'export',
                            );
                            final productExport = productOps.isEmpty
                                ? null
                                : productOps.first;
                            if (productExport != null &&
                                productExport.skipped) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    productExport.message.trim().isNotEmpty
                                        ? productExport.message
                                        : context
                                              .l10n
                                              .storeSetupExportNotConfigured,
                                  ),
                                ),
                              );
                              return;
                            }
                            if (productExport != null &&
                                !productExport.success) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n
                                        .storeSetupCatalogueExportFailed(
                                          productExport.message,
                                        ),
                                  ),
                                ),
                              );
                              return;
                            }
                            final exported = productExport?.successCount ?? 0;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  exported > 0
                                      ? context.l10n
                                            .storeSetupSyncFinishedExported(
                                              exported,
                                            )
                                      : context.l10n.storeSetupSyncFinishedNone,
                                ),
                              ),
                            );
                            await controller.loadCatalogue();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.storeSetupSyncFailed(
                                    userFacingError(
                                      e,
                                      fallback: context.l10n.errorCouldNotSync,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.sync_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: !hasStore
            ? Center(
                child: Text(
                  context.l10n.homeOpenStoreFirst,
                  style: FontUtility.body.copyWith(color: Colors.black54),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      style: FontUtility.heading.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 560
                              ? 2
                              : 1;
                          final tiles = [
                            _tile(
                              context,
                              icon: Icons.category_rounded,
                              title: context.l10n.commonCategories,
                              count: _categories,
                              onTap: () => _open(const CategoriesSetupScreen()),
                            ),
                            _tile(
                              context,
                              icon: Icons.inventory_2_rounded,
                              title: context.l10n.commonProducts,
                              count: _products,
                              onTap: () => _open(const ProductsSetupScreen()),
                            ),
                            _tile(
                              context,
                              icon: Icons.local_offer_rounded,
                              title: context.l10n.commonOffers,
                              count: _offers,
                              onTap: () => _open(const OffersSetupScreen()),
                            ),
                            _tile(
                              context,
                              icon: Icons.extension_rounded,
                              title: context.l10n.commonAddons,
                              count: _addons,
                              onTap: () => _open(const AddonsSetupScreen()),
                            ),
                            _tile(
                              context,
                              icon: Icons.person_add_alt_1_rounded,
                              title: context.l10n.storeSetupAddCashier,
                              count: _staff,
                              onTap: () => _open(const StaffSignupScreen()),
                            ),
                            _tile(
                              context,
                              icon: Icons.point_of_sale_rounded,
                              title: context.l10n.commonBackToSelling,
                              onTap: () async {
                                try {
                                  await controller.loadCatalogue();
                                } catch (_) {}
                                if (!context.mounted) return;
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.home,
                                );
                              },
                            ),
                          ];
                          return GridView.count(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: columns == 1 ? 5.2 : 3.4,
                            children: tiles,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) await _loadCounts();
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int? count,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: _primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtility.body.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  '$count',
                  style: FontUtility.heading.copyWith(
                    color: _primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
