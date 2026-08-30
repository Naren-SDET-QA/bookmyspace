import { buildOneSignalRequestBody, hasNoMatchedRecipients } from './onesignal.ts';

Deno.test('buildOneSignalRequestBody targets the user by external_id, not a device token', () => {
  const body = buildOneSignalRequestBody('app-1', {
    externalUserId: 'user-42',
    title: 'Booking confirmed',
    body: 'Your slot is booked.',
    data: { notification_type: 'booking_confirmation', booking_id: 'b-1' },
  });
  if (body.app_id !== 'app-1') throw new Error('app_id not passed through');
  if (body.target_channel !== 'push') throw new Error('target_channel must be "push" when using include_aliases');
  const aliases = body.include_aliases as { external_id: string[] };
  if (JSON.stringify(aliases.external_id) !== JSON.stringify(['user-42'])) {
    throw new Error('include_aliases.external_id must target exactly the job user id');
  }
});

Deno.test('buildOneSignalRequestBody puts the custom payload under "data" (not "custom_data")', () => {
  const body = buildOneSignalRequestBody('app-1', {
    externalUserId: 'user-1',
    title: 't',
    data: { notification_type: 'slot_reminder' },
  });
  if ((body as Record<string, unknown>)['custom_data'] !== undefined) {
    throw new Error('must not use custom_data -- it is not reliably delivered as additionalData');
  }
  const data = body.data as Record<string, string>;
  if (data.notification_type !== 'slot_reminder') {
    throw new Error('data field must carry the notification_type routing key');
  }
});

Deno.test('buildOneSignalRequestBody defaults missing body/data without throwing', () => {
  const body = buildOneSignalRequestBody('app-1', {
    externalUserId: 'user-1',
    title: 'Only a title',
  });
  const contents = body.contents as Record<string, string>;
  if (contents.en !== '') throw new Error('missing body should default to empty string');
  if (JSON.stringify(body.data) !== '{}') throw new Error('missing data should default to {}');
});

Deno.test('hasNoMatchedRecipients is true for an empty id (no subscribed device)', () => {
  if (!hasNoMatchedRecipients({ id: '' })) throw new Error('empty id must count as no recipients');
});

Deno.test('hasNoMatchedRecipients is false once OneSignal returns a notification id', () => {
  if (hasNoMatchedRecipients({ id: 'notif-abc' })) throw new Error('a real id must count as matched');
});
