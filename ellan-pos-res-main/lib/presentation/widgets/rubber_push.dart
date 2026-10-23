import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/pos_theme.dart';

/// Rounded field shape with no stroke. The shadow lives on [RubberPush].
class PosFields {
  PosFields._();

  static const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide.none,
  );
}

/// Raised surface that sinks slightly while pressed, like rubber.
class RubberPush extends StatefulWidget {
  const RubberPush({
    super.key,
    required this.child,
    this.radius = 14,
    this.trackFocus = true,
  });

  final Widget child;
  final double radius;
  final bool trackFocus;

  @override
  State<RubberPush> createState() => _RubberPushState();
}

class _RubberPushState extends State<RubberPush> {
  bool _down = false;
  bool _focused = false;
  Offset? _origin;

  @override
  void initState() {
    super.initState();
    if (widget.trackFocus) {
      FocusManager.instance.addListener(_syncFocus);
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFocus());
    }
  }

  @override
  void dispose() {
    if (widget.trackFocus) {
      FocusManager.instance.removeListener(_syncFocus);
    }
    super.dispose();
  }

  void _syncFocus() {
    if (!mounted) return;
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFocus());
      return;
    }
    final node = FocusManager.instance.primaryFocus;
    final focused =
        node?.context?.findAncestorStateOfType<_RubberPushState>() == this;
    if (focused != _focused) setState(() => _focused = focused);
  }

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  double get _amount {
    if (_down) return 1;
    if (widget.trackFocus && _focused) return 0.55;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _origin = event.position;
        _setDown(true);
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (origin != null && (event.position - origin).distance > 12) {
          _setDown(false);
        }
      },
      onPointerUp: (_) => _setDown(false),
      onPointerCancel: (_) => _setDown(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _amount),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
        builder: (context, t, child) {
          final lifted = PosTheme.lift();
          final pressed = PosTheme.pressed();
          // easeOutBack springs past 0 and 1. Shadow blur cannot follow that.
          final shadowT = t.clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, 3 * t),
            child: Transform.scale(
              scale: 1 - (0.012 * t),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  boxShadow: [
                    for (var i = 0; i < lifted.length; i++)
                      BoxShadow.lerp(lifted[i], pressed[i], shadowT)!,
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
