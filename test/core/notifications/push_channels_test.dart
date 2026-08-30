import 'package:bookmyspace/core/notifications/push_channels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushChannels.channelIdForType', () {
    test('maps booking confirmation and payment types to the confirmations channel', () {
      for (final type in ['booking_confirmation', 'booking_confirmed', 'payment_received']) {
        expect(
          PushChannels.channelIdForType(type),
          PushChannels.confirmations,
          reason: 'type=$type',
        );
      }
    });

    test('maps slot_reminder to the reminders channel', () {
      expect(PushChannels.channelIdForType('slot_reminder'), PushChannels.reminders);
    });

    test('maps status/cancellation/refund types to the status-updates channel', () {
      for (final type in [
        'booking_status_update',
        'booking_cancelled',
        'refund_processed',
      ]) {
        expect(
          PushChannels.channelIdForType(type),
          PushChannels.statusUpdates,
          reason: 'type=$type',
        );
      }
    });

    test('falls back to the general channel for null or unknown types', () {
      expect(PushChannels.channelIdForType(null), PushChannels.general);
      expect(PushChannels.channelIdForType('something_new'), PushChannels.general);
    });

    test('registers exactly one channel definition per known channel id', () {
      final ids = PushChannels.all.map((c) => c.id).toSet();
      expect(ids, {
        PushChannels.confirmations,
        PushChannels.reminders,
        PushChannels.statusUpdates,
        PushChannels.general,
      });
    });

    test('nameFor/descriptionFor resolve real, non-empty channel metadata', () {
      for (final channel in PushChannels.all) {
        expect(PushChannels.nameFor(channel.id), isNotEmpty);
        expect(PushChannels.descriptionFor(channel.id), isNotEmpty);
      }
    });
  });
}
