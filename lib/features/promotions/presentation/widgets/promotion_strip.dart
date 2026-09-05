import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../promotion_providers.dart';
import 'promotion_preview.dart';

class PromotionStrip extends ConsumerWidget {
  const PromotionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(activePromotionsProvider);
    return promotions.when(
      loading: () => const SizedBox(height: 8),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 150,
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: items.length.clamp(0, 10),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final promotion = items[index];
              return SizedBox(
                width: index == 0 ? 320 : 220,
                child: PromotionPreview(promotion: promotion),
              );
            },
          ),
        );
      },
    );
  }
}
