import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Formats amounts with the Indian rupee grouping (₹ symbol).
String formatInr(double amount) {
  final formatted = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  ).format(amount);
  return formatted;
}

/// Formats a distance in km for display ("1.2 km").
String formatDistance(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// A compact display of a venue's rating with a star icon.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.count});

  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Verified badge shown next to venue names.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified venue',
      child: Icon(
        Icons.verified_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// A favourite (heart) toggle button.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.isFavorite, this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
      ),
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
        color: isFavorite ? AppTheme.accent : Colors.white,
      ),
      tooltip: isFavorite ? 'Remove from saved' : 'Save venue',
    );
  }
}
