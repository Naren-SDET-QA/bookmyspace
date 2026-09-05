import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../courses/domain/course.dart';
import '../institute_providers.dart';

class InstituteDetailScreen extends ConsumerWidget {
  const InstituteDetailScreen({super.key, required this.instituteId});

  final String instituteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(instituteDetailProvider(instituteId));
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(instituteDetailProvider(instituteId)),
        ),
        data: (institute) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(institute.name),
                background: institute.coverUrl.isEmpty
                    ? Container(color: AppTheme.brand)
                    : AppNetworkImage(
                        url: institute.coverUrl,
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
                    if (institute.isVerified)
                      Chip(
                        avatar: const Icon(Icons.verified, size: 16),
                        label: Text(l10n.verifiedInstitute),
                      ),
                    const SizedBox(height: 8),
                    Text(institute.description),
                    if (institute.address.isNotEmpty ||
                        institute.city.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          institute.address,
                          institute.city,
                          institute.state,
                        ].where((s) => s.isNotEmpty).join(', '),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (institute.phone.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () =>
                                launchUrl(Uri.parse('tel:${institute.phone}')),
                            icon: const Icon(Icons.call),
                            label: Text(l10n.call),
                          ),
                        if (institute.whatsapp.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://wa.me/${institute.whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
                              ),
                            ),
                            icon: const Icon(Icons.chat),
                            label: Text(l10n.whatsapp),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.gallery,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 88,
                      child: institute.media.isEmpty
                          ? Text(l10n.noGalleryYet)
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: institute.media.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final media = institute.media[i];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 120,
                                    child: media.url.isEmpty
                                        ? const ColoredBox(
                                            color: Colors.black12,
                                          )
                                        : AppNetworkImage(
                                            url: media.url,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.faculty,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (institute.faculty.isEmpty)
                      Text(l10n.facultyPlaceholder),
                    ...institute.faculty.map(
                      (f) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            f.name.isEmpty ? '?' : f.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(f.name),
                        subtitle: Text(
                          [
                            f.specialization,
                            f.qualification,
                            if (f.experienceYears > 0)
                              '${f.experienceYears} yrs',
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.classesAndCourses,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (institute.courses.isEmpty)
                      Text(l10n.noPublishedClasses),
                    ...institute.courses.map(
                      (course) => Card(
                        child: ListTile(
                          title: Text(course.title),
                          subtitle: Text(
                            [
                              _modeLabel(l10n, course.mode),
                              if (course.isDemo) l10n.demoSession,
                              '₹${course.feeAmount.toStringAsFixed(0)}',
                              if (course.seats != null) '${course.seats} seats',
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            AppRoutes.courseDetails.replaceFirst(
                              ':id',
                              course.id,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
