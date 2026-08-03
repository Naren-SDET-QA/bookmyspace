import 'package:flutter/material.dart';

/// Ensures a child widget meets the minimum 44x44 touch target size
/// recommended by WCAG 2.1 / Material Design accessibility guidelines.
///
/// If the child is smaller than 44x44, transparent padding is added to
/// meet the minimum without visually changing the widget.
class MinTouchTarget extends StatelessWidget {
  const MinTouchTarget({
    super.key,
    required this.child,
    this.minSize = 44,
  });

  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: child,
    );
  }
}

/// A touch-target-aware [InkWell] that enforces a minimum 44x44 size.
class AccessibleInkWell extends StatelessWidget {
  const AccessibleInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticsLabel,
    this.borderRadius,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? semanticsLabel;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: MinTouchTarget(
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// A touch-target-aware [IconButton] wrapper that enforces minimum size.
class AccessibleIconButton extends StatelessWidget {
  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticsLabel,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        label: semanticsLabel,
        button: onPressed != null,
        child: MinTouchTarget(
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
