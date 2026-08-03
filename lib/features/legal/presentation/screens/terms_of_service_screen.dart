import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Terms of service screen.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsAndConditions)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Terms & Conditions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Last updated: August 3, 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            '1. Acceptance of Terms',
            'By using BookMySpace, you agree to these Terms & Conditions. '
                'If you do not agree, please do not use the app.',
          ),
          _buildSection(
            theme,
            '2. User Accounts',
            '• You must be at least 18 years old to create an account.\n'
                '• You are responsible for maintaining account security.\n'
                '• One account per person; duplicate accounts may be suspended.',
          ),
          _buildSection(
            theme,
            '3. Bookings & Payments',
            '• Bookings are subject to venue availability.\n'
                '• Payment is processed securely via Razorpay.\n'
                '• Cancellation policies are set by individual venues.\n'
                '• Refunds follow the venue\'s cancellation policy.',
          ),
          _buildSection(
            theme,
            '4. Venue Owner Responsibilities',
            '• Venue information must be accurate and up-to-date.\n'
                '• Owners must honor confirmed bookings.\n'
                '• Owners are responsible for venue safety and compliance.',
          ),
          _buildSection(
            theme,
            '5. Prohibited Activities',
            'Users may not:\n'
                '• Make false bookings or payments\n'
                '• Harass other users or venue staff\n'
                '• Attempt to circumvent booking or payment systems\n'
                '• Use the app for illegal purposes',
          ),
          _buildSection(
            theme,
            '6. Limitation of Liability',
            'BookMySpace acts as a platform connecting users and venue owners. '
                'We are not liable for the quality, safety, or legality of '
                'venues listed on the platform.',
          ),
          _buildSection(
            theme,
            '7. Changes to Terms',
            'We may update these terms at any material changes will be notified '
                'through the app.',
          ),
          _buildSection(
            theme,
            '8. Contact',
            'For questions about these terms:\n'
                'Email: legal@bookmyspace.com',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
