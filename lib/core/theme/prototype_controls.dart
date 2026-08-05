import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'prototype_visuals.dart';

/// Prototype `.btn` — gradient primary CTA with brand shadow.
///
/// Mirrors `background: var(--grad); border-radius: 15px; box-shadow: 0 8px
/// 20px rgba(108,61,244,.3)`. Disabled renders the muted `.btn:disabled` look.
class PrototypeButton extends StatelessWidget {
  const PrototypeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.small = false,
    this.expanded = false,
    this.ghost = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool small;
  final bool expanded;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Material(
      color: ghost
          ? AppTheme.card
          : (enabled ? Colors.transparent : const Color(0xFFD5D1E6)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(small ? 11 : 15),
        side: ghost
            ? const BorderSide(color: AppTheme.line)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ghost
            ? null
            : BoxDecoration(
                gradient: enabled ? AppTheme.brandGradient : null,
                color: enabled ? null : const Color(0xFFD5D1E6),
              ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: small ? 40 : 50,
            width: fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: expanded || fullWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: small ? 16 : 19,
                    color: ghost ? AppTheme.ink : Colors.white,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w800,
                      color: ghost ? AppTheme.ink : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (enabled && !ghost) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(small ? 11 : 15),
          boxShadow: [PrototypeVisuals.ctaShadow],
        ),
        child: button,
      );
    }
    return button;
  }
}

/// Prototype `.secHead` — 16.5/800 title with a brand "See all" action.
class PrototypeSectionHeader extends StatelessWidget {
  const PrototypeSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'See all',
    this.padding = const EdgeInsets.only(top: 24, bottom: 0),
  });

  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                letterSpacing: -0.3,
                color: AppTheme.ink,
                fontFamilyFallback: AppTheme.emojiFontFallbacks,
              ),
            ),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  viewAllLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Prototype `.steps` — segmented progress track for multi-step sheets/flows.
class PrototypeSteps extends StatelessWidget {
  const PrototypeSteps({super.key, required this.current, this.total = 4});

  /// 1-based current step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final on = i < current;
        return Expanded(
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: on ? AppTheme.brand : PrototypeVisuals.stepsTrack,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

/// Prototype `.statB` — white stat tile used on venue details.
class PrototypeStatBox extends StatelessWidget {
  const PrototypeStatBox({
    super.key,
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: PrototypeVisuals.cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype `.pillW` — frosted white pill used on hero overlays.
class PrototypePill extends StatelessWidget {
  const PrototypePill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: PrototypeVisuals.star),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype `.avatar` — 60×60 gradient rounded square with an initial.
class PrototypeAvatar extends StatelessWidget {
  const PrototypeAvatar({super.key, required this.initial, this.size = 60});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.33),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
