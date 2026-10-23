import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/bloc/sync/sync_cubit.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import '../../core/localization/l10n_context.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => SyncCubit(), child: const _SyncView());
  }
}

class _SyncView extends StatefulWidget {
  const _SyncView();

  @override
  State<_SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<_SyncView> {
  static const Color _primary = Color(0xFF4A00E0);

  List<StoreSyncAttemptRecord> _history = const [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final history = await getIt<UiStoreController>().loadSyncHistory(
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _history = const [];
        _historyLoading = false;
      });
    }
  }

  void _showHistoryDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            context.l10n.syncHistory45,
            style: FontUtility.heading.copyWith(fontSize: 20),
          ),
          content: SizedBox(
            width: 520,
            child: _historyLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                ? Text(
                    context.l10n.syncNoAttemptsYet,
                    style: FontUtility.body.copyWith(color: Colors.black54),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _history.length; i++) ...[
                          if (i > 0) const Divider(height: 20),
                          _SyncHistoryTile(entry: _history[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                context.l10n.actionClose,
                style: FontUtility.button.copyWith(color: Colors.black54),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: PosBrandTitle(
          child: Text(
          context.l10n.syncDataSync,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.l10n.syncHistory,
            onPressed: _showHistoryDialog,
            icon: const Icon(Icons.history_rounded, color: _primary),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<SyncCubit, SyncState>(
          listenWhen: (previous, current) =>
              previous.isRunning && !current.isRunning,
          listener: (context, state) {
            _loadHistory();
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.storeName == null || state.storeName!.isEmpty
                              ? context.l10n.syncStoreWithRemote
                              : context.l10n.syncNamedStoreWithRemote(
                                  state.storeName!,
                                ),
                          style: FontUtility.subheading.copyWith(fontSize: 18),
                        ),
                      ),
                      _LastSyncBadge(lastSyncAt: state.lastSuccessfulSyncAt),
                    ],
                  ),
                  if (state.isOffline) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.orange.shade800,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.l10n.syncServerUnreachable,
                              style: FontUtility.body.copyWith(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.read<SyncCubit>().refreshReachability(),
                            child: Text(
                              context.l10n.actionRetry,
                              style: FontUtility.button.copyWith(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (state.isRunning || state.completed)
                    _SyncCountsSummary(items: state.items),
                  Expanded(
                    child: ListView(
                      children: [
                        _SectionHeader(
                          icon: Icons.cloud_download_rounded,
                          label: context.l10n.syncDownloadFromRemote,
                        ),
                        const SizedBox(height: 10),
                        for (final item in state.downloadItems) ...[
                          _SyncChecklistTile(item: item),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        _SectionHeader(
                          icon: Icons.cloud_upload_rounded,
                          label: context.l10n.syncUploadToRemote,
                        ),
                        const SizedBox(height: 10),
                        for (final item in state.uploadItems) ...[
                          _SyncChecklistTile(item: item),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: FontUtility.body.copyWith(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: state.isRunning || state.isOffline
                          ? null
                          : () => context.read<SyncCubit>().runSync(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: state.isRunning || state.isOffline ? 0 : 3,
                      ),
                      icon: state.isRunning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              state.isOffline
                                  ? Icons.cloud_off_rounded
                                  : state.completed
                                  ? Icons.sync_rounded
                                  : Icons.cloud_sync_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        state.isRunning
                            ? context.l10n.syncSyncing
                            : state.isOffline
                            ? context.l10n.syncOfflineWhenOnline
                            : state.completed
                            ? context.l10n.syncAgain
                            : context.l10n.syncStart,
                        style: FontUtility.button.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SyncHistoryTile extends StatelessWidget {
  final StoreSyncAttemptRecord entry;

  const _SyncHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ok = entry.success && !entry.skipped;
    final color = entry.skipped
        ? Colors.orange.shade700
        : (ok ? Colors.green.shade700 : Colors.red.shade700);
    final when =
        DateTime.tryParse(entry.completedAt) ??
        DateTime.tryParse(entry.startedAt);
    final stamp = when == null
        ? context.l10n.commonEmpty
        : DateFormat('MMM dd, hh:mm a').format(when.toLocal());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: entry.direction == 'import'
              ? context.l10n.syncDownloadFromRemote
              : context.l10n.syncUploadToRemote,
          child: Icon(
            entry.direction == 'import'
                ? Icons.cloud_download_rounded
                : Icons.cloud_upload_rounded,
            size: 20,
            color: const Color(0xFF4A00E0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.entity,
                style: FontUtility.subheading.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                stamp,
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              if (entry.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.message,
                  style: FontUtility.body.copyWith(fontSize: 13),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                context.l10n.syncHistoryStats(
                  entry.processedCount,
                  entry.successCount,
                  entry.failureCount,
                ),
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Text(
          entry.skipped
              ? context.l10n.commonSkipped
              : (ok ? context.l10n.commonSuccess : context.l10n.commonFailed),
          style: FontUtility.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SyncCountsSummary extends StatelessWidget {
  final List<SyncChecklistItem> items;

  const _SyncCountsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final counted = items
        .where(
          (item) =>
              item.totalCount > 0 ||
              item.status == SyncItemStatus.running ||
              item.status == SyncItemStatus.success ||
              item.status == SyncItemStatus.failed,
        )
        .toList(growable: false);
    if (counted.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF4A00E0).withValues(alpha: 0.15),
          ),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in counted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.totalCount > 0
                      ? '${item.title}: ${item.successCount} synced / ${item.totalCount} total'
                      : '${item.title}: ${item.detail ?? ''}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B0764),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4A00E0)),
        const SizedBox(width: 8),
        Text(
          label,
          style: FontUtility.subheading.copyWith(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _LastSyncBadge extends StatelessWidget {
  final DateTime? lastSyncAt;

  const _LastSyncBadge({required this.lastSyncAt});

  @override
  Widget build(BuildContext context) {
    final formatted = lastSyncAt == null
        ? context.l10n.syncNeverSynced
        : context.l10n.syncLastSync(
            DateFormat('MMM dd, yyyy hh:mm a').format(lastSyncAt!.toLocal()),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lastSyncAt == null
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lastSyncAt == null
              ? Colors.orange.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lastSyncAt == null
                ? Icons.cloud_off_rounded
                : Icons.check_circle_rounded,
            size: 16,
            color: lastSyncAt == null
                ? Colors.orange.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            formatted,
            style: FontUtility.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: lastSyncAt == null
                  ? Colors.orange.shade800
                  : Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncChecklistTile extends StatelessWidget {
  final SyncChecklistItem item;

  const _SyncChecklistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _statusVisuals(item.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: item.status == SyncItemStatus.running
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: FontUtility.subheading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: FontUtility.body.copyWith(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                if (item.detail != null && item.detail!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.detail!,
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (item.status == SyncItemStatus.running ||
                    item.totalCount > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.progressFraction,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(context, item.status),
            style: FontUtility.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _statusVisuals(SyncItemStatus status) {
    switch (status) {
      case SyncItemStatus.pending:
        return (
          Icons.radio_button_unchecked,
          Colors.grey.shade500,
          Colors.grey.shade100,
        );
      case SyncItemStatus.running:
        return (
          Icons.sync,
          const Color(0xFF4A00E0),
          const Color(0xFF4A00E0).withValues(alpha: 0.1),
        );
      case SyncItemStatus.success:
        return (
          Icons.check_circle,
          Colors.green.shade700,
          Colors.green.shade50,
        );
      case SyncItemStatus.failed:
        return (Icons.error_rounded, Colors.red.shade700, Colors.red.shade50);
      case SyncItemStatus.skipped:
        return (
          Icons.remove_circle_outline,
          Colors.orange.shade700,
          Colors.orange.shade50,
        );
    }
  }

  String _statusLabel(BuildContext context, SyncItemStatus status) {
    switch (status) {
      case SyncItemStatus.pending:
        return context.l10n.commonPending;
      case SyncItemStatus.running:
        return context.l10n.syncRunning;
      case SyncItemStatus.success:
        return context.l10n.commonDone;
      case SyncItemStatus.failed:
        return context.l10n.commonFailed;
      case SyncItemStatus.skipped:
        return context.l10n.commonSkipped;
    }
  }
}
