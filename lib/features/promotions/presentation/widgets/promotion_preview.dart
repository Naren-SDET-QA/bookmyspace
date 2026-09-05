import 'package:flutter/material.dart';

import '../../domain/promotion.dart';

class PromotionPreview extends StatelessWidget {
  const PromotionPreview({required this.promotion, this.bannerUrl, super.key});

  final Promotion promotion;
  final String? bannerUrl;

  static Color? color(String? value) {
    if (value == null || value.isEmpty) return null;
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return hex.length == 6 ? Color(0xFF000000 | parsed) : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final background =
        color(promotion.backgroundColor) ??
        Theme.of(context).colorScheme.primaryContainer;
    final foreground =
        color(promotion.textColor) ??
        Theme.of(context).colorScheme.onPrimaryContainer;
    return Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bannerUrl != null && bannerUrl!.isNotEmpty)
              Image.network(
                bannerUrl!,
                height: 58,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if ((promotion.badge ?? '').isNotEmpty)
              Text(
                promotion.badge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground),
              ),
            Text(
              promotion.title.isEmpty ? 'Promotion title' : promotion.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                promotion.shortDescription,
                style: TextStyle(color: foreground),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (promotion.ctaText.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: null,
                  child: Text(
                    promotion.ctaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
