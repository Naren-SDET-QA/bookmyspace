import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/event.dart';

/// A tappable event card used in listings and the home screen.
///
/// Matches prototype `.evMini` (horizontal) and listing cards.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final emoji = PrototypeVisuals.emojiForEventCategory(event.category.name);
    final dateLabel = _datePill(event.startsAt);
    final hasImage = event.coverImage.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.eventDetails.replaceAll(':id', event.id)),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Ink(
          decoration: PrototypeVisuals.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: PrototypeVisuals.thumbGradientFor(event.id),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.cardRadius),
                        ),
                      ),
                    ),
                    if (hasImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.cardRadius),
                        ),
                        child: AppNetworkImage(
                          url: event.coverImage,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Center(
                        child: Text(
                          emoji,
                          style: PrototypeVisuals.emojiStyle(fontSize: 40),
                        ),
                      ),
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (event.venueName.isNotEmpty) event.venueName,
                              DateFormat.jm().format(event.startsAt),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (event.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: PrototypeVisuals.freeTagBg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'FREE ENTRY',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success,
                              ),
                            ),
                          )
                        else
                          Text(
                            formatInr(event.ticketPrice),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brand,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          event.seatsLeft > 0
                              ? l10n.seatsLeft.replaceAll(
                                  '{count}',
                                  '${event.seatsLeft}',
                                )
                              : l10n.soldOut,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: event.seatsLeft > 0
                                ? AppTheme.muted
                                : AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _datePill(DateTime startsAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('d MMM').format(startsAt);
  }
}
