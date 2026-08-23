import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class HomePromoCard extends StatelessWidget {
  const HomePromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      margin: const EdgeInsets.only(top: 4, bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151A3D), Color(0xFF4C2A72), Color(0xFFB84B78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BOOK SMART',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Your space,\nready when you are.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white.withValues(alpha: 0.88),
            size: 56,
          ),
        ],
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class HomeRadarCard extends StatelessWidget {
  const HomeRadarCard({
    super.key,
    required this.locationLabel,
    required this.verifiedCount,
    required this.onTap,
  });

  final String locationLabel;
  final int verifiedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.radar_rounded, color: theme.colorScheme.primary),
                  Positioned(
                    right: 8,
                    top: 7,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Color(0xFF39D98A), shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('LIVE SPACE RADAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(width: 6),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF39D98A), shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('$verifiedCount verified spaces available', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class HomeSectionSkeleton extends StatelessWidget {
  const HomeSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 58);
}

class CategorySpotlightCard extends StatefulWidget {
  const CategorySpotlightCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  State<CategorySpotlightCard> createState() => _CategorySpotlightCardState();
}

class _CategorySpotlightCardState extends State<CategorySpotlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 0.16 + (_controller.value * 0.10);
        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 126,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: glow),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: theme.colorScheme.primaryContainer,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.76),
                          theme.colorScheme.primary.withValues(alpha: 0.52),
                          Colors.black.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'FEATURED IN THIS CATEGORY',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Discover ${widget.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Fresh spaces, real availability, simple booking.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
