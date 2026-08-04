import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/venue_import_models.dart';
import '../venue_import_providers.dart';

final pendingVenueClaimsProvider = FutureProvider<List<VenueClaim>>((ref) {
  return ref.watch(venueImportRepositoryProvider).listPendingClaims();
});

/// Admin inbox: review Claim This Venue requests.
class AdminVenueClaimsScreen extends ConsumerWidget {
  const AdminVenueClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(pendingVenueClaimsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Venue Claims'),
        backgroundColor: AppTheme.surfaceLight,
      ),
      body: claims.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(pendingVenueClaimsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No pending claims',
              message: 'New Claim This Venue requests will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final claim = items[i];
              final evidence = claim.evidence;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppTheme.line),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brand.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('🏠', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${evidence['business_name'] ?? 'Claim request'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                              Text(
                                'Venue ${claim.venueId.substring(0, 8)}… · claimant ${claim.claimantUserId.substring(0, 8)}…',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'pending',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '📞 ${evidence['contact_phone'] ?? '—'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (evidence['license_id'] != null)
                      Text(
                        '🪪 ${evidence['license_id']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    if (evidence['notes'] != null)
                      Text(
                        '${evidence['notes']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            await ref
                                .read(venueImportRepositoryProvider)
                                .reviewClaim(
                                  claimId: claim.id,
                                  approve: true,
                                );
                            ref.invalidate(pendingVenueClaimsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Claim approved — venue linked & owner-verified',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(venueImportRepositoryProvider)
                                .reviewClaim(
                                  claimId: claim.id,
                                  approve: false,
                                  notes: 'Rejected by admin',
                                );
                            ref.invalidate(pendingVenueClaimsProvider);
                          },
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
