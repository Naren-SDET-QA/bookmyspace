import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../domain/registration_form.dart';

class DynamicRegistrationForm extends StatefulWidget {
  const DynamicRegistrationForm({
    super.key,
    required this.definition,
    required this.onSubmit,
    this.preview = false,
    this.participantIndex = 0,
    this.collectionStage = RegistrationCollectionStage.preBooking,
  });
  final RegistrationFormDefinition definition;
  final Future<void> Function(Map<String, dynamic>, Map<String, XFile>)
  onSubmit;
  final bool preview;
  final int participantIndex;
  final RegistrationCollectionStage collectionStage;
  @override
  State<DynamicRegistrationForm> createState() => _State();
}

class _State extends State<DynamicRegistrationForm> {
  final key = GlobalKey<FormState>();
  final values = <String, dynamic>{};
  final files = <String, XFile>{};
  bool busy = false;
  Future<void> submit() async {
    if (!(key.currentState?.validate() ?? false) || busy) return;
    key.currentState!.save();
    if (widget.preview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview validation passed')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onSubmit(values, files);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.definition.fields
        .where(
          (f) =>
              f.enabled &&
              f.collectionStage == widget.collectionStage &&
              (widget.participantIndex == 0 ||
                  f.participantScope == RegistrationParticipantScope.all),
        )
        .toList();
    return Form(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in fields) ...[_field(f), const SizedBox(height: 12)],
          FilledButton.icon(
            onPressed: busy ? null : submit,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              busy
                  ? 'Submitting…'
                  : widget.preview
                  ? 'Validate preview'
                  : 'Submit registration',
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(RegistrationFieldDefinition f) {
    if (f.type == RegistrationFieldType.checkbox) {
      return FormField<bool>(
        initialValue: false,
        validator: (v) => f.required && v != true ? 'Required' : null,
        onSaved: (v) => values[f.key] = v ?? false,
        builder: (s) => CheckboxListTile(
          value: s.value ?? false,
          onChanged: s.didChange,
          title: Text(f.label),
          subtitle: s.hasError
              ? Text(
                  s.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : null,
        ),
      );
    }
    if (f.type == RegistrationFieldType.dropdown) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: f.label),
        items: f.options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        validator: (v) =>
            f.required && (v == null || v.isEmpty) ? 'Required' : null,
        onSaved: (v) => values[f.key] = v,
        onChanged: (_) {},
      );
    }
    if (f.type == RegistrationFieldType.date) {
      return TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: f.label,
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        validator: (v) =>
            f.required && (v == null || v.isEmpty) ? 'Required' : null,
        onSaved: (v) => values[f.key] = v,
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (!mounted) return;
          if (d != null) {
            values[f.key] = d.toIso8601String().split('T').first;
            key.currentState?.validate();
            setState(() {});
          }
        },
        controller: TextEditingController(
          text: values[f.key]?.toString() ?? '',
        ),
      );
    }
    if ({
      RegistrationFieldType.photo,
      RegistrationFieldType.file,
      RegistrationFieldType.document,
    }.contains(f.type)) {
      return FormField<XFile>(
        validator: (v) => f.required && v == null ? 'Required' : null,
        onSaved: (v) {
          if (v != null) files[f.key] = v;
        },
        builder: (s) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: Text(
            s.value?.name ?? s.errorText ?? 'PDF, JPG or PNG • max 10 MB',
          ),
          trailing: OutlinedButton(
            onPressed: () async {
              final x = await openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'Documents',
                    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  ),
                ],
              );
              if (x != null) {
                final length = await x.length();
                if (length > 10485760) {
                  s.didChange(null);
                  return;
                }
                s.didChange(x);
              }
            },
            child: const Text('Choose'),
          ),
        ),
      );
    }
    final keyboard = switch (f.type) {
      RegistrationFieldType.number => TextInputType.number,
      RegistrationFieldType.phone => TextInputType.phone,
      RegistrationFieldType.email => TextInputType.emailAddress,
      _ => TextInputType.text,
    };
    return TextFormField(
      decoration: InputDecoration(labelText: f.label),
      keyboardType: keyboard,
      maxLines: f.type == RegistrationFieldType.address ? 3 : 1,
      validator: (v) {
        final text = v?.trim() ?? '';
        if (f.required && text.isEmpty) return 'Required';
        final pattern = f.validation['pattern']?.toString();
        if (text.isNotEmpty &&
            pattern != null &&
            !RegExp(pattern).hasMatch(text)) {
          return 'Invalid value';
        }
        if (f.type == RegistrationFieldType.email &&
            text.isNotEmpty &&
            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
          return 'Invalid email';
        }
        return null;
      },
      onSaved: (v) => values[f.key] = f.type == RegistrationFieldType.number
          ? num.tryParse(v ?? '')
          : v?.trim(),
    );
  }
}
