import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/configurable_booking.dart';

class ConfigurableBookingFieldsForm extends StatelessWidget {
  const ConfigurableBookingFieldsForm({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
  });

  final List<BookingFieldSpec> fields;
  final BookingFieldValues values;
  final ValueChanged<BookingFieldValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final extras = fields
        .where((field) => field.key != 'date' && field.key != 'time')
        .toList();
    if (extras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          for (final field in extras) ...[
            _field(context, field),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _field(BuildContext context, BookingFieldSpec field) {
    final current = values.values[field.key];
    final kind = field.inputKind;
    if (kind == 'number') {
      final count = current is num ? current.toInt() : 1;
      return Row(
        children: [
          Expanded(child: Text(_label(field.key))),
          IconButton(
            onPressed: count > 1
                ? () => onChanged(values.copyWith(field.key, count - 1))
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$count'),
          IconButton(
            onPressed: () => onChanged(values.copyWith(field.key, count + 1)),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
    }
    if (kind == 'date') {
      final parsed = current is DateTime
          ? current
          : DateTime.tryParse('$current');
      return Row(
        children: [
          Expanded(child: Text(_label(field.key))),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parsed ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                onChanged(
                  values.copyWith(
                    field.key,
                    DateFormat('yyyy-MM-dd').format(picked),
                  ),
                );
              }
            },
            child: Text(
              parsed == null ? 'Select' : DateFormat.MMMd().format(parsed),
            ),
          ),
        ],
      );
    }
    return TextFormField(
      initialValue: current?.toString() ?? '',
      decoration: InputDecoration(labelText: _label(field.key)),
      onChanged: (value) => onChanged(values.copyWith(field.key, value)),
    );
  }

  static String _label(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
