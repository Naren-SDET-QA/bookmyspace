import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../domain/pg_rent.dart';
import '../../domain/venue.dart';
import 'venue_badges.dart';

/// PG sharing picker + tenure slider + cost breakdown.
///
/// Display-only: does not change booking holds or payment amounts.
class PgRentCalculatorCard extends StatefulWidget {
  const PgRentCalculatorCard({super.key, required this.venue});

  final Venue venue;

  static bool appliesTo(Venue venue) =>
      CustomerSectionCatalog.sectionForVenue(venue) ==
      CustomerSection.pgHostels;

  @override
  State<PgRentCalculatorCard> createState() => _PgRentCalculatorCardState();
}

class _PgRentCalculatorCardState extends State<PgRentCalculatorCard> {
  int _sharingIndex = 0;
  int _tenureMonths = 1;

  @override
  Widget build(BuildContext context) {
    if (!PgRentCalculatorCard.appliesTo(widget.venue)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final details = PgDetails.tryFromVenue(widget.venue);
    final options = details?.sharingOptions ?? const <PgSharingOption>[];
    final sharingIndex = options.isEmpty
        ? 0
        : _sharingIndex.clamp(0, options.length - 1);

    final breakdown = PgRentCalculator.fromVenue(
      widget.venue,
      selectedOptionIndex: sharingIndex,
      tenureMonths: _tenureMonths,
    );

    return Column(
      key: const Key('pg_rent_calculator'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options.isNotEmpty) ...[
          Text(l10n.selectRoomSharing, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++)
            _SharingOptionTile(
              option: options[i],
              selected: i == sharingIndex,
              perMonth: l10n.perMonth,
              onTap: () => setState(() => _sharingIndex = i),
              index: i,
            ),
          const SizedBox(height: 12),
        ],
        Card(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monthlyRentCalculator,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.stayDuration,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      l10n.monthsLabel(_tenureMonths),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  key: const Key('pg_rent_tenure_slider'),
                  value: _tenureMonths.toDouble(),
                  min: PgRentCalculator.minTenureMonths.toDouble(),
                  max: PgRentCalculator.maxTenureMonths.toDouble(),
                  divisions:
                      PgRentCalculator.maxTenureMonths -
                      PgRentCalculator.minTenureMonths,
                  label: l10n.monthsLabel(_tenureMonths),
                  onChanged: (value) =>
                      setState(() => _tenureMonths = value.round()),
                ),
                const Divider(),
                _BreakdownRow(
                  label: l10n.totalRentForTenure(_tenureMonths),
                  value: formatInr(breakdown.totalRent),
                ),
                _BreakdownRow(
                  label: l10n.refundableSecurityDeposit,
                  value: formatInr(breakdown.securityDeposit),
                  emphasize: true,
                ),
                if (breakdown.monthlyMaintenanceFee > 0)
                  _BreakdownRow(
                    label: l10n.maintenanceCharges(_tenureMonths),
                    value: formatInr(breakdown.totalMaintenance),
                  ),
                _BreakdownRow(
                  label: l10n.monthlyPayable,
                  value: formatInr(breakdown.monthlyPayable),
                ),
                const Divider(),
                _BreakdownRow(
                  key: const Key('pg_rent_total'),
                  label: l10n.estimatedTotalMoveIn,
                  value: formatInr(breakdown.totalTenureCost),
                  isTotal: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SharingOptionTile extends StatelessWidget {
  const _SharingOptionTile({
    required this.option,
    required this.selected,
    required this.perMonth,
    required this.onTap,
    required this.index,
  });

  final PgSharingOption option;
  final bool selected;
  final String perMonth;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          key: Key('pg_sharing_$index'),
          onTap: option.isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.typeName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${formatInr(option.monthlyRent)}$perMonth',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (option.roomFeatures.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final feature in option.roomFeatures)
                          Chip(
                            label: Text(feature),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isTotal
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasize ? const Color(0xFF2E7D32) : AppTheme.brand,
            ),
          ),
        ],
      ),
    );
  }
}
