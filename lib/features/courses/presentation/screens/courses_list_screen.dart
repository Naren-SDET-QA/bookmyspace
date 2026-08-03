import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';

/// All published courses, newest first.
class CoursesListScreen extends ConsumerWidget {
  const CoursesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final courses = ref.watch(publishedCoursesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courses)),
      body: courses.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 220, radius: 16),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(publishedCoursesProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.school_rounded,
                title: l10n.noCourses,
                message: l10n.noCoursesMessage,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CourseCard(course: items[i]),
                ),
              ),
      ),
    );
  }
}
