import 'package:flutter/material.dart';
import '../widgets/pos_brand_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import '../../core/routes.dart';
import '../../bloc/store_list/store_list_bloc.dart';
import '../../bloc/store_list/store_list_state.dart';
import '../../data/models/store_model.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

/// Store List Screen - Premium tablet-optimized UI for store selection
///
/// This screen allows users to select a store from the available list
/// before proceeding to the main dashboard. The left side uses the same
/// branding layout as the welcome screen, while the right side displays
/// an elegant store selection interface.
///
/// When [returnToStaffLock] is true (Switch store from the lock screen),
/// a successful selection opens the branch then returns to staff unlock
/// instead of auto-entering the previous operator's home session.
class StoreListScreen extends StatelessWidget {
  final bool returnToStaffLock;

  const StoreListScreen({super.key, this.returnToStaffLock = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StoreListCubit()..loadStores(),
      child: Scaffold(
        body: Stack(
          children: [_buildLayout(context), const _StoreSyncProgressOverlay()],
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PosBrandLogo(size: 80),
                    const SizedBox(height: 32),
                    Text(
                      context.l10n.appName,
                      style: FontUtility.heading.copyWith(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.storeListSelectStore,
                      style: FontUtility.heading.copyWith(
                        color: const Color(0xFF333333),
                        fontSize: 36,
                      ),
                    ),
                    if (returnToStaffLock) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.storeListChooseBranchUnlock,
                        style: FontUtility.body.copyWith(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildStoreListContent()),
                    const SizedBox(height: 16),
                    _buildSubmitButton(),
                    const SizedBox(height: 8),
                    _buildExitActions(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExitActions(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (returnToStaffLock)
          TextButton(
            onPressed: () {
              final controller = getIt<UiStoreController>();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.staffLock,
                (route) => false,
                arguments: {
                  'storeId': controller.store?.scope.storeId,
                  'storeName': controller.store?.storeName,
                },
              );
            },
            child: Text(
              context.l10n.storeListBackToUnlock,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          },
          child: Text(
            context.l10n.staffLockOnlineSignIn,
            style: FontUtility.body.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return BlocBuilder<StoreListCubit, StoreListState>(
      builder: (context, state) {
        return RubberPush(child: TextField(
          onChanged: (query) {
            context.read<StoreListCubit>().searchStores(query);
          },
          decoration: InputDecoration(
            hintText: context.l10n.storeListSearchHint,
            hintStyle: FontUtility.body.copyWith(color: Colors.black38),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF4A00E0)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: PosFields.border,
            enabledBorder: PosFields.border,
            focusedBorder: PosFields.border,
          ),
          style: FontUtility.body,
        ));
      },
    );
  }

  Widget _buildStoreListContent() {
    return BlocBuilder<StoreListCubit, StoreListState>(
      builder: (context, state) {
        if (state is StoreListLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF4A00E0),
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.storeListLoading,
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (state is StoreListError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage,
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.read<StoreListCubit>().loadStores(),
                  child: Text(context.l10n.actionRetry),
                ),
              ],
            ),
          );
        }

        final cubit = context.read<StoreListCubit>();
        List<StoreModel> stores = [];
        String? selectedStoreId;

        if (state is StoreListLoaded) {
          stores = state.filteredStores ?? state.stores;
          selectedStoreId = state.selectedStoreId;
        } else if (state is StoreSelectionChanged) {
          stores = state.allStores;
          selectedStoreId = state.selectedStore.storeId;
        } else if (state is StoreVerificationLoading) {
          stores = cubit.allStores;
          selectedStoreId = state.store.storeId;
        } else if (state is StoreVerificationFailure ||
            state is StoreVerificationSuccess) {
          stores = cubit.allStores;
          selectedStoreId = cubit.selectedStoreId;
        }

        if (stores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.store_outlined,
                  size: 48,
                  color: Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.storeListEmpty,
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final isSelected = selectedStoreId == store.storeId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildStoreCard(
                context: context,
                store: store,
                isSelected: isSelected,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoreCard({
    required BuildContext context,
    required StoreModel store,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        context.read<StoreListCubit>().selectStore(store.storeId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A00E0).withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A00E0) : Colors.black12,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A00E0).withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8E2DE2).withValues(alpha: 0.8),
                      const Color(0xFF4A00E0).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      store.storeName,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.storeListStoreId(store.storeId),
                      style: FontUtility.body.copyWith(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRoleBadge(store.storeRole),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4A00E0)
                          : Colors.black26,
                      width: 2.0,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4A00E0),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    Color textColor;

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      case 'manager':
        badgeColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
      case 'cashier':
        badgeColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      default:
        badgeColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: FontUtility.body.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocListener<StoreListCubit, StoreListState>(
      listener: (context, state) async {
        if (state is StoreVerificationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.storeSelectedSuccess(state.store.storeName),
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );

          if (returnToStaffLock) {
            // openStore binds the cached org login as the store session —
            // clear it so the next operator must unlock explicitly.
            try {
              await getIt<UiStoreController>().lockStaff();
            } catch (_) {}
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.staffLock,
              (route) => false,
              arguments: {
                'storeId': state.store.storeId,
                'storeName': state.store.storeName,
              },
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        } else if (state is StoreVerificationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: BlocBuilder<StoreListCubit, StoreListState>(
        builder: (context, state) {
          final cubit = context.read<StoreListCubit>();
          final isLoading = state is StoreVerificationLoading;
          final syncMessage = state is StoreVerificationLoading
              ? state.message
              : null;
          final isEnabled = (cubit.selectedStoreId ?? '').isNotEmpty;

          return SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isEnabled && !isLoading
                  ? () {
                      context.read<StoreListCubit>().verifySelectedStore();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isEnabled ? 5 : 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          if (syncMessage != null &&
                              syncMessage.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                syncMessage,
                                overflow: TextOverflow.ellipsis,
                                style: FontUtility.button.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        returnToStaffLock
                            ? context.l10n.storeListOpenBranch
                            : context.l10n.actionContinue,
                        style: FontUtility.button.copyWith(
                          color: isEnabled
                              ? Colors.white
                              : Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Blocking popup while the selected branch opens and pulls its catalogue.
class _StoreSyncProgressOverlay extends StatelessWidget {
  const _StoreSyncProgressOverlay();

  static const _accent = Color(0xFF4A00E0);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreListCubit, StoreListState>(
      buildWhen: (prev, next) =>
          prev is StoreVerificationLoading || next is StoreVerificationLoading,
      builder: (context, state) {
        final loading = state is StoreVerificationLoading ? state : null;
        return IgnorePointer(
          ignoring: loading == null,
          child: AnimatedOpacity(
            opacity: loading == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: loading == null
                ? const SizedBox.expand()
                : ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _card(context, loading),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, StoreVerificationLoading state) {
    final message = state.message?.trim() ?? '';
    return Material(
      color: Colors.white,
      elevation: 12,
      borderRadius: BorderRadius.circular(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: _accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.storeSyncTitle(state.store.storeName),
                textAlign: TextAlign.center,
                style: FontUtility.heading.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.storeSyncBody,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 8,
                  color: _accent,
                  backgroundColor: _accent.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty ? message : context.l10n.storeSyncPreparing,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FontUtility.body.copyWith(
                  color: const Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state.counts.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final line in state.counts) ...[
                          _SyncCountRow(line: line),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncCountRow extends StatelessWidget {
  final StoreSyncCountLine line;

  const _SyncCountRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final color = line.failedStep
        ? Colors.red.shade700
        : line.done
        ? Colors.green.shade700
        : const Color(0xFF4A00E0);
    final count = line.total > 0
        ? '${line.synced} synced / ${line.total} total'
        : line.done
        ? '0 synced / 0 total'
        : '…';
    final failed = line.failed > 0 ? ' · ${line.failed} failed' : '';
    final note = line.background ? ' · background' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                line.label,
                style: FontUtility.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            Text(
              '$count$failed$note',
              style: FontUtility.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: line.fraction,
            minHeight: 4,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}
