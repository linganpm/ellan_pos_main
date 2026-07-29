import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import '../../core/localization/l10n_context.dart';

enum PosToastKind { success, failed }

/// Compact corner toast: title is Success / Failed; details behind an (i) icon.
class PosToast {
  PosToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void success(
    BuildContext context, {
    String? detail,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      kind: PosToastKind.success,
      detail: detail,
      duration: duration,
    );
  }

  static void failed(
    BuildContext context, {
    String? detail,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      kind: PosToastKind.failed,
      detail: detail,
      duration: duration,
    );
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static void _show(
    BuildContext context, {
    required PosToastKind kind,
    String? detail,
    required Duration duration,
  }) {
    dismiss();
    // Also clear any lingering Material snackbars.
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _PosToastCard(
        kind: kind,
        detail: (detail ?? '').trim(),
        onClose: dismiss,
        onHold: () {
          _timer?.cancel();
          _timer = null;
        },
        onResume: () {
          _timer?.cancel();
          _timer = Timer(duration, dismiss);
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }
}

class _PosToastCard extends StatefulWidget {
  final PosToastKind kind;
  final String detail;
  final VoidCallback onClose;
  final VoidCallback onHold;
  final VoidCallback onResume;

  const _PosToastCard({
    required this.kind,
    required this.detail,
    required this.onClose,
    required this.onHold,
    required this.onResume,
  });

  @override
  State<_PosToastCard> createState() => _PosToastCardState();
}

class _PosToastCardState extends State<_PosToastCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  bool get _isSuccess => widget.kind == PosToastKind.success;
  bool get _hasDetail => widget.detail.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0.15, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleDetail() {
    if (!_hasDetail) return;
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      widget.onHold();
    } else {
      widget.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isSuccess
        ? const Color(0xFF1B7F4E)
        : const Color(0xFFB42318);
    final bg = _isSuccess ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2);
    final border = _isSuccess
        ? const Color(0xFFABEFC6)
        : const Color(0xFFFECDCA);
    final title = _isSuccess
        ? context.l10n.commonSuccess
        : context.l10n.commonFailed;
    final leadingIcon = _isSuccess
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 168, maxWidth: 280),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(leadingIcon, color: accent, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: FontUtility.subheading.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            if (_hasDetail) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: _expanded
                                    ? context.l10n.commonHideDetails
                                    : context.l10n.commonDetails,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: _toggleDetail,
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: accent.withValues(alpha: 0.9),
                                ),
                              ),
                            ] else
                              const SizedBox(width: 8),
                            IconButton(
                              tooltip: context.l10n.commonDismiss,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: widget.onClose,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                        if (_expanded && _hasDetail) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              widget.detail,
                              style: FontUtility.body.copyWith(
                                fontSize: 13,
                                height: 1.35,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
