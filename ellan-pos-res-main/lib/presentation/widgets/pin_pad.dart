import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/l10n_context.dart';
import '../../core/pos_lock_pin.dart';
import '../../core/utils/font_utility.dart';

const _accent = Color(0xFF4A00E0);
const _danger = Color(0xFFD92D20);

/// Dots + numeric keypad; also accepts digits / backspace from a keyboard.
class PinPad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool error;
  final bool enabled;

  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.error = false,
    this.enabled = true,
  });

  void _digit(String d) {
    if (!enabled || value.length >= kPosPinLength) return;
    onChanged(value + d);
  }

  void _backspace() {
    if (!enabled || value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      _digit(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < kPosPinLength; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < value.length
                        ? (error ? _danger : _accent)
                        : Colors.transparent,
                    border: Border.all(
                      color: error ? _danger : _accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final d in row) _key(d, () => _digit(d))],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 88, height: 72),
              _key('0', () => _digit('0')),
              _key(
                '',
                _backspace,
                icon: Icons.backspace_outlined,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(
    String label,
    VoidCallback onTap, {
    IconData? icon,
    String? tooltip,
  }) {
    final child = icon != null
        ? Icon(icon, color: const Color(0xFF374151), size: 24)
        : Text(
            label,
            style: FontUtility.heading.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          );
    final button = Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 72,
        height: 56,
        child: Material(
          color: icon != null ? Colors.transparent : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: Center(child: child),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Asks the staff member to choose and confirm a PIN, then calls [onSubmit]
/// (which returns an error message, or null on success). Not dismissible.
Future<void> showCreatePinDialog(
  BuildContext context, {
  required Future<String?> Function(String pin) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PopScope(canPop: false, child: _CreatePinDialog(onSubmit: onSubmit)),
  );
}

class _CreatePinDialog extends StatefulWidget {
  final Future<String?> Function(String pin) onSubmit;

  const _CreatePinDialog({required this.onSubmit});

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  String _first = '';
  String _value = '';
  String? _error;
  bool _saving = false;

  bool get _confirming => _first.isNotEmpty;

  Future<void> _onChanged(String value) async {
    setState(() {
      _value = value;
      _error = null;
    });
    if (value.length < kPosPinLength) return;

    if (!_confirming) {
      setState(() {
        _first = value;
        _value = '';
      });
      return;
    }
    if (value != _first) {
      setState(() {
        _error = context.l10n.pinMismatch;
        _first = '';
        _value = '';
      });
      return;
    }

    setState(() => _saving = true);
    final error = await widget.onSubmit(value);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
      _first = '';
      _value = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_rounded, color: _accent, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              _confirming ? l10n.pinConfirmTitle : l10n.pinCreateTitle,
              style: FontUtility.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pinCreateBody(kPosPinLength),
              textAlign: TextAlign.center,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            PinPad(
              key: ValueKey(_confirming),
              value: _value,
              error: _error != null,
              enabled: !_saving,
              onChanged: _onChanged,
            ),
            SizedBox(
              height: 32,
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        _error ?? '',
                        textAlign: TextAlign.center,
                        style: FontUtility.body.copyWith(
                          color: _danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
