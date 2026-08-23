import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../venues/domain/category_configuration.dart';

class UnifiedRegistrationModule {
  const UnifiedRegistrationModule({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Returns the stable public modules plus enabled database categories.
  /// Category slugs remain data, not Dart enum values.
  static List<UnifiedRegistrationModule> resolve(
    List<CategoryConfiguration> categories,
  ) {
    final result = <UnifiedRegistrationModule>[...unifiedRegistrationModules];
    for (final category in categories) {
      if (!category.registrationRequired ||
          result.any((module) => module.key == category.slug)) {
        continue;
      }
      result.add(
        UnifiedRegistrationModule(
          key: category.slug,
          title: '${category.name} registration',
          subtitle: category.kycRequired
              ? 'Registration and verification required'
              : 'Registration details for ${category.name}',
          icon: Icons.assignment_outlined,
        ),
      );
    }
    return result;
  }
}

const unifiedRegistrationModules = [
  UnifiedRegistrationModule(
    key: 'customer',
    title: 'Customer / member',
    subtitle: 'Search, book, pay, and manage stays',
    icon: Icons.person_outline,
  ),
  UnifiedRegistrationModule(
    key: 'venue_owner',
    title: 'Venue & space owner',
    subtitle: 'List halls, stays, PG, and spaces',
    icon: Icons.storefront_outlined,
  ),
  UnifiedRegistrationModule(
    key: 'institute_student',
    title: 'Institute student / coach',
    subtitle: 'Academies, classes, and demo sessions',
    icon: Icons.school_outlined,
  ),
  UnifiedRegistrationModule(
    key: 'event_attendee',
    title: 'Event / tournament attendee',
    subtitle: 'Workshops, events, and courses',
    icon: Icons.event_outlined,
  ),
];

/// Zip Android `UnifiedRegistrationScreen` mapped onto the existing
/// module-registration framework (database forms, not hardcoded KYC).
class UnifiedRegistrationScreen extends StatelessWidget {
  const UnifiedRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.unifiedRegistration)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.unifiedRegistrationHint),
          const SizedBox(height: 16),
          ...unifiedRegistrationModules.map(
            (module) => Card(
              child: ListTile(
                leading: Icon(module.icon),
                title: Text(module.title),
                subtitle: Text(module.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // `venue_owner` is an application role, not a listing/category
                  // module. Route it to the dedicated OTP owner registration
                  // flow instead of the generic module-registration screen.
                  if (module.key == 'venue_owner') {
                    context.push(AppRoutes.ownerRegistration);
                    return;
                  }
                  context.push(
                    AppRoutes.moduleRegistration.replaceFirst(
                      ':module',
                      module.key,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
