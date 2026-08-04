// Deno edge function: Razorpay webhook receiver.
//
// SECURITY: verifies the Razorpay webhook signature before processing.
// IDEMPOTENT: webhook_event_id uniqueness guarantees a webhook is never
// processed twice, so a payment can never create a duplicate booking.
//
// Razorpay signs the raw body with HMAC-SHA256 using the webhook secret.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { verifyRazorpaySignature } from '../_shared/razorpay_signature.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_WEBHOOK_SECRET = Deno.env.get('RAZORPAY_WEBHOOK_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const rawBody = await req.text();
  const signature = req.headers.get('x-razorpay-signature') ?? '';
  if (!RAZORPAY_WEBHOOK_SECRET) {
    console.error('razorpay-webhook: webhook secret is not configured');
    return json({ error: 'webhook_not_configured' }, 424);
  }
  if (!await verifyRazorpaySignature(rawBody, signature, RAZORPAY_WEBHOOK_SECRET)) {
    return new Response(JSON.stringify({ error: 'invalid_signature' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const event = JSON.parse(rawBody);
  const eventId: string = event.payload?.payment?.entity?.id ?? event.id;
  const eventType: string = event.event ?? 'unknown';

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  // Idempotency: register the event; skip if it was already handled.
  const { data: registered, error: registrationError } = await supabase.rpc('begin_webhook_event', {
    p_provider: 'razorpay',
    p_event_id: eventId,
    p_event_type: eventType,
    p_payload: event,
  });
  if (registrationError) return json({ error: 'event_registration_failed' }, 500);
  if (registered === false) {
    return new Response(JSON.stringify({ status: 'duplicate' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
  // Only payment.captured confirms a booking. Payment.failed releases the hold.
  if (eventType === 'payment.captured') {
    const paymentEntity = event.payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    const paymentId = paymentEntity?.id;

    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .select('id, commerce_reference_id, amount, status')
      .eq('provider_order_id', orderId)
      .maybeSingle();
    if (paymentError || !payment) {
      throw new Error('payment_not_found');
    }

    // Dispatch module confirmation only after the trusted captured webhook.
    const { error: applyError } = await supabase.rpc('apply_commerce_payment', {
      p_reference_id: payment.commerce_reference_id,
      p_payment_ref: paymentId,
    });
    if (applyError) throw new Error('commerce_confirmation_failed');
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'captured', provider_payment_id: paymentId })
      .eq('id', payment.id);
    if (updateError) throw new Error('payment_update_failed');
    await completeEvent(supabase, eventId);

    return new Response(JSON.stringify({ status: 'confirmed' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (eventType === 'payment.failed') {
    // Mark payment failed; the reconciliation job / hold expiry frees the slot.
    await supabase
      .from('payments')
      .update({ status: 'failed' })
      .eq('provider_order_id', event.payload?.payment?.entity?.order_id ?? '');
    await completeEvent(supabase, eventId);
    return new Response(JSON.stringify({ status: 'recorded_failed' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  await completeEvent(supabase, eventId);
  return new Response(JSON.stringify({ status: 'ignored' }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
  } catch (error) {
    const reason = error instanceof Error ? error.message : 'processing_failed';
    await supabase.rpc('fail_webhook_event', {
      p_provider: 'razorpay', p_event_id: eventId, p_error: reason,
    });
    console.error('razorpay-webhook: processing failed', reason);
    return json({ error: reason }, reason === 'payment_not_found' ? 404 : 503);
  }
});

async function completeEvent(supabase: SupabaseClient, eventId: string) {
  const { error } = await supabase.rpc('complete_webhook_event', {
    p_provider: 'razorpay', p_event_id: eventId,
  });
  if (error) throw new Error('event_completion_failed');
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
