import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// Wraps any tappable surface with a quick press-down scale, a button
/// semantics role and an optional tooltip-style label for screen readers.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.95,
    this.semanticLabel,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: AppDurations.press,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
