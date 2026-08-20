import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const keyId = Deno.env.get('RAZORPAY_KEY_ID')!;
const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')!;
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json' } });

async function razorpayOrder(amount: number, currency: string, receipt: string) {
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ amount: String(amount), currency, receipt }),
  });
  if (!response.ok) throw new Error(`provider_${response.status}`);
  return await response.json() as { id: string };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({ error: 'missing_auth' }, 401);
  const authClient: SupabaseClient = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
  const { data: { user } } = await authClient.auth.getUser();
  if (!user) return json({ error: 'unauthorized' }, 401);
  const admin = createClient(url, serviceRole);
  try {
    const { registration_id, idempotency_key } = await request.json();
    if (!registration_id || !idempotency_key) return json({ error: 'missing_fields' }, 400);
    const { data: submission } = await admin.from('module_form_submissions').select('id,module_key,customer_user_id,status').eq('id', registration_id).eq('customer_user_id', user.id).single();
    if (!submission) return json({ error: 'registration_not_found' }, 404);
    const { data: config } = await admin.from('module_feature_configs').select('payment_enabled,payment_timing,registration_fee_minor,currency,refund_policy').eq('module_key', submission.module_key).is('venue_id', null).maybeSingle();
    if (!config?.payment_enabled || config.payment_timing === 'payment_not_required') return json({ error: 'payment_not_required' }, 400);
    const amount = Number(config.registration_fee_minor ?? 0);
    if (!Number.isSafeInteger(amount) || amount <= 0) return json({ error: 'payment_amount_not_configured' }, 422);
    const { data: existing } = await admin.from('module_registration_payments').select('id,provider_order_id,amount_minor,currency,status').eq('submission_id', registration_id).maybeSingle();
    if (existing?.provider_order_id && ['pending','processing'].includes(existing.status)) return json({ order_id: existing.provider_order_id, amount: existing.amount_minor, currency: existing.currency, payment_id: existing.id });
    const { data: claim, error: claimError } = await admin.from('module_registration_payments').insert({ submission_id: registration_id, user_id: user.id, module_key: submission.module_key, amount_minor: amount, currency: config.currency, refundable: config.refund_policy?.refundable !== false, idempotency_key: idempotency_key, status: 'pending' }).select('id').single();
    if (claimError || !claim) return json({ error: claimError?.code === '23505' ? 'payment_in_progress' : 'payment_claim_failed' }, claimError?.code === '23505' ? 409 : 500);
    let order: { id: string };
    try { order = await razorpayOrder(amount, config.currency, registration_id); } catch (_) { await admin.from('module_registration_payments').update({ status: 'failed', updated_at: new Date().toISOString() }).eq('id', claim.id).eq('status', 'pending'); return json({ error: 'payment_order_failed' }, 502); }
    const { error } = await admin.from('module_registration_payments').update({ provider_order_id: order.id, updated_at: new Date().toISOString() }).eq('id', claim.id).eq('status', 'pending');
    if (error) return json({ error: 'payment_persist_failed' }, 500);
    return json({ order_id: order.id, amount, currency: config.currency, payment_id: claim.id });
  } catch (_) { return json({ error: 'internal' }, 500); }
});
