import { sendJob } from './index.ts';
import type { OneSignalMessage, OneSignalSendResult } from '../_shared/onesignal.ts';

const job = {
  id: 'job-1',
  user_id: 'user-42',
  title: 'Booking confirmed',
  body: 'Your slot is booked.',
  data: { type: 'booking_confirmation', booking_id: 'b-1' },
  attempts: 0,
};

Deno.test('sendJob: provider "mock" skips without calling send() or needing credentials', async () => {
  let called = false;
  const result = await sendJob(job, {
    provider: 'mock',
    appId: '',
    restApiKey: '',
    send: async () => {
      called = true;
      return { id: 'should-not-be-called' };
    },
  });
  if (called) throw new Error('mock provider must never call send()');
  if (!result.skipped) throw new Error('mock provider must report skipped: true');
});

Deno.test('sendJob: provider "disabled" (default, no PUSH_PROVIDER set) throws without credentials', async () => {
  let threw = false;
  try {
    await sendJob(job, {
      provider: 'disabled',
      appId: '',
      restApiKey: '',
      send: async () => ({ id: 'unused' }),
    });
  } catch (error) {
    threw = true;
    if (!(error instanceof Error) || error.message !== 'push_provider_not_configured') {
      throw new Error(`unexpected error: ${error}`);
    }
  }
  if (!threw) throw new Error('disabled provider must throw push_provider_not_configured');
});

Deno.test('sendJob: provider "onesignal" without ONESIGNAL_APP_ID/REST_API_KEY throws, never calls send()', async () => {
  let called = false;
  let threw = false;
  try {
    await sendJob(job, {
      provider: 'onesignal',
      appId: '',
      restApiKey: '',
      send: async () => {
        called = true;
        return { id: 'unused' };
      },
    });
  } catch {
    threw = true;
  }
  if (called) throw new Error('must not call OneSignal without both credentials configured');
  if (!threw) throw new Error('must throw push_provider_not_configured when credentials are missing');
});

Deno.test('sendJob: fully configured, no matching OneSignal subscription -> reported as skipped, not an error', async () => {
  const result = await sendJob(job, {
    provider: 'onesignal',
    appId: 'app-1',
    restApiKey: 'key-1',
    send: async (
      _appId: string,
      _key: string,
      _message: OneSignalMessage,
    ): Promise<OneSignalSendResult> => ({ id: '' }),
  });
  if (!result.skipped) throw new Error('an empty id from OneSignal must be treated as skipped, not failed');
});

Deno.test('sendJob: fully configured, OneSignal accepts the notification -> not skipped', async () => {
  let receivedExternalId = '';
  const result = await sendJob(job, {
    provider: 'onesignal',
    appId: 'app-1',
    restApiKey: 'key-1',
    send: async (
      _appId: string,
      _key: string,
      message: OneSignalMessage,
    ): Promise<OneSignalSendResult> => {
      receivedExternalId = message.externalUserId;
      return { id: 'notif-1' };
    },
  });
  if (result.skipped) throw new Error('a real notification id must not be reported as skipped');
  if (receivedExternalId !== 'user-42') {
    throw new Error('must target the job user_id as the OneSignal external id, not a device token');
  }
});
