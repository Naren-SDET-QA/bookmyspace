import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
import '../course_providers.dart';

/// Course details with its batches and per-batch enroll/drop actions.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
        ),
        data: (course) => _CourseBody(course: course),
      ),
    );
  }
}

class _CourseBody extends ConsumerWidget {
  const _CourseBody({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          flexibleSpace: FlexibleSpaceBar(
            background: AppNetworkImage(
              url: course.coverImage,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (course.instituteVerified)
                      const Icon(Icons.verified_rounded, color: AppTheme.brand),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  course.instituteName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _DetailChip(
                      icon: Icons.school_rounded,
                      label: _modeLabel(l10n, course.mode),
                    ),
                    _DetailChip(
                      icon: Icons.calendar_month_rounded,
                      label: l10n.durationWeeks.replaceAll(
                        '{weeks}',
                        '${course.durationWeeks}',
                      ),
                    ),
                    if (course.instructorName.isNotEmpty)
                      _DetailChip(
                        icon: Icons.person_rounded,
                        label: '${l10n.instructor}: ${course.instructorName}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _FeeCard(course: course),
                const SizedBox(height: 20),
                if (course.description.isNotEmpty) ...[
                  Text(l10n.details, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    course.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(l10n.enrollInCourse, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                if (course.batches.isEmpty)
                  Text(
                    l10n.noCourses,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...course.batches.map(
                    (b) => _BatchTile(courseId: course.id, batch: b),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _modeLabel(AppLocalizations l10n, CourseMode mode) =>
      switch (mode) {
        CourseMode.online => l10n.modeOnline,
        CourseMode.offline => l10n.modeOffline,
        CourseMode.hybrid => l10n.modeHybrid,
      };
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppTheme.brand),
      label: Text(label),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      color: AppTheme.brand.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.courseFee,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              course.isFree ? l10n.freeEvent : formatInr(course.feeAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchTile extends ConsumerStatefulWidget {
  const _BatchTile({required this.courseId, required this.batch});

  final String courseId;
  final CourseBatch batch;

  @override
  ConsumerState<_BatchTile> createState() => _BatchTileState();
}

class _BatchTileState extends ConsumerState<_BatchTile> {
  bool _busy = false;

  CourseBatch get batch => widget.batch;

  Future<void> _enroll() async {
    setState(() => _busy = true);
    try {
      await ref.read(enrollInCourseProvider(batch.id).future);
      ref.invalidate(courseDetailProvider(widget.courseId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDrop() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dropEnrollment),
        content: Text(l10n.dropEnrollmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(dropCourseProvider(batch.id).future);
      ref.invalidate(courseDetailProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enrollmentDropped)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          batch.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (batch.userEnrolled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n.enrolled,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.batchStartsOn} ${DateFormat.yMMMd().format(batch.startsOn)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    batch.seatsLeft > 0
                        ? l10n.seatsLeft.replaceAll(
                            '{count}',
                            '${batch.seatsLeft}',
                          )
                        : l10n.soldOut,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: batch.seatsLeft > 0
                          ? AppTheme.brand
                          : AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            batch.userEnrolled
                ? OutlinedButton(
                    onPressed: _busy ? null : _confirmDrop,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(_busy ? l10n.loading : l10n.dropEnrollment),
                  )
                : FilledButton(
                    onPressed: _busy || batch.isFull ? null : _enroll,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n.enrollNow),
                  ),
          ],
        ),
      ),
    );
  }
}
