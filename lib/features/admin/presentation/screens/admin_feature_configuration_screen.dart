import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/domain/auth_configuration.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/feature_registry.dart';
import '../../../promotions/infrastructure/supabase_admin_promotion_repository.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../domain/admin_feature_configuration.dart';

class AdminFeatureConfigurationScreen extends ConsumerWidget {
  const AdminFeatureConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(featureRegistryProvider);
    final categories =
        ref.watch(categoryConfigurationsProvider).valueOrNull ??
        const <CategoryConfiguration>[];
    final grouped = AdminFeatureConfiguration.grouped(
      registry,
      categories: categories,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature configuration'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategory(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _AuthConfigurationPanel(),
            const SizedBox(height: 12),
            for (final group in AdminConfigGroup.values) ...[
              Card(
                child: ExpansionTile(
                  title: Text(group.label),
                  subtitle: Text('${grouped[group]?.length ?? 0} settings'),
                  children: [
                    for (final item
                        in grouped[group] ??
                            const <AdminFeatureConfiguration>[])
                      _FeatureSettingsTile(item: item, registry: registry),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthConfigurationPanel extends ConsumerWidget {
  const _AuthConfigurationPanel();

  static const _flags = <String, String>{
    'authentication_enabled': 'Authentication',
    'signup_enabled': 'Signup',
    'phone_login_enabled': 'Mobile login',
    'phone_otp_enabled': 'Mobile OTP',
    'email_login_enabled': 'Email login',
    'email_otp_enabled': 'Email OTP',
    'password_login_enabled': 'Email password',
    'google_login_enabled': 'Google login',
    'apple_login_enabled': 'Apple login',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authConfigurationProvider);
    return Card(
      child: ExpansionTile(
        title: const Text('Authentication'),
        subtitle: const Text('Provider availability and sign-up controls'),
        children: [
          state.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const ListTile(
              title: Text('Authentication configuration unavailable'),
            ),
            data: (config) => Column(
              children: [
                for (final entry in _flags.entries)
                  SwitchListTile.adaptive(
                    title: Text(entry.value),
                    value: _value(config, entry.key),
                    onChanged:
                        config.authenticationEnabled ||
                            entry.key == 'authentication_enabled'
                        ? (value) async {
                            await ref
                                .read(authConfigurationRepositoryProvider)
                                .update({entry.key: value});
                            ref.invalidate(authConfigurationProvider);
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _value(AuthConfiguration c, String key) => switch (key) {
    'authentication_enabled' => c.authenticationEnabled,
    'signup_enabled' => c.signupEnabled,
    'phone_login_enabled' => c.phoneLoginEnabled,
    'phone_otp_enabled' => c.phoneOtpEnabled,
    'email_login_enabled' => c.emailLoginEnabled,
    'email_otp_enabled' => c.emailOtpEnabled,
    'password_login_enabled' => c.passwordLoginEnabled,
    'google_login_enabled' => c.googleLoginEnabled,
    'apple_login_enabled' => c.appleLoginEnabled,
    _ => false,
  };
}

Future<void> _showAddCategory(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final code = TextEditingController();
  final icon = TextEditingController();
  var active = true;
  var searchable = true;
  var bookable = true;
  var availability = true;
  var offers = true;
  var payments = true;
  var location = true;
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Category code'),
              ),
              TextField(
                controller: icon,
                decoration: const InputDecoration(labelText: 'Icon or image'),
              ),
              for (final item
                  in <({String label, bool value, void Function(bool) set})>[
                    (
                      label: 'Active',
                      value: active,
                      set: (v) => setState(() => active = v),
                    ),
                    (
                      label: 'Search',
                      value: searchable,
                      set: (v) => setState(() => searchable = v),
                    ),
                    (
                      label: 'Booking',
                      value: bookable,
                      set: (v) => setState(() => bookable = v),
                    ),
                    (
                      label: 'Availability',
                      value: availability,
                      set: (v) => setState(() => availability = v),
                    ),
                    (
                      label: 'Offers',
                      value: offers,
                      set: (v) => setState(() => offers = v),
                    ),
                    (
                      label: 'Payments',
                      value: payments,
                      set: (v) => setState(() => payments = v),
                    ),
                    (
                      label: 'Location',
                      value: location,
                      set: (v) => setState(() => location = v),
                    ),
                  ])
                SwitchListTile.adaptive(
                  title: Text(item.label),
                  value: item.value,
                  onChanged: item.set,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (created != true || name.text.trim().isEmpty || code.text.trim().isEmpty)
    return;
  try {
    await ref
        .read(categoryConfigurationRepositoryProvider)
        .createCategory(
          slug: code.text.trim(),
          name: name.text.trim(),
          icon: icon.text.trim(),
          metadata: {
            'active': active,
            'searchable': searchable,
            'bookable': bookable,
            'availability_enabled': availability,
            'offers_enabled': offers,
            'payments_enabled': payments,
            'location_enabled': location,
          },
        );
    ref.invalidate(categoryConfigurationsProvider);
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category saved')));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category could not be saved')),
      );
  }
}

class _FeatureSettingsTile extends ConsumerWidget {
  const _FeatureSettingsTile({required this.item, required this.registry});

  final AdminFeatureConfiguration item;
  final FeatureRegistry registry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = item.group;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        elevation: 0,
        child: ExpansionTile(
          title: Text(item.displayName),
          subtitle: Text(item.description),
          trailing: Switch.adaptive(
            value: item.enabled,
            onChanged: (value) => _save(ref, enabled: value),
          ),
          children: [
            SwitchListTile.adaptive(
              title: const Text('Show on home'),
              value: item.homeVisible,
              onChanged: (value) => _save(ref, homeVisible: value),
            ),
            SwitchListTile.adaptive(
              title: const Text('Show in search'),
              value: item.searchVisible,
              onChanged: (value) => _save(ref, searchVisible: value),
            ),
            SwitchListTile.adaptive(
              title: const Text('Show in navigation'),
              value: item.navigationVisible,
              onChanged: (value) => _save(ref, navigationVisible: value),
            ),
            if (group == AdminConfigGroup.categories ||
                group == AdminConfigGroup.booking)
              SwitchListTile.adaptive(
                title: Text(
                  group == AdminConfigGroup.categories
                      ? 'Bookable'
                      : 'Booking enabled',
                ),
                value: item.bookingEnabled,
                onChanged: (value) => _save(ref, bookingEnabled: value),
              ),
            if (group == AdminConfigGroup.categories ||
                group == AdminConfigGroup.offers)
              SwitchListTile.adaptive(
                title: const Text('Show offers'),
                value: item.offerVisible,
                onChanged: (value) => _save(ref, offerVisible: value),
              ),
            if (group == AdminConfigGroup.categories) ...[
              SwitchListTile.adaptive(
                title: const Text('Availability'),
                value: item.availabilityEnabled,
                onChanged: (value) => _save(ref, availabilityEnabled: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Payments'),
                value: item.paymentsEnabled,
                onChanged: (value) => _save(ref, paymentsEnabled: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Location'),
                value: item.locationEnabled,
                onChanged: (value) => _save(ref, locationEnabled: value),
              ),
            ],
            if (group == AdminConfigGroup.offers) ...[
              for (final flag in const [
                ('promotions_enabled', 'Promotions'),
                ('banners_enabled', 'Banners'),
                ('offers_enabled', 'Offers'),
                ('discounts_enabled', 'Discounts'),
                ('promotion_media_enabled', 'Promotion media'),
                ('category_targeting_enabled', 'Category targeting'),
                ('venue_targeting_enabled', 'Venue targeting'),
                ('scheduling_enabled', 'Scheduling'),
                ('cta_enabled', 'CTA buttons'),
              ])
                SwitchListTile.adaptive(
                  title: Text(flag.$2),
                  value:
                      item.registry.configOf(item.id!).config[flag.$1]
                          as bool? ??
                      true,
                  onChanged: (value) {
                    final current = item.registry.configOf(item.id!).config;
                    item.registry.apply(
                      item.id!,
                      config: {...current, flag.$1: value},
                    );
                    ref.invalidate(featureRegistryProvider);
                    unawaited(
                      SupabaseAdminPromotionRepository(
                        ref.read(supabaseProvider),
                      ).saveGlobalFlag(flag.$1, value),
                    );
                  },
                ),
            ],
            _textField(
              label: 'Display name',
              value: item.displayName,
              onSubmitted: (value) => _save(ref, displayName: value),
            ),
            _textField(
              label: 'Description',
              value: item.description,
              onSubmitted: (value) => _save(ref, description: value),
            ),
            _textField(
              label: 'Icon',
              value: item.icon,
              onSubmitted: (value) => _save(ref, icon: value),
            ),
            _textField(
              label: 'Image URL',
              value: item.image,
              onSubmitted: (value) => _save(ref, image: value),
            ),
            _textField(
              label: 'Accent color (#RRGGBB)',
              value: item.accentColor,
              onSubmitted: (value) => _save(ref, accentColor: value),
            ),
            ListTile(
              title: const Text('Order'),
              trailing: SizedBox(
                width: 96,
                child: TextFormField(
                  initialValue: '${item.order}',
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (value) {
                    final order = int.tryParse(value);
                    if (order != null) _save(ref, order: order);
                  },
                ),
              ),
            ),
            if (group == AdminConfigGroup.categories ||
                group == AdminConfigGroup.booking) ...[
              _textField(
                label: 'Required booking fields (comma separated)',
                value: item.bookingRequiredFields.join(', '),
                onSubmitted: (value) =>
                    _save(ref, bookingRequiredFields: _split(value)),
              ),
              _textField(
                label: 'Optional booking fields (comma separated)',
                value: item.bookingOptionalFields.join(', '),
                onSubmitted: (value) =>
                    _save(ref, bookingOptionalFields: _split(value)),
              ),
            ],
            if (group == AdminConfigGroup.categories) ...[
              SwitchListTile.adaptive(
                title: const Text('Registration required'),
                value: item.registrationRequired,
                onChanged: (value) => _save(ref, registrationRequired: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('KYC / document required'),
                value: item.kycRequired,
                onChanged: (value) => _save(ref, kycRequired: value),
              ),
              _textField(
                label: 'Required registration fields (comma separated)',
                value: item.registrationRequiredFields.join(', '),
                onSubmitted: (value) =>
                    _save(ref, registrationRequiredFields: _split(value)),
              ),
              _textField(
                label: 'Optional registration fields (comma separated)',
                value: item.registrationOptionalFields.join(', '),
                onSubmitted: (value) =>
                    _save(ref, registrationOptionalFields: _split(value)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Invoice'),
                value: item.invoiceVisible,
                onChanged: (value) => _save(ref, invoiceVisible: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Notifications'),
                value: item.notificationVisible,
                onChanged: (value) => _save(ref, notificationVisible: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('QR/Barcode'),
                value: item.qrVisible,
                onChanged: (value) => _save(ref, qrVisible: value),
              ),
            ],
            if (group == AdminConfigGroup.invoice) ...[
              SwitchListTile.adaptive(
                title: const Text('Show PDF'),
                value: item.showPdf,
                onChanged: (value) => _save(ref, showPdf: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show print'),
                value: item.showPrint,
                onChanged: (value) => _save(ref, showPrint: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show share'),
                value: item.showShare,
                onChanged: (value) => _save(ref, showShare: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show email status'),
                value: item.emailVisible,
                onChanged: (value) => _save(ref, emailVisible: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show notification status'),
                value: item.notificationVisible,
                onChanged: (value) => _save(ref, notificationVisible: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show QR on invoice'),
                value: item.qrVisible,
                onChanged: (value) => _save(ref, qrVisible: value),
              ),
            ],
            if (group == AdminConfigGroup.qrBarcode)
              SwitchListTile.adaptive(
                title: const Text('Show QR / barcode check-in'),
                value: item.qrVisible,
                onChanged: (value) => _save(ref, qrVisible: value),
              ),
            if (group == AdminConfigGroup.analytics) ...[
              SwitchListTile.adaptive(
                title: const Text('Show KPIs'),
                value: item.analyticsShowKpis,
                onChanged: (value) => _save(ref, analyticsShowKpis: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show charts'),
                value: item.analyticsShowCharts,
                onChanged: (value) => _save(ref, analyticsShowCharts: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Daily chart'),
                value: item.analyticsShowDaily,
                onChanged: (value) => _save(ref, analyticsShowDaily: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Weekly chart'),
                value: item.analyticsShowWeekly,
                onChanged: (value) => _save(ref, analyticsShowWeekly: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Monthly chart'),
                value: item.analyticsShowMonthly,
                onChanged: (value) => _save(ref, analyticsShowMonthly: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Category breakdown'),
                value: item.analyticsShowCategoryBreakdown,
                onChanged: (value) =>
                    _save(ref, analyticsShowCategoryBreakdown: value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Listing breakdown'),
                value: item.analyticsShowListingBreakdown,
                onChanged: (value) =>
                    _save(ref, analyticsShowListingBreakdown: value),
              ),
              _textField(
                label: 'KPI order (comma separated)',
                value: item.analyticsKpiOrder.join(', '),
                onSubmitted: (value) =>
                    _save(ref, analyticsKpiOrder: _split(value)),
              ),
              _textField(
                label: 'Date ranges (comma separated)',
                value: item.analyticsDateRanges.join(', '),
                onSubmitted: (value) =>
                    _save(ref, analyticsDateRanges: _split(value)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required String value,
    required ValueChanged<String> onSubmitted,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: TextFormField(
        initialValue: value,
        onFieldSubmitted: onSubmitted,
      ),
    );
  }

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Future<void> _save(
    WidgetRef ref, {
    bool? enabled,
    bool? homeVisible,
    bool? navigationVisible,
    bool? searchVisible,
    bool? bookingEnabled,
    bool? offerVisible,
    bool? availabilityEnabled,
    bool? paymentsEnabled,
    bool? locationEnabled,
    int? order,
    String? displayName,
    String? description,
    String? icon,
    String? image,
    String? accentColor,
    List<String>? bookingRequiredFields,
    List<String>? bookingOptionalFields,
    bool? registrationRequired,
    bool? kycRequired,
    List<String>? registrationRequiredFields,
    List<String>? registrationOptionalFields,
    bool? invoiceVisible,
    bool? emailVisible,
    bool? notificationVisible,
    bool? qrVisible,
    bool? showPdf,
    bool? showPrint,
    bool? showShare,
    bool? analyticsShowKpis,
    bool? analyticsShowCharts,
    bool? analyticsShowDaily,
    bool? analyticsShowWeekly,
    bool? analyticsShowMonthly,
    bool? analyticsShowCategoryBreakdown,
    bool? analyticsShowListingBreakdown,
    List<String>? analyticsKpiOrder,
    List<String>? analyticsDateRanges,
  }) async {
    if (item.id != null) {
      item.update(
        registry,
        enabled: enabled,
        homeVisible: homeVisible,
        navigationVisible: navigationVisible,
        searchVisible: searchVisible,
        bookingEnabled: bookingEnabled,
        offerVisible: offerVisible,
        availabilityEnabled: availabilityEnabled,
        paymentsEnabled: paymentsEnabled,
        locationEnabled: locationEnabled,
        order: order,
        displayName: displayName,
        description: description,
        icon: icon,
        image: image,
        accentColor: accentColor,
        bookingRequiredFields: bookingRequiredFields,
        bookingOptionalFields: bookingOptionalFields,
        invoiceVisible: invoiceVisible,
        emailVisible: emailVisible,
        notificationVisible: notificationVisible,
        qrVisible: qrVisible,
        showPdf: showPdf,
        showPrint: showPrint,
        showShare: showShare,
        analyticsShowKpis: analyticsShowKpis,
        analyticsShowCharts: analyticsShowCharts,
        analyticsShowDaily: analyticsShowDaily,
        analyticsShowWeekly: analyticsShowWeekly,
        analyticsShowMonthly: analyticsShowMonthly,
        analyticsShowCategoryBreakdown: analyticsShowCategoryBreakdown,
        analyticsShowListingBreakdown: analyticsShowListingBreakdown,
        analyticsKpiOrder: analyticsKpiOrder,
        analyticsDateRanges: analyticsDateRanges,
      );
      return;
    }
    final categoryId = item.categoryId;
    if (categoryId == null) return;
    try {
      await ref
          .read(categoryConfigurationRepositoryProvider)
          .updateMetadata(
            categoryId: categoryId,
            metadata: item.metadataForUpdate(
              enabled: enabled,
              homeVisible: homeVisible,
              searchVisible: searchVisible,
              bookingEnabled: bookingEnabled,
              offerVisible: offerVisible,
              availabilityEnabled: availabilityEnabled,
              paymentsEnabled: paymentsEnabled,
              locationEnabled: locationEnabled,
              order: order,
              displayName: displayName,
              description: description,
              icon: icon,
              image: image,
              accentColor: accentColor,
              bookingRequiredFields: bookingRequiredFields,
              bookingOptionalFields: bookingOptionalFields,
              registrationRequired: registrationRequired,
              kycRequired: kycRequired,
              registrationRequiredFields: registrationRequiredFields,
              registrationOptionalFields: registrationOptionalFields,
              invoiceVisible: invoiceVisible,
              notificationVisible: notificationVisible,
              qrVisible: qrVisible,
            ),
          );
      ref.invalidate(categoryConfigurationsProvider);
    } catch (_) {
      // Fail closed: keep the app running if category persistence is unavailable.
    }
  }
}
