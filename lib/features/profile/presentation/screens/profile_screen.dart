import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/auth_providers.dart';

/// Customer account hub matching the approved prototype's profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(appAccessRoleProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 14),
          const _ProfileHeader(),
          const SizedBox(height: 14),
          const _EditProfileCard(),
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
            'BookMySpace v1.0 · Made for India 💜',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
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
        PrototypeAvatar(initial: initial),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
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
          child: Text(
            authenticated ? 'Sign out' : 'Sign in',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.brand,
            ),
          ),
        ),
      ],
    );
  }
}

/// Edit-profile affordance card (opens a sheet with name/phone fields).
class _EditProfileCard extends ConsumerStatefulWidget {
  const _EditProfileCard();

  @override
  ConsumerState<_EditProfileCard> createState() => _EditProfileCardState();
}

class _EditProfileCardState extends ConsumerState<_EditProfileCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    final user =
        ref.read(authStateProvider).asData?.value ??
        ref.read(authRepositoryProvider).currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() => _savedMessage = null);
    await showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.7,
      builder: (sheetContext) => AppBottomSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ),
                PrototypeIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Full name',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.muted,
                ),
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: AppTheme.brand,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Phone',
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: AppTheme.muted,
                ),
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: AppTheme.brand,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_savedMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _savedMessage!,
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrototypeButton(
              label: 'Save changes',
              onPressed: () {
                setState(() => _savedMessage = 'Profile updated ✓');
                Navigator.pop(sheetContext);
              },
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: PrototypeVisuals.softIconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: AppTheme.brand,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Edit profile',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFC6C2DE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: PrototypeVisuals.cardDecoration(),
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
    child: Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PrototypeVisuals.menuRowBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppTheme.brand
                  : PrototypeVisuals.softIconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 17,
              color: highlighted ? Colors.white : AppTheme.brand,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFFC6C2DE),
          ),
        ],
      ),
    ),
  );
}
