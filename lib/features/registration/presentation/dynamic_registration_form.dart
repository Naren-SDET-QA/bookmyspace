import 'package:flutter/material.dart';
import '../domain/module_registration.dart';

/// Shared renderer for every configurable customer registration form.
/// It only collects values; submission/payment remain server-authoritative.
class DynamicRegistrationForm extends StatefulWidget {
  const DynamicRegistrationForm({
    super.key,
    required this.fields,
    required this.onChanged,
  });
  final List<ModuleFormField> fields;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<DynamicRegistrationForm> createState() =>
      _DynamicRegistrationFormState();
}

class _DynamicRegistrationFormState extends State<DynamicRegistrationForm> {
  final _values = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(ModuleFormField field) =>
      _controllers.putIfAbsent(field.key, TextEditingController.new);

  void _set(String key, dynamic value) {
    _values[key] = value;
    widget.onChanged(Map.unmodifiable(_values));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: widget.fields.where((field) => field.enabled).map((field) {
      if (field.type == ModuleFieldType.checkbox) {
        return CheckboxListTile(
          title: Text(field.label),
          value: _values[field.key] as bool? ?? false,
          onChanged: (v) => _set(field.key, v ?? false),
          contentPadding: EdgeInsets.zero,
        );
      }
      if (field.type == ModuleFieldType.dropdown ||
          field.type == ModuleFieldType.radio) {
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: field.label),
          value: _values[field.key] as String?,
          items: field.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => _set(field.key, v),
          validator: field.required
              ? (v) => v == null || v.isEmpty ? 'Required' : null
              : null,
        );
      }
      final multiline =
          field.type == ModuleFieldType.longText ||
          field.type == ModuleFieldType.address;
      return TextFormField(
        controller: _controller(field),
        maxLines: multiline ? 3 : 1,
        keyboardType:
            field.type == ModuleFieldType.number ||
                field.type == ModuleFieldType.currency
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(labelText: field.label),
        onChanged: (v) => _set(field.key, v),
        validator: field.required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      );
    }).toList(),
  );
}
