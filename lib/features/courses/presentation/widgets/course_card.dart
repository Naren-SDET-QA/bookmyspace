import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';

/// A tappable course card used in listings and the home screen.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasImage = course.coverImage.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.courseDetails.replaceAll(':id', course.id)),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: PrototypeVisuals.thumbGradientFor(course.id),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                    ),
                    if (hasImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: AppNetworkImage(
                          url: course.coverImage,
                          fit: BoxFit.cover,
                        ),
                      )
                      else
                      Center(
                        child: Text(
                          '🎓',
                          style: PrototypeVisuals.emojiStyle(fontSize: 40),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ModeChip(mode: course.mode, l10n: l10n),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PrototypeBadge.institute(),
                    const SizedBox(height: 6),
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.instituteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (course.instituteVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppTheme.brand,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.isFree
                          ? l10n.freeEvent
                          : '${l10n.courseFee} ${formatInr(course.feeAmount)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.l10n});

  final CourseMode mode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, emoji, label) = switch (mode) {
      CourseMode.online => (
        PrototypeVisuals.badgeClassBg,
        PrototypeVisuals.badgeClassFg,
        '🌐',
        l10n.modeOnline,
      ),
      CourseMode.offline => (
        PrototypeVisuals.availBg,
        const Color(0xFF15803D),
        '📍',
        l10n.modeOffline,
      ),
      CourseMode.hybrid => (
        PrototypeVisuals.badgeVenueBg,
        AppTheme.brand,
        '🔀',
        l10n.modeHybrid,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          color: fg,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
