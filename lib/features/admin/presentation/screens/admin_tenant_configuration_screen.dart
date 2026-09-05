import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../integrations/domain/tenant_configuration.dart';
import '../../../integrations/presentation/tenant_configuration_controller.dart';
import '../../../integrations/presentation/tenant_configuration_providers.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/observability_control_plane.dart';

class AdminTenantConfigurationScreen extends ConsumerStatefulWidget {
  const AdminTenantConfigurationScreen({super.key, required this.organizationId});
  final String organizationId;

  @override
  ConsumerState<AdminTenantConfigurationScreen> createState() =>
      _AdminTenantConfigurationScreenState();
}

class _AdminTenantConfigurationScreenState
    extends ConsumerState<AdminTenantConfigurationScreen> {
  TenantConfigurationController? _controller;
  late Future<TenantConfiguration> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadConfiguration();
  }

  Future<TenantConfiguration> _loadConfiguration() async {
    var organizationId = widget.organizationId;
    if (organizationId.isEmpty) {
      final row = await ref.read(supabaseProvider)
          .from('organizations')
          .select('id')
          .limit(1)
          .maybeSingle();
      organizationId = row?['id']?.toString() ?? '';
    }
    if (organizationId.isEmpty) {
      throw StateError('No tenant organization is available for this administrator.');
    }
    _controller = TenantConfigurationController(
      ref.read(tenantConfigurationRepositoryProvider), organizationId,
    );
    return _controller!.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _controller == null ? _loadConfiguration() : _controller!.refresh());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant configuration'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<TenantConfiguration>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Tenant configuration unavailable: ${snapshot.error}'));
          }
          final config = snapshot.data ?? _controller!.configuration;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BrandingCard(config: config, onSaved: _refresh),
              const SizedBox(height: 12),
              _FeatureCard(controller: _controller!, config: config, onSaved: _refresh),
              const SizedBox(height: 12),
              _ObservabilityEffectiveCard(config: config),
              const SizedBox(height: 12),
              _SectionCard(title: 'Languages', values: config.language),
              _SectionCard(title: 'Booking', values: config.booking),
              _SectionCard(title: 'Notifications', values: config.notifications),
              _SectionCard(title: 'Media', values: config.media),
              _SectionCard(title: 'Voice', values: config.voice),
            ],
          );
        },
      ),
    );
  }
}

class _ObservabilityEffectiveCard extends StatelessWidget {
  const _ObservabilityEffectiveCard({required this.config});
  final TenantConfiguration config;

  @override
  Widget build(BuildContext context) {
    const keys = <String, String>{
      'observability': 'Observability',
      'observability.error_collection': 'Error collection',
      'observability.metrics': 'Metrics',
      'observability.alerts': 'Alerts',
      'observability.recovery': 'Recovery',
    };
    final categories = config.categoryOverrides.entries;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Observability effective settings'),
        subtitle: const Text('Global and configured category overrides'),
        children: [
          for (final entry in keys.entries)
            _settingRow(entry.key, entry.value, null),
          for (final category in categories)
            for (final entry in keys.entries)
              if (category.value.containsKey(entry.key))
                _settingRow(entry.key, entry.value, category.key),
        ],
      ),
    );
  }

  Widget _settingRow(String key, String label, String? category) {
    final shortKey = key.startsWith('observability.') ? key.substring('observability.'.length) : key;
    final result = EffectiveObservabilitySetting.resolve(
      key: shortKey,
      global: config.features[key] as bool?,
      category: category == null ? null : config.categoryOverrides[category]?[key] as bool?,
      fallback: false,
    );
    return ListTile(
      dense: true,
      title: Text(category == null ? label : '$category → $label'),
      subtitle: Text('Source: ${result.sourceLabel}'),
      trailing: Text(result.value ? 'ON' : 'OFF'),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.controller, required this.config, required this.onSaved});
  final TenantConfigurationController controller;
  final TenantConfiguration config;
  final Future<void> Function() onSaved;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  static const featureLabels = <String, String>{
    'observability': 'Observability',
    'observability.error_collection': 'Error collection',
    'observability.metrics': 'Metrics',
    'observability.alerts': 'Alerts',
    'observability.recovery': 'Recovery',
    'booking': 'Booking',
    'voice': 'Voice booking',
    'qr': 'QR',
    'pdf': 'PDF',
    'invoice': 'Invoice',
    'whatsapp': 'WhatsApp',
    'email': 'Email',
    'push': 'Push notifications',
    'sms': 'SMS',
    'reviews': 'Reviews',
    'offers': 'Offers',
    'gallery': 'Gallery',
    'video': 'Video',
    'media_3d': '3D media',
    'maps': 'Maps',
    'current_location': 'Current location',
    'pin_search': 'PIN/ZIP search',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Features'),
        subtitle: const Text('Changes apply through tenant runtime configuration'),
        children: [
          for (final entry in featureLabels.entries)
            SwitchListTile.adaptive(
              title: Text(entry.value),
              value: widget.config.isEnabled(entry.key),
              onChanged: (value) async {
                await widget.controller.setFeature(entry.key, value);
                await widget.onSaved();
              },
            ),
        ],
      ),
    );
  }
}

class _BrandingCard extends StatelessWidget {
  const _BrandingCard({required this.config, required this.onSaved});
  final TenantConfiguration config;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(config.branding['name']?.toString() ?? 'Business branding'),
          subtitle: Text(config.branding.isEmpty
              ? 'Configure branding through the tenant configuration service.'
              : 'Branding configuration loaded'),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.values});
  final String title;
  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          title: Text(title),
          subtitle: Text(values.isEmpty ? 'Using safe defaults' : '${values.length} configured values'),
          children: [
            for (final entry in values.entries)
              ListTile(title: Text(entry.key), trailing: Text('${entry.value}')),
          ],
        ),
      );
}
