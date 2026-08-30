// Deno edge function: batch-sends queued push notifications.
//
// Mirrors send-email-outbox/index.ts: claims a batch of pending
// public.push_outbox rows (enqueued by the trg_enqueue_push_for_notification
// trigger on public.notifications -- see
// 20260829090000_push_notifications.sql) and sends via OneSignal's Create
// Notification API, targeting the job's user_id as a OneSignal External ID
// (set client-side via OneSignal.login(userId) -- see
// lib/core/notifications/onesignal_push_service.dart).
//
// Unlike the previous FCM implementation, this no longer looks up
// public.device_tokens to fan out per device: OneSignal's own External ID
// association already fans out to every subscribed device for that user,
// across Android, iOS and web, in one API call per job. device_tokens is
// kept only for local observability of what OneSignal subscription id
// each device last registered -- see 20260829090000_push_notifications.sql
// and 20260830120000_device_tokens_client_grants.sql (unchanged by this
// migration to OneSignal: push_outbox, its trigger, and device_tokens'
// schema/RLS are all preserved as-is).
//
// Like send-email-outbox, this function is not scheduled from within this
// repo's SQL; invoke it periodically (Supabase dashboard cron, GitHub
// Action, etc.) once ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY and
// PUSH_PROVIDER=onesignal are configured as Supabase secrets.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { hasNoMatchedRecipients, sendOneSignalNotification } from '../_shared/onesignal.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const provider = Deno.env.get('PUSH_PROVIDER') ?? 'disabled';
const oneSignalAppId = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const oneSignalRestApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';
const cors = { 'Content-Type': 'application/json' };

/**
 * Sends a single push_outbox job via OneSignal, targeting job.user_id as
 * the OneSignal External ID. Exported so the provider-gating behavior
 * (mock/unconfigured/onesignal) can be exercised in tests without real
 * credentials or network access -- see send_push_outbox_test.ts.
 */
export async function sendJob(
  job: Record<string, any>,
  config: {
    provider: string;
    appId: string;
    restApiKey: string;
    send: typeof sendOneSignalNotification;
  } = {
    provider,
    appId: oneSignalAppId,
    restApiKey: oneSignalRestApiKey,
    send: sendOneSignalNotification,
  },
): Promise<{ skipped: boolean }> {
  if (config.provider === 'mock') return { skipped: true };
  if (config.provider !== 'onesignal' || !config.appId || !config.restApiKey) {
    throw new Error('push_provider_not_configured');
  }

  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(job.data ?? {})) {
    data[key] = typeof value === 'string' ? value : JSON.stringify(value);
  }

  const result = await config.send(config.appId, config.restApiKey, {
    externalUserId: job.user_id,
    title: job.title,
    body: job.body ?? '',
    data,
  });

  // No subscribed OneSignal device for this user yet -- not an error,
  // nothing to send to. The in-app notification itself was already
  // created (this outbox row only drives the push side).
  return { skipped: hasNoMatchedRecipients(result) };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const client: SupabaseClient = createClient(url, serviceKey);
  const { data: jobs, error } = await client.rpc('claim_push_outbox_batch', { p_limit: 10 });
  if (error) {
    return new Response(JSON.stringify({ error: 'claim_failed' }), { status: 500, headers: cors });
  }

  let sent = 0;
  for (const job of jobs ?? []) {
    try {
      await sendJob(job);
      await client.rpc('set_push_outbox_result', { p_id: job.id, p_status: 'sent' });
      sent++;
    } catch (error) {
      const safe = error instanceof Error ? error.message.slice(0, 200) : 'push_send_failed';
      await client.rpc('set_push_outbox_result', {
        p_id: job.id,
        p_status: 'failed',
        p_error: safe,
        p_retry_after_seconds: Math.min(3600, 30 * (2 ** Math.min(job.attempts, 7))),
      });
    }
  }

  return new Response(JSON.stringify({ claimed: jobs?.length ?? 0, sent, provider }), {
    status: 200,
    headers: cors,
  });
});
