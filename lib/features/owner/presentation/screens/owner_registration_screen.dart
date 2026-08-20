import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/registration_field_config.dart';
import '../owner_providers.dart';

/// Owner registration form with email/password.
class OwnerRegistrationScreen extends ConsumerStatefulWidget {
  const OwnerRegistrationScreen({super.key});

  @override
  ConsumerState<OwnerRegistrationScreen> createState() =>
      _OwnerRegistrationScreenState();
}

class _OwnerRegistrationScreenState
    extends ConsumerState<OwnerRegistrationScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final Map<String, TextEditingController> _dynamicControllers = {};
  final Map<String, String> _dynamicValues = {};
  List<RegistrationFieldConfig> _configs = const [];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final missing = _configs.where((field) {
      if (!field.required) return false;
      final value =
          _dynamicValues[field.key] ??
          _dynamicControllers[field.key]?.text.trim() ??
          '';
      return value.isEmpty;
    }).toList();
    if (_emailController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    final createOwner = ref.read(
      createOwnerProvider((
        email: _emailController.text,
        name: _nameController.text,
        password: _passwordController.text,
      )).future,
    );

    try {
      await createOwner;
      final values = <String, String>{
        for (final entry in _dynamicControllers.entries)
          entry.key: entry.value.text.trim(),
        ..._dynamicValues,
      };
      if (values.isNotEmpty) {
        await ref
            .read(registrationConfigRepositoryProvider)
            .saveOwnerValues(values);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signUp)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorInvalidEmail} ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final createOwner = ref.watch(
      createOwnerProvider((
        email: _emailController.text,
        name: _nameController.text,
        password: _passwordController.text,
      )),
    );
    final fields = ref.watch(ownerRegistrationFieldsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signUp)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.name,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l10n.password,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            fields.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Additional fields unavailable: $error'),
              ),
              data: (configs) {
                _configs = configs;
                return Column(
                  children: [
                    for (final field in configs.where(
                      (field) =>
                          field.key != 'owner_name' && field.key != 'email',
                    ))
                      _dynamicField(field),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: createOwner.isLoading ? null : _register,
              child: Text(createOwner.isLoading ? l10n.loading : l10n.signUp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dynamicField(RegistrationFieldConfig config) {
    if (config.type == RegistrationFieldType.boolean) {
      return SwitchListTile(
        title: Text('${config.label}${config.required ? ' *' : ''}'),
        subtitle: config.helpText == null ? null : Text(config.helpText!),
        value: _dynamicValues[config.key] == 'true',
        onChanged: (value) => setState(() {
          _dynamicValues[config.key] = value.toString();
        }),
      );
    }
    if (config.type == RegistrationFieldType.dropdown &&
        config.options.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          value: _dynamicValues[config.key],
          decoration: InputDecoration(
            labelText: '${config.label}${config.required ? ' *' : ''}',
            helperText: config.helpText,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in config.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) => setState(() {
            if (value == null) {
              _dynamicValues.remove(config.key);
            } else {
              _dynamicValues[config.key] = value;
            }
          }),
        ),
      );
    }
    final controller = _dynamicControllers.putIfAbsent(
      config.key,
      TextEditingController.new,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: config.type == RegistrationFieldType.date,
        onTap: config.type == RegistrationFieldType.date
            ? () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                  initialDate: DateTime.now(),
                );
                if (picked != null) {
                  controller.text = picked.toIso8601String().split('T').first;
                }
              }
            : null,
        obscureText: config.sensitive,
        keyboardType: config.type == RegistrationFieldType.phone
            ? TextInputType.phone
            : config.type == RegistrationFieldType.email
            ? TextInputType.emailAddress
            : config.type == RegistrationFieldType.number
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: '${config.label}${config.required ? ' *' : ''}',
          hintText: config.placeholder,
          helperText: config.helpText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
