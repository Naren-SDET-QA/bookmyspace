import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../courses/domain/course.dart';
import '../../domain/institute_profile.dart';
import '../institute_providers.dart';

class InstituteOwnerDashboardScreen extends ConsumerStatefulWidget {
  const InstituteOwnerDashboardScreen({super.key});

  @override
  ConsumerState<InstituteOwnerDashboardScreen> createState() =>
      _InstituteOwnerDashboardScreenState();
}

class _InstituteOwnerDashboardScreenState
    extends ConsumerState<InstituteOwnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = ref.watch(myInstituteProvider);
    final plans = ref.watch(instituteListingPlansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.instituteOwnerPortal)),
      floatingActionButton: mine.valueOrNull == null
          ? FloatingActionButton.extended(
              onPressed: _createInstitute,
              icon: const Icon(Icons.add),
              label: Text(l10n.createInstitute),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addClass(mine.valueOrNull!),
              icon: const Icon(Icons.class_),
              label: Text(l10n.addClass),
            ),
      body: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myInstituteProvider),
        ),
        data: (institute) {
          if (institute == null) {
            return EmptyState(
              icon: Icons.apartment_outlined,
              title: l10n.noInstituteProfile,
              message: l10n.createInstituteHint,
            );
          }
          final listing = ref.watch(
            activeInstituteListingProvider(institute.id),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(institute.name),
                  subtitle: Text(
                    institute.isVerified ? l10n.verified : l10n.unverified,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _createInstitute(existing: institute),
                  ),
                ),
              ),
              listing.when(
                data: (active) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: Text(
                      active == null || !active.isValid
                          ? l10n.noActiveAdvertisingPlan
                          : l10n.listingActiveUntil(
                              '${active.endsAt.toLocal()}',
                            ),
                    ),
                    subtitle: Text(l10n.plansPaymentHint),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Text(l10n.plans, style: Theme.of(context).textTheme.titleMedium),
              ...?plans.valueOrNull?.map(
                (plan) => ListTile(
                  title: Text(plan.name),
                  subtitle: Text(plan.description),
                  trailing: Text('₹${plan.price.toStringAsFixed(0)}'),
                ),
              ),
              const Divider(),
              Text(
                l10n.faculty,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...institute.faculty.map(
                (f) => ListTile(
                  title: Text(f.name),
                  subtitle: Text(f.specialization),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteFaculty(f.id),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addFaculty(institute.id),
                icon: const Icon(Icons.person_add),
                label: Text(l10n.addFaculty),
              ),
              const Divider(),
              Text(
                l10n.classes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...institute.courses.map(
                (c) => ListTile(
                  title: Text(c.title),
                  subtitle: Text(
                    [
                      c.status,
                      _modeLabel(l10n, c.mode),
                      if (c.isDemo) l10n.demoSession,
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _classAction(c, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'schedule',
                        child: Text('Schedule'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      PopupMenuItem(
                        value: c.status == 'published'
                            ? 'unpublish'
                            : 'publish',
                        child: Text(
                          c.status == 'published' ? 'Unpublish' : 'Publish',
                        ),
                      ),
                      PopupMenuItem(
                        value: c.status == 'paused' ? 'unpause' : 'pause',
                        child: Text(c.status == 'paused' ? 'Unpause' : 'Pause'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _modeLabel(AppLocalizations l10n, CourseMode mode) => switch (mode) {
    CourseMode.online => l10n.modeOnline,
    CourseMode.offline => l10n.modeOffline,
    CourseMode.hybrid => l10n.modeHybrid,
  };

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteFaculty(String id) async {
    if (!await _confirm(
      'Delete faculty?',
      'This faculty member will be removed.',
    ))
      return;
    try {
      await ref.read(instituteRepositoryProvider).deleteFaculty(id);
      ref.invalidate(myInstituteProvider);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _classAction(Course course, String action) async {
    if (action == 'delete' &&
        !await _confirm('Delete class?', 'This class will be removed.'))
      return;
    try {
      final repo = ref.read(instituteRepositoryProvider);
      if (action == 'delete') {
        await repo.deleteClass(course.id);
      } else if (action == 'schedule') {
        await _editSchedule(course);
        return;
      } else {
        final status = switch (action) {
          'pause' => 'paused',
          'unpause' => 'published',
          'publish' => 'published',
          'unpublish' => 'draft',
          _ => course.status,
        };
        await repo.updateClassStatus(course.id, status);
      }
      ref.invalidate(myInstituteProvider);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editSchedule(Course course) async {
    final controller = TextEditingController(text: course.scheduleNotes);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Schedule'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    if (save != true) return;
    await ref
        .read(instituteRepositoryProvider)
        .saveClass(
          instituteId: course.instituteId,
          courseId: course.id,
          draft: OwnerClassDraft(
            title: course.title,
            description: course.description,
            mode: course.mode.dbValue,
            durationWeeks: course.durationWeeks,
            feeAmount: course.feeAmount,
            instructorName: course.instructorName,
            isDemo: course.isDemo,
            status: course.status,
            seats: course.seats,
            scheduleNotes: controller.text.trim(),
          ),
        );
    ref.invalidate(myInstituteProvider);
  }

  Future<void> _createInstitute({InstituteProfile? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final city = TextEditingController(text: existing?.city ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(
            existing == null ? l10n.createInstitute : l10n.editInstitute,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                TextField(
                  controller: description,
                  decoration: InputDecoration(labelText: l10n.description),
                ),
                TextField(
                  controller: city,
                  decoration: InputDecoration(labelText: l10n.city),
                ),
                TextField(
                  controller: phone,
                  decoration: InputDecoration(labelText: l10n.phone),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await ref
        .read(instituteRepositoryProvider)
        .upsertMine(
          name: name.text.trim(),
          description: description.text.trim(),
          city: city.text.trim(),
          phone: phone.text.trim(),
        );
    ref.invalidate(myInstituteProvider);
    ref.invalidate(publishedInstitutesProvider);
  }

  Future<void> _addFaculty(String instituteId) async {
    final name = TextEditingController();
    final spec = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.addFaculty),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              TextField(
                controller: spec,
                decoration: InputDecoration(labelText: l10n.specialization),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await ref
        .read(instituteRepositoryProvider)
        .addFaculty(
          instituteId: instituteId,
          name: name.text.trim(),
          specialization: spec.text.trim(),
        );
    ref.invalidate(myInstituteProvider);
  }

  Future<void> _addClass(InstituteProfile institute) async {
    final title = TextEditingController();
    final fee = TextEditingController(text: '0');
    var demo = false;
    var mode = 'offline';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.addClass),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: l10n.classTitle),
                ),
                TextField(
                  controller: fee,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.fee),
                ),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  items: [
                    DropdownMenuItem(
                      value: 'offline',
                      child: Text(l10n.modeOffline),
                    ),
                    DropdownMenuItem(
                      value: 'online',
                      child: Text(l10n.modeOnline),
                    ),
                    DropdownMenuItem(
                      value: 'hybrid',
                      child: Text(l10n.modeHybrid),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => mode = v ?? 'offline'),
                  decoration: InputDecoration(labelText: l10n.deliveryMode),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.demoSession),
                  value: demo,
                  onChanged: (v) => setLocal(() => demo = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.saveDraft),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true || title.text.trim().isEmpty) return;
    await ref
        .read(instituteRepositoryProvider)
        .saveClass(
          instituteId: institute.id,
          draft: OwnerClassDraft(
            title: title.text.trim(),
            description: '',
            mode: mode,
            durationWeeks: 4,
            feeAmount: double.tryParse(fee.text) ?? 0,
            isDemo: demo,
            status: 'draft',
          ),
        );
    ref.invalidate(myInstituteProvider);
  }
}
