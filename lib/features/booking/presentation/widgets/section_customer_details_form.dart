import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../home/domain/customer_section_catalog.dart';

/// Collects only the details required for the selected section, at booking time.
class SectionCustomerDetailsForm extends StatelessWidget {
  const SectionCustomerDetailsForm({
    super.key,
    required this.section,
    required this.details,
    required this.onChanged,
  });

  final CustomerSection? section;
  final CustomerBookingDetails details;
  final ValueChanged<CustomerBookingDetails> onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = CustomerSectionCatalog.requiredCustomerFields(section);
    if (fields.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final nameLabel = section == CustomerSection.pgHostels
        ? l10n.tenantName
        : section == CustomerSection.lodgeRooms
            ? l10n.guestName
            : l10n.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bookingDetails,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (fields.contains(CustomerDetailField.fullName))
            TextFormField(
              initialValue: details.fullName,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: nameLabel,
                isDense: true,
              ),
              validator: AppValidators.name,
              onChanged: (v) => onChanged(details.copyWith(fullName: v)),
            ),
          if (fields.contains(CustomerDetailField.phone)) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: details.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.phone,
                isDense: true,
              ),
              validator: AppValidators.phone,
              onChanged: (v) => onChanged(details.copyWith(phone: v)),
            ),
          ],
          if (fields.contains(CustomerDetailField.eventType)) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: details.eventType,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.eventType,
                isDense: true,
              ),
              validator: (v) =>
                  AppValidators.required(v, fieldName: 'Event type'),
              onChanged: (v) => onChanged(details.copyWith(eventType: v)),
            ),
          ],
          if (fields.contains(CustomerDetailField.idNumber)) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: details.idNumber,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.idNumber,
                isDense: true,
              ),
              validator: (v) => AppValidators.required(
                v,
                fieldName: 'ID number',
                minLength: 6,
              ),
              onChanged: (v) => onChanged(details.copyWith(idNumber: v)),
            ),
          ],
          if (fields.contains(CustomerDetailField.address)) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: details.address,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.address,
                isDense: true,
              ),
              validator: (v) => AppValidators.required(
                v,
                fieldName: 'Address',
                minLength: 8,
              ),
              onChanged: (v) => onChanged(details.copyWith(address: v)),
            ),
          ],
        ],
      ),
    );
  }
}
