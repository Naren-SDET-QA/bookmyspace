import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/institute_discovery_query.dart';
import '../../domain/institute_profile.dart';
import '../institute_providers.dart';

class InstitutesListScreen extends ConsumerStatefulWidget {
  const InstitutesListScreen({super.key});

  @override
  ConsumerState<InstitutesListScreen> createState() =>
      _InstitutesListScreenState();
}

class _InstitutesListScreenState extends ConsumerState<InstitutesListScreen> {
  final _query = TextEditingController();
  bool _verifiedOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final institutes = ref.watch(publishedInstitutesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.institutesAndClasses)),
      body: institutes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(publishedInstitutesProvider),
        ),
        data: (items) {
          final visible = InstituteDiscoveryQuery(
            query: _query.text,
            verifiedOnly: _verifiedOnly,
          ).apply(items);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _query,
                  decoration: InputDecoration(
                    hintText: l10n.searchInstitutes,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(l10n.verifiedOnly),
                    selected: _verifiedOnly,
                    onSelected: (value) =>
                        setState(() => _verifiedOnly = value),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: Icons.school_outlined,
                        title: l10n.noInstitutes,
                        message: l10n.noInstitutesMessage,
                      )
                    : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: l10n.noResults,
                        message: l10n.noResultsMessage,
                      )
                    : ResponsiveLayoutBuilder(
                        builder: (context, responsive) {
                          final columns = responsive.isCompact
                              ? 1
                              : responsive.isMedium
                              ? 2
                              : 3;
                          return GridView.builder(
                            padding: EdgeInsets.all(
                              responsive.horizontalPadding,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.4,
                                ),
                            itemCount: visible.length,
                            itemBuilder: (context, i) =>
                                _InstituteCard(item: visible[i]),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InstituteCard extends StatelessWidget {
  const _InstituteCard({required this.item});

  final InstituteProfile item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.instituteDetails.replaceFirst(':id', item.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.coverUrl.isEmpty
                  ? Container(
                      color: AppTheme.brand.withValues(alpha: 0.08),
                      child: const Icon(Icons.school_rounded, size: 40),
                    )
                  : AppNetworkImage(url: item.coverUrl, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isVerified)
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.green,
                        ),
                    ],
                  ),
                  Text(
                    [
                      item.city,
                      '${item.courses.length} classes',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
