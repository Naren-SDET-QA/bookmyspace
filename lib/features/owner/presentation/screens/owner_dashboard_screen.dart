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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ownerDashboard.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
            const Text('Manage your business'),
          ],
        ),
        actions: [
          IconButton.outlined(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: owner.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentOwnerProvider),
        ),
        data: (ownerData) => ownerData == null
            ? EmptyState(
                icon: Icons.person_add_rounded,
                title: 'Not an owner',
                message: 'Register as an owner to access the dashboard.',
                action: FilledButton(
                  onPressed: () => context.push(AppRoutes.ownerRegistration),
                  child: const Text('Register as owner'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _OwnerCard(owner: ownerData),
                  const SizedBox(height: 18),
                  const _StatsGrid(),
                  const SizedBox(height: 22),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _QuickAction(
                        icon: Icons.storefront_rounded,
                        label: l10n.myVenues,
                        onTap: () => context.push(AppRoutes.ownerVenues),
                      ),
                      _QuickAction(
                        icon: Icons.add_business_rounded,
                        label: 'Add Hall',
                        onTap: () => context.push(AppRoutes.ownerVenueCreate),
                      ),
                      _QuickAction(
                        icon: Icons.meeting_room_rounded,
                        label: 'Meeting Rooms',
                        onTap: () => context.push(AppRoutes.ownerMeetingRooms),
                      ),
                      _QuickAction(
                        icon: Icons.hotel_rounded,
                        label: 'Rooms & Stays',
                        onTap: () => context.push(AppRoutes.ownerStays),
                      ),
                      _QuickAction(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Sports Venues',
                        onTap: () => context.push(AppRoutes.ownerSports),
                      ),
                      _QuickAction(
                        icon: Icons.dynamic_form_rounded,
                        label: 'Registration Forms',
                        onTap: () => context.push(AppRoutes.registrationForms),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Invoice Settings',
                        onTap: () => context.push(AppRoutes.invoiceConfig),
                      ),
                      _QuickAction(
                        icon: Icons.calendar_month_rounded,
                        label: 'Availability',
                        onTap: () => context.push(AppRoutes.ownerAvailability),
                      ),
                      _QuickAction(
                        icon: Icons.pending_actions_rounded,
                        label: 'Bookings',
                        onTap: () => context.push(AppRoutes.ownerBookings),
                      ),
                      _QuickAction(
                        icon: Icons.add_card_rounded,
                        label: 'Offline Booking',
                        onTap: () =>
                            context.push(AppRoutes.ownerOfflineBooking),
                      ),
                      _QuickAction(
                        icon: Icons.payments_rounded,
                        label: 'Payments',
                        onTap: () => context.push(AppRoutes.ownerPayments),
                      ),
                      _QuickAction(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Profile',
                        onTap: () => context.push(AppRoutes.ownerProfile),
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
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(ownerDashboardStatsProvider);
    return stats.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(ownerDashboardStatsProvider),
      ),
      data: (data) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          _StatCard(
            label: 'Revenue · this month',
            value: _formatInr(data.monthlyRevenue),
          ),
          _StatCard(
            label: 'Bookings',
            value: '${data.totalBookings}',
          ),
          _StatCard(
            label: 'Pending approval',
            value: '${data.pendingApprovals}',
          ),
          _StatCard(
            label: 'Today',
            value: '${data.todayBookings}',
          ),
        ],
      ),
    );
  }

  static String _formatInr(double amount) {
    if (amount <= 0) return '₹0';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.brand,
            ),
          ),
        ],
      ),
    ),
  );
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
              child: const Icon(Icons.person_rounded, color: AppTheme.brand),
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
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppTheme.brand),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
