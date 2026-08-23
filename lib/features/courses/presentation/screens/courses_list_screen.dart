import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/course_discovery_query.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';

/// Published courses with local search and mode/offer filters.
class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final _query = TextEditingController();
  CourseModeFilter _mode = CourseModeFilter.all;
  CourseOfferFilter _offer = CourseOfferFilter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        data: (items) {
          final visible = CourseDiscoveryQuery(
            query: _query.text,
            mode: _mode,
            offer: _offer,
          ).apply(items);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _query,
                  decoration: InputDecoration(
                    hintText: l10n.searchCourses,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    for (final filter in CourseModeFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_modeLabel(filter, l10n)),
                          selected: _mode == filter,
                          onSelected: (_) => setState(() => _mode = filter),
                        ),
                      ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    for (final filter in CourseOfferFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_offerLabel(filter, l10n)),
                          selected: _offer == filter,
                          onSelected: (_) => setState(() => _offer = filter),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: Icons.school_rounded,
                        title: l10n.noCourses,
                        message: l10n.noCoursesMessage,
                      )
                    : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: l10n.noResults,
                        message: l10n.noResultsMessage,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(publishedCoursesProvider);
                          await ref.read(publishedCoursesProvider.future);
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CourseCard(course: visible[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _modeLabel(CourseModeFilter filter, AppLocalizations l10n) {
    return switch (filter) {
      CourseModeFilter.all => l10n.allModes,
      CourseModeFilter.online => l10n.modeOnline,
      CourseModeFilter.offline => l10n.modeOffline,
      CourseModeFilter.hybrid => l10n.modeHybrid,
    };
  }

  String _offerLabel(CourseOfferFilter filter, AppLocalizations l10n) {
    return switch (filter) {
      CourseOfferFilter.all => l10n.allModes,
      CourseOfferFilter.demo => l10n.demoSession,
      CourseOfferFilter.paid => l10n.paidCourse,
      CourseOfferFilter.free => l10n.freeEvent,
    };
  }
}
