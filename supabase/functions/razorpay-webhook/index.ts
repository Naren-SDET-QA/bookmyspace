// Deno edge function: Razorpay webhook receiver.
//
// SECURITY: verifies the Razorpay webhook signature before processing.
// IDEMPOTENT: webhook_event_id uniqueness guarantees a webhook is never
// processed twice, so a payment can never create a duplicate booking.
//
// Razorpay signs the raw body with HMAC-SHA256 using the webhook secret.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { createHmac, timingSafeEqual } from 'node:crypto';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_WEBHOOK_SECRET = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function verifySignature(body: string, signature: string): boolean {
  const expected = createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
    .update(body)
    .digest('hex');
  const a = Buffer.from(signature ?? '');
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const rawBody = await req.text();
  const signature = req.headers.get('x-razorpay-signature') ?? '';
  if (!verifySignature(rawBody, signature)) {
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
  const { data: registered } = await supabase.rpc('register_webhook_event', {
    p_provider: 'razorpay',
    p_event_id: eventId,
    p_event_type: eventType,
    p_payload: event,
  });
  if (registered === false) {
    return new Response(JSON.stringify({ status: 'duplicate' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Only payment.captured confirms a booking. Payment.failed releases the hold.
  if (eventType === 'payment.captured') {
    const paymentEntity = event.payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    const paymentId = paymentEntity?.id;

    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .select('id, booking_id, amount, status')
      .eq('provider_order_id', orderId)
      .maybeSingle();
    if (paymentError || !payment) {
      return new Response(JSON.stringify({ error: 'payment_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Confirm the booking (guarded to status='pending' in SQL).
    await supabase.rpc('confirm_booking', {
      p_booking_id: payment.booking_id,
      p_payment_ref: paymentId,
    });
    await supabase
      .from('payments')
      .update({ status: 'captured', provider_payment_id: paymentId })
      .eq('id', payment.id);

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
    return new Response(JSON.stringify({ status: 'recorded_failed' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ status: 'ignored' }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
