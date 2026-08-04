import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/venue_claim_service.dart';
import 'venue_import_providers.dart';

/// Owner "Claim This Venue" sheet — evidence → submit for admin review.
Future<void> showClaimVenueSheet(
  BuildContext context,
  WidgetRef ref, {
  required String venueId,
  required String venueName,
  required bool isClaimable,
  required bool ownerVerified,
}) async {
  if (!isClaimable || ownerVerified) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ownerVerified
              ? 'This venue is already owner-verified.'
              : 'This venue is not available to claim.',
        ),
      ),
    );
    return;
  }

  final session = ref.read(authStateProvider).valueOrNull;
  if (session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in as an owner to claim this venue.')),
    );
    return;
  }

  final businessCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  const claimService = VenueClaimService();

  await showAppBottomSheet<void>(
    context: context,
    maxHeightFactor: 0.85,
    backgroundColor: AppTheme.surfaceLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var submitting = false;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AppBottomSheetScrollBody(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              8,
              AppTheme.pagePadding,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('🏠', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claim This Venue',
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          Text(
                            venueName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verify ownership with business details. An admin will review before linking the listing to you.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business / legal name *',
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone *',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'License / GST (optional)',
                  ),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          try {
                            final evidence = claimService.validateEvidence(
                              businessName: businessCtrl.text,
                              contactPhone: phoneCtrl.text,
                              licenseId: licenseCtrl.text,
                              notes: notesCtrl.text,
                            );
                            claimService.assertClaimable(
                              isClaimable: isClaimable,
                              ownerVerified: ownerVerified,
                              hasPendingOtherClaim: false,
                            );
                            setState(() => submitting = true);
                            await ref
                                .read(venueImportRepositoryProvider)
                                .submitClaim(
                                  venueId: venueId,
                                  evidence: evidence.toJson(),
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Claim submitted — awaiting admin review',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => submitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit claim'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  businessCtrl.dispose();
  phoneCtrl.dispose();
  licenseCtrl.dispose();
  notesCtrl.dispose();
}
