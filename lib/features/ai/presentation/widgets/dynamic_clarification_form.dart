import 'package:flutter/material.dart';
import '../../domain/dynamic_clarification.dart';

/// One renderer for metadata-defined clarification fields. It contains no
/// category knowledge; callers own persistence and submit validation.
class DynamicClarificationForm extends StatelessWidget {
  const DynamicClarificationForm({super.key, required this.schema, required this.values, required this.onChanged, this.loading = false, this.error, this.expired = false, this.onRetry});
  final DynamicFieldSchema schema;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool loading;
  final String? error;
  final bool expired;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (expired) return _message(context, 'This clarification has expired.', onRetry);
    if (error != null) return _message(context, error!, onRetry);
    return SingleChildScrollView(
      child: Column(
        children: schema.fields.map((field) {
        final when = field.validation['when'];
        if (when is Map && values[when['field']]?.toString() != when['equals']?.toString()) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(context, field));
        }).toList(growable: false),
      ),
    );
  }

  Widget _field(BuildContext context, DynamicField field) {
    if (field.type == DynamicFieldType.checkbox || field.type == DynamicFieldType.toggle) {
      return CheckboxListTile(value: values[field.key] == true, onChanged: (value) => _set(field.key, value), title: Text(field.label), controlAffinity: ListTileControlAffinity.leading);
    }
    if (field.type == DynamicFieldType.dropdown || field.type == DynamicFieldType.radio) {
      return DropdownButtonFormField<String>(value: values[field.key]?.toString(), decoration: InputDecoration(labelText: field.label), items: field.options.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => _set(field.key, value), validator: field.required ? (value) => value == null ? 'Required' : null : null);
    }
    final keyboard = field.type == DynamicFieldType.number || field.type == DynamicFieldType.currency ? TextInputType.number : field.type == DynamicFieldType.email ? TextInputType.emailAddress : field.type == DynamicFieldType.phone ? TextInputType.phone : TextInputType.text;
    return TextFormField(initialValue: values[field.key]?.toString(), keyboardType: keyboard, decoration: InputDecoration(labelText: field.label), onChanged: (value) => _set(field.key, value), validator: field.required ? (value) => value == null || value.trim().isEmpty ? 'Required' : null : null);
  }

  Widget _message(BuildContext context, String message, VoidCallback? retry) => Column(mainAxisSize: MainAxisSize.min, children: [Text(message), if (retry != null) TextButton(onPressed: retry, child: const Text('Retry'))]);

  void _set(String key, Object? value) => onChanged({...values, key: value});
}
