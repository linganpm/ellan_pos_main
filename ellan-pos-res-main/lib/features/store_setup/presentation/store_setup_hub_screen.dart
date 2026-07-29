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

/// Offline-first store setup hub. Catalogue edits stay local until Sync exports.
class StoreSetupHubScreen extends StatelessWidget {
  const StoreSetupHubScreen({super.key});

  static const _primary = Color(0xFF4A00E0);

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
          title: Text(
            'Store setup',
            style: FontUtility.heading.copyWith(fontSize: 22),
          ),
          actions: [
            TextButton.icon(
              onPressed: !hasStore
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Exporting catalogue…')),
                      );
                      try {
                        final batch = await controller.syncFromRemote();
                        final productOps = batch.operations.where(
                          (op) =>
                              op.entity == 'products' &&
                              op.direction == 'export',
                        );
                        final productExport =
                            productOps.isEmpty ? null : productOps.first;
                        if (productExport != null && productExport.skipped) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                productExport.message.trim().isNotEmpty
                                    ? productExport.message
                                    : 'Catalogue export not configured — local edits stayed on this tablet.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (productExport != null && !productExport.success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Catalogue export failed: ${productExport.message}',
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
                                  ? 'Sync finished — exported $exported catalogue row(s).'
                                  : 'Sync finished — no pending catalogue changes to export.',
                            ),
                          ),
                        );
                        await controller.loadCatalogue();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sync failed: ${userFacingError(e, fallback: 'Could not sync. Try again.')}',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync / export'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: !hasStore
            ? Center(
                child: Text(
                  'Open a store first',
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
                      style: FontUtility.heading.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.45,
                        children: [
                          _tile(
                            context,
                            icon: Icons.category_rounded,
                            title: 'Categories',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CategoriesSetupScreen(),
                              ),
                            ),
                          ),
                          _tile(
                            context,
                            icon: Icons.inventory_2_rounded,
                            title: 'Products',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProductsSetupScreen(),
                              ),
                            ),
                          ),
                          _tile(
                            context,
                            icon: Icons.local_offer_rounded,
                            title: 'Offers',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OffersSetupScreen(),
                              ),
                            ),
                          ),
                          _tile(
                            context,
                            icon: Icons.extension_rounded,
                            title: 'Add-ons',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddonsSetupScreen(),
                              ),
                            ),
                          ),
                          _tile(
                            context,
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Add cashier',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StaffSignupScreen(),
                              ),
                            ),
                          ),
                          _tile(
                            context,
                            icon: Icons.point_of_sale_rounded,
                            title: 'Back to selling',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _primary, size: 36),
              const Spacer(),
              Text(
                title,
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
