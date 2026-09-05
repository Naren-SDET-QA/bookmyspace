import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_layout.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      _AdminTile(
        icon: Icons.fact_check_rounded,
        title: 'Listing approval',
        subtitle: 'Approve, reject, publish or unpublish listings',
        route: AppRoutes.adminListings,
      ),
      _AdminTile(
        icon: Icons.travel_explore_rounded,
        title: 'Venue discovery review',
        subtitle: 'Review OSM-discovered venues before they become drafts',
        route: AppRoutes.adminVenueDiscoveryReview,
      ),
      _AdminTile(
        icon: Icons.category_rounded,
        title: 'Category configuration',
        subtitle: 'Aliases, visibility, booking mode, media',
        route: AppRoutes.adminCategories,
      ),
      _AdminTile(
        icon: Icons.toggle_on_rounded,
        title: 'App sections',
        subtitle: 'Show or hide customer home sections',
        route: AppRoutes.adminAppSections,
      ),
      _AdminTile(
        icon: Icons.tune_rounded,
        title: 'Feature configuration',
        subtitle: 'Enable features and control app visibility',
        route: AppRoutes.adminFeatureConfiguration,
      ),
      _AdminTile(
        icon: Icons.local_offer_rounded,
        title: 'Promotions',
        subtitle: 'Create, edit, schedule and publish promotions',
        route: AppRoutes.adminPromotions,
      ),
      _AdminTile(
        icon: Icons.settings_suggest_rounded,
        title: 'Tenant configuration',
        subtitle: 'Branding, runtime features, language and notifications',
        route: AppRoutes.adminTenantConfiguration,
      ),
      _AdminTile(
        icon: Icons.receipt_long_rounded,
        title: 'Booking oversight',
        subtitle: 'Server booking records',
        route: AppRoutes.adminBookings,
      ),
      _AdminTile(
        icon: Icons.payments_rounded,
        title: 'Payment oversight',
        subtitle: 'Captured and failed payments',
        route: AppRoutes.adminPayments,
      ),
      _AdminTile(
        icon: Icons.healing_rounded,
        title: 'Payment & self-healing',
        subtitle: 'Live Razorpay health and stale pending reconcile',
        route: AppRoutes.adminPaymentHealth,
      ),
      _AdminTile(
        icon: Icons.monitor_heart_rounded,
        title: 'Observability',
        subtitle: 'Verified health, errors, alerts and recovery visibility',
        route: AppRoutes.adminObservability,
      ),
      _AdminTile(
        icon: Icons.hub_rounded,
        title: 'Observability providers',
        subtitle: 'Provider health and safe connection tests',
        route: AppRoutes.adminObservabilityProviders,
      ),
      _AdminTile(
        icon: Icons.settings_rounded,
        title: 'Platform settings',
        subtitle: 'Home UI, colors and module configuration',
        route: AppRoutes.adminSettings,
      ),
      _AdminTile(
        icon: Icons.help_center_rounded,
        title: 'Help Center',
        subtitle: 'Searchable configuration and troubleshooting help',
        route: AppRoutes.adminHelp,
      ),
      _AdminTile(
        icon: Icons.tune_rounded,
        title: 'Listing fields',
        subtitle: 'Required and optional fields per category',
        route: AppRoutes.adminListingFields,
      ),
      _AdminTile(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Registration fields',
        subtitle: 'Module registration form configuration',
        route: AppRoutes.adminRegistrationFields,
      ),
      _AdminTile(
        icon: Icons.replay_rounded,
        title: 'Refund oversight',
        subtitle: 'Refund requests and outcomes',
        route: AppRoutes.adminRefunds,
      ),
      _AdminTile(
        icon: Icons.history_rounded,
        title: 'Audit log',
        subtitle: 'Admin and system actions',
        route: AppRoutes.adminAudit,
      ),
      _AdminTile(
        icon: Icons.location_on_rounded,
        title: 'Location master',
        subtitle: 'Approve location submissions',
        route: AppRoutes.adminLocations,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: ResponsiveLayoutBuilder(
        builder: (context, responsive) {
          final columns = responsive.isCompact
              ? 1
              : responsive.isMedium
              ? 2
              : 3;
          return GridView.builder(
            padding: EdgeInsets.all(responsive.horizontalPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: responsive.isCompact ? 2.8 : 1.6,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: InkWell(
                  onTap: () => context.push(item.route),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.brand.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(item.icon, color: AppTheme.brand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminTile {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
