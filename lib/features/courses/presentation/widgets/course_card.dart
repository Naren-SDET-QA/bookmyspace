import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
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

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.courseDetails.replaceAll(':id', course.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: course.coverImage, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Pill(
                      text: _modeLabel(l10n, course.mode),
                      background: AppTheme.brand,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _modeLabel(AppLocalizations l10n, CourseMode mode) =>
      switch (mode) {
        CourseMode.online => l10n.modeOnline,
        CourseMode.offline => l10n.modeOffline,
        CourseMode.hybrid => l10n.modeHybrid,
      };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.background});

  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
