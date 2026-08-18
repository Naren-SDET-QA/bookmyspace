import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../auth_providers.dart';
import '../widgets/edit_profile_modal.dart';

/// Full-featured Profile Screen with instant Edit Profile modal support,
/// account status, and Supabase profile synchronization.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.navProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.horizontalPadding,
                vertical: 16,
              ),
              children: [
                // Profile Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primaryContainer,
                                    border: Border.all(
                                      color: AppTheme.brand,
                                      width: 2.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: user?.avatarUrl.isNotEmpty == true
                                      ? AppNetworkImage(
                                          url: user!.avatarUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            user?.fullName.isNotEmpty == true
                                                ? user!.fullName[0].toUpperCase()
                                                : user?.email.isNotEmpty == true
                                                    ? user!.email[0].toUpperCase()
                                                    : 'U',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => EditProfileModal.show(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.brand,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user?.fullName.isNotEmpty == true
                                              ? user!.fullName
                                              : 'Guest User',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              size: 12,
                                              color: Colors.green.shade800,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email.isNotEmpty == true
                                        ? user!.email
                                        : 'Signed in via Supabase',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (user?.phone.isNotEmpty == true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      user!.phone,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Edit Profile Button (Triggers EditProfileModal)
                        FilledButton.tonalIcon(
                          onPressed: () => EditProfileModal.show(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text(
                            'Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Activity Metrics
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'My Bookings',
                        count: '3 Active',
                        color: Colors.blue,
                        onTap: () => context.push(AppRoutes.bookings),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.favorite_rounded,
                        title: 'Saved Spaces',
                        count: '8 Saved',
                        color: Colors.pink,
                        onTap: () => context.push(AppRoutes.saved),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Wallet',
                        count: '₹2,500',
                        color: Colors.amber.shade800,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Menu Options
                Text(
                  'Account Settings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                _ProfileMenuTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Edit Profile & Avatar',
                  subtitle: 'Update your display name and photo in Supabase',
                  onTap: () => EditProfileModal.show(context),
                ),
                _ProfileMenuTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications & Alerts',
                  subtitle: 'Booking updates, reminders, and offers',
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                _ProfileMenuTile(
                  icon: Icons.tune_rounded,
                  title: 'App Preferences',
                  subtitle: 'Theme, language, and display options',
                  onTap: () => context.push(AppRoutes.settings),
                ),
                _ProfileMenuTile(
                  icon: Icons.storefront_outlined,
                  title: 'Partner / Venue Owner Hub',
                  subtitle: 'List your spaces, halls, and classes',
                  onTap: () => context.push(AppRoutes.ownerDashboard),
                ),
                _ProfileMenuTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'Support & Help Desk',
                  subtitle: 'Get quick assistance with bookings',
                  onTap: () => context.push(AppRoutes.support),
                ),
                const SizedBox(height: 16),

                // Sign out button
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                count,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}
