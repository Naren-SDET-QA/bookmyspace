import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/owner.dart';
import '../owner_providers.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(currentOwnerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ownerDashboard)),
      body: owner.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentOwnerProvider),
        ),
        data: (ownerData) => ownerData == null
            ? const EmptyState(
                icon: Icons.person_add_rounded,
                title: 'Not an owner',
                message: 'Register as an owner to access the dashboard.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _OwnerCard(owner: ownerData),
                  const SizedBox(height: 24),
                  _QuickAction(
                    icon: Icons.storefront_rounded,
                    label: l10n.myVenues,
                    onTap: () => context.push(AppRoutes.ownerVenues),
                  ),
                  _QuickAction(
                    icon: Icons.notifications_rounded,
                    label: l10n.notifications,
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                  _QuickAction(
                    icon: Icons.analytics_rounded,
                    label: l10n.analytics,
                    onTap: () => context.push(AppRoutes.analytics),
                  ),
                  _QuickAction(
                    icon: Icons.headset_mic_rounded,
                    label: l10n.support,
                    onTap: () => context.push(AppRoutes.support),
                  ),
                  _QuickAction(
                    icon: Icons.history_rounded,
                    label: l10n.auditLog,
                    onTap: () => context.push(AppRoutes.adminAudit),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner});

  final Owner owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
              child:               const Icon(Icons.person_rounded, color: AppTheme.brand),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    owner.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppTheme.brand),
              const SizedBox(width: 16),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}