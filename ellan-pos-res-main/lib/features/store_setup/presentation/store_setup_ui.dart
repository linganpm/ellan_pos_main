import 'package:flutter/material.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import '../../../core/localization/l10n_context.dart';

/// Shared chrome for offline store-setup catalogue screens.
class StoreSetupUi {
  static const Color primary = Color(0xFF4A00E0);
  static const Color canvas = Color(0xFFF3F5F9);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  static const Color productsAccent = Color(0xFF0EA5E9);
  static const Color categoriesAccent = Color(0xFFF59E0B);
  static const Color offersAccent = Color(0xFFEC4899);
  static const Color addonsAccent = Color(0xFF10B981);

  static InputDecoration field({
    required String hint,
    String? label,
    IconData? icon,
    Color accent = primary,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: accent.withValues(alpha: 0.85)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    );
  }

  static PreferredSizeWidget appBar({
    required String title,
    required Color accent,
    List<Widget>? actions,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: FontUtility.heading.copyWith(fontSize: 22, color: ink),
          ),
        ],
      ),
      actions: actions,
    );
  }

  static Widget iconAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
        ),
      ),
    );
  }

  static Widget addButton({
    required String label,
    required VoidCallback onPressed,
    required Color accent,
    IconData icon = Icons.add_rounded,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          child: Icon(icon),
        ),
      ),
    );
  }

  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color accent,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: accent, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FontUtility.heading.copyWith(fontSize: 22, color: ink),
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(color: muted, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget statusChip(
    String label, {
    required bool pending,
    Color? accent,
  }) {
    final color = pending
        ? const Color(0xFFEA580C)
        : (accent ?? const Color(0xFF059669));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: FontUtility.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Widget cardTile({
    required Color accent,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final trimmedSubtitle = subtitle?.trim() ?? '';
    final hasSubtitle = trimmedSubtitle.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ink,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          trimmedSubtitle,
                          style: FontUtility.body.copyWith(
                            color: muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> showFormDialog({
    required BuildContext context,
    required String title,
    required Color accent,
    required Widget child,
    String? confirmLabel,
    double width = 460,
  }) {
    final resolvedConfirm = confirmLabel ?? context.l10n.commonSaveOffline;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.edit_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: FontUtility.heading.copyWith(fontSize: 22, color: ink),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.actionCancel,
              style: FontUtility.body.copyWith(color: muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(resolvedConfirm),
          ),
        ],
      ),
    );
  }

  static Widget sectionLabel(String text, {Color accent = primary}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: FontUtility.body.copyWith(
              fontWeight: FontWeight.w800,
              color: ink,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
