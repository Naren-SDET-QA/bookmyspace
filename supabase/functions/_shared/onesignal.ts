// Minimal OneSignal REST API client for Deno edge functions.
//
// Sends push notifications via OneSignal's Create Notification API,
// targeting a BookMySpace user by OneSignal External ID (set client-side
// via OneSignal.login(userId) -- see
// lib/core/notifications/onesignal_push_service.dart). No third-party
// OneSignal SDK dependency; a plain fetch() call, mirroring the previous
// hand-rolled fcm.ts client this replaces.
//
// Configure via the ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY secrets.
// Until both are set (they are not, in this dev environment), callers must
// treat push sending as unavailable -- see send-push-outbox/index.ts's
// PUSH_PROVIDER gate.

const ONESIGNAL_API_URL = 'https://api.onesignal.com/notifications?c=push';

export type OneSignalMessage = {
  externalUserId: string;
  title: string;
  body?: string;
  data?: Record<string, string>;
};

export type OneSignalSendResult = {
  id: string;
  recipients?: number;
  errors?: unknown;
};

/**
 * Builds the Create Notification request body for one message. Exported
 * as a pure function (no network or env access) so it can be unit tested
 * without real credentials -- see onesignal_test.ts.
 */
export function buildOneSignalRequestBody(
  appId: string,
  message: OneSignalMessage,
): Record<string, unknown> {
  return {
    app_id: appId,
    include_aliases: { external_id: [message.externalUserId] },
    target_channel: 'push',
    contents: { en: message.body ?? '' },
    headings: { en: message.title },
    // The long-established, reliably-delivered field for a custom payload
    // that reaches the client as OSNotification.additionalData. OneSignal's
    // newer "custom_data" field has open reports of not always reaching
    // additionalData (OneSignal/OneSignal-Flutter-SDK#939), so "data" is
    // used deliberately -- this is what PushRouteResolver/PushChannels on
    // the client key off, so getting this field wrong silently breaks
    // notification-tap routing.
    data: message.data ?? {},
  };
}

/**
 * True when a Create Notification response indicates no subscribed
 * recipient matched the target external_id (not an error -- the user just
 * has no active OneSignal subscription yet, e.g. never granted permission,
 * or has push notifications turned off). Mirrors the previous FCM
 * implementation's "no registered devices" no-op branch.
 */
export function hasNoMatchedRecipients(result: OneSignalSendResult): boolean {
  return !result.id || result.id.length === 0;
}

/**
 * Sends one push notification via OneSignal's REST API. Throws on any
 * non-2xx HTTP response so the caller's retry logic can react to it. A
 * 200 response with no matched recipients is NOT an error -- check
 * hasNoMatchedRecipients() on the result.
 */
export async function sendOneSignalNotification(
  appId: string,
  restApiKey: string,
  message: OneSignalMessage,
): Promise<OneSignalSendResult> {
  const response = await fetch(ONESIGNAL_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Key ${restApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(buildOneSignalRequestBody(appId, message)),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      `onesignal_send_http_${response.status}:${JSON.stringify(json).slice(0, 200)}`,
    );
  }
  return json as OneSignalSendResult;
}
