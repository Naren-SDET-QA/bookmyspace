import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../infrastructure/supabase_admin_repository.dart';

enum AdminModule {
  users('Users', ['profiles']),
  owners('Owners', ['owner_profiles']),
  organizations('Organizations', ['organizations']),
  listings('Listings / Approvals', ['venues', 'accommodation_properties']),
  bookings('Bookings', ['bookings', 'stay_bookings']),
  payments('Payments / Refunds', ['payments', 'refunds']),
  reports('Reports', ['platform_commissions']),
  settings('Settings', ['platform_settings']);

  const AdminModule(this.label, this.tables);
  final String label;
  final List<String> tables;
}

final adminRepositoryProvider = Provider<SupabaseAdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseProvider)),
);

final adminModuleRowsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, AdminModule>(
      (ref, module) => ref.watch(adminRepositoryProvider).rows(module.tables),
    );

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Platform Administration')),
    body: GridView(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 120,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      children: [
        for (final module in AdminModule.values)
          _AdminTile(
            label: module.label,
            onTap: () => context.push('/admin/${module.name}'),
          ),
        _AdminTile(
          label: 'Audit Logs',
          onTap: () => context.push(AppRoutes.adminAudit),
        ),
        _AdminTile(
          label: 'Venue Import',
          onTap: () => context.push(AppRoutes.adminVenueImport),
        ),
        _AdminTile(
          label: 'Venue Claims',
          onTap: () => context.push(AppRoutes.adminVenueClaims),
        ),
        _AdminTile(
          label: 'Content & Pricing',
          onTap: () => context.push(AppRoutes.adminContent),
        ),
      ],
    ),
  );
}

class AdminModuleScreen extends ConsumerWidget {
  const AdminModuleScreen({required this.module, super.key});

  final AdminModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(adminModuleRowsProvider(module));
    return Scaffold(
      appBar: AppBar(title: Text(module.label)),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminModuleRowsProvider(module)),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No ${module.label.toLowerCase()}',
                message: 'No records are currently available.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => Card(
                  child: ListTile(
                    title: Text(_title(items[index])),
                    subtitle: Text(_summary(items[index])),
                  ),
                ),
              ),
      ),
    );
  }

  String _title(Map<String, dynamic> row) =>
      '${row['full_name'] ?? row['name'] ?? row['booking_ref'] ?? row['key'] ?? row['id']}';

  String _summary(Map<String, dynamic> row) {
    const keys = ['_source', 'email', 'status', 'org_type', 'amount', 'value'];
    return keys
        .where((key) => row[key] != null)
        .map((key) => '$key: ${row[key]}')
        .join(' · ');
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static String _emojiFor(String label) {
    return switch (label) {
      'Users' => '👥',
      'Owners' => '🏠',
      'Organizations' => '🏢',
      'Listings / Approvals' => '📋',
      'Bookings' => '📅',
      'Payments / Refunds' => '💳',
      'Reports' => '📊',
      'Settings' => '⚙️',
      'Audit Logs' => '🧾',
      'Venue Import' => '📥',
      'Venue Claims' => '🏠',
      'Content & Pricing' => '✏️',
      _ => '📌',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          decoration: BoxDecoration(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_emojiFor(label), style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
