import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Privacy policy screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Privacy Policy',
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
            '1. Information We Collect',
            'BookMySpace collects information you provide directly, including:\n'
                '• Account details (name, email, phone number)\n'
                '• Booking information (venues, dates, payment details)\n'
                '• Communication data (support tickets, reviews)\n'
                '• Device information (for analytics and crash reporting)',
          ),
          _buildSection(
            theme,
            '2. How We Use Your Information',
            'We use your information to:\n'
                '• Process bookings and payments\n'
                '• Send booking confirmations and notifications\n'
                '• Provide customer support\n'
                '• Improve our services and user experience\n'
                '• Ensure platform security and prevent fraud',
          ),
          _buildSection(
            theme,
            '3. Information Sharing',
            'We share your information with:\n'
                '• Venue owners (booking details only)\n'
                '• Payment processors (Razorpay) for transaction processing\n'
                '• Analytics providers (anonymized data)\n'
                '• Law enforcement when required by law',
          ),
          _buildSection(
            theme,
            '4. Data Security',
            'We implement industry-standard security measures including:\n'
                '• End-to-end encryption for data in transit\n'
                '• Encrypted storage for sensitive data\n'
                '• Regular security audits\n'
                '• Strict access controls for employees',
          ),
          _buildSection(
            theme,
            '5. Your Rights',
            'You have the right to:\n'
                '• Access your personal data\n'
                '• Correct inaccurate data\n'
                '• Delete your account and data\n'
                '• Opt out of non-essential data collection',
          ),
          _buildSection(
            theme,
            '6. Contact Us',
            'For privacy-related inquiries:\n'
                'Email: privacy@bookmyspace.com\n'
                'Address: BookMySpace Privacy Team, Hyderabad, India',
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
