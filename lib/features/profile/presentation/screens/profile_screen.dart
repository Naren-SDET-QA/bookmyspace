import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/auth_providers.dart';

/// Customer account hub matching the approved prototype's profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(appAccessRoleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 18),
          _MenuCard(
            children: [
              _MenuItem(
                icon: Icons.confirmation_number_outlined,
                label: 'My bookings',
                onTap: () => context.go(AppRoutes.bookings),
              ),
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'Favourites',
                onTap: () => context.go(AppRoutes.saved),
              ),
              _MenuItem(
                icon: Icons.payments_outlined,
                label: 'Payments & refunds',
                onTap: () => context.go(AppRoutes.bookings),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => context.push(AppRoutes.notifications),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (role == AppAccessRole.admin)
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin dashboard',
                  highlighted: true,
                  onTap: () => context.push(AppRoutes.adminDashboard),
                ),
              ],
            )
          else if (role == AppAccessRole.owner)
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Owner dashboard',
                  highlighted: true,
                  onTap: () => context.push(AppRoutes.ownerDashboard),
                ),
              ],
            )
          else
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.storefront_outlined,
                  label: 'Become an owner',
                  highlighted: true,
                  onTap: () => context.push(AppRoutes.ownerRegistration),
                ),
              ],
            ),
          if (role != null) const SizedBox(height: 14),
          _MenuCard(
            children: [
              _MenuItem(
                icon: Icons.support_agent_rounded,
                label: 'Help & support',
                onTap: () => context.push(AppRoutes.support),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings & legal',
                onTap: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'BookMySpace v1.0 · Made for India',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(authRepositoryProvider);
    final user =
        ref.watch(authStateProvider).asData?.value ?? repository.currentUser;
    final authenticated = user != null;
    final displayName = authenticated
        ? (user.fullName.trim().isNotEmpty ? user.fullName.trim() : user.email)
        : 'Guest User';
    final subtitle = authenticated
        ? user.email
        : 'Sign in to sync bookings and favourites';
    final initial = displayName.trim().isEmpty
        ? 'G'
        : displayName.trim()[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.brand,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        TextButton(
          onPressed: authenticated
              ? () async {
                  await repository.signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                }
              : () => context.push(AppRoutes.login),
          child: Text(authenticated ? 'Sign out' : 'Sign in'),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppTheme.brand
                  : AppTheme.brand.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: highlighted ? Colors.white : AppTheme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    ),
  );
}
