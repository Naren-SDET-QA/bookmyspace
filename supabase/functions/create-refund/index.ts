// Deno edge function: create a Razorpay refund for a captured payment.
//
// Called from the Flutter app from the "request refund" action on a
// confirmed booking. The refund is created server-side (secrets stay on
// the server), a `refunds` row is written, and the booking + payment are
// moved to their `refunded` states.
//
// POST body: { commerce_reference_id } or legacy { booking_id }, amount?, reason?
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function createRazorpayRefund(
  paymentId: string,
  amountPaise: number,
  reason: string,
) {
  const body = new URLSearchParams({
    amount: String(amountPaise),
    notes: reason || 'booking_refund',
  });
  const res = await fetch(
    `https://api.razorpay.com/v1/payments/${paymentId}/refund`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    },
  );
  if (!res.ok) {
    throw new Error(`razorpay refund error ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'missing_auth' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { commerce_reference_id, booking_id, amount, reason } = await req.json();
    if (!commerce_reference_id && !booking_id) {
      return new Response(JSON.stringify({ error: 'missing_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const referenceQuery = supabase.from('commerce_references')
      .select('id, legacy_booking_id, customer_user_id, booking_status, amount');
    const { data: booking, error: bookingError } = await (commerce_reference_id
      ? referenceQuery.eq('id', commerce_reference_id)
      : referenceQuery.eq('legacy_booking_id', booking_id))
      .single();
    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: 'booking_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (booking.customer_user_id !== user.id || booking.booking_status !== 'confirmed') {
      return new Response(JSON.stringify({ error: 'not_refundable' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Find the captured payment for this booking.
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .select('id, provider_payment_id, amount, status')
      .eq('commerce_reference_id', booking.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (paymentError || !payment || payment.status !== 'captured') {
      return new Response(JSON.stringify({ error: 'no_captured_payment' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Refund amount defaults to the full captured amount.
    const refundAmount = amount != null ? Number(amount) : Number(payment.amount);
    if (
      refundAmount <= 0 ||
      refundAmount > Number(payment.amount) + 0.01
    ) {
      return new Response(JSON.stringify({ error: 'invalid_amount' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Guard: a refund for this payment must not already exist.
    const { data: existing, error: existingError } = await supabase
      .from('refunds')
      .select('id')
      .eq('payment_id', payment.id)
      .maybeSingle();
    if (existingError && !existing) {
      return new Response(JSON.stringify({ error: 'refund_lookup_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (existing) {
      return new Response(JSON.stringify({ error: 'already_refunded' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const refund = await createRazorpayRefund(
      payment.provider_payment_id,
      Math.round(refundAmount * 100),
      reason ?? '',
    );

    const { data: refundRow, error: refundInsertError } = await supabase
      .from('refunds')
      .insert({
        payment_id: payment.id,
        booking_id: booking.legacy_booking_id,
        commerce_reference_id: booking.id,
        amount: refundAmount,
        reason: reason ?? null,
        status: 'processed',
        provider_refund_id: refund.id,
        processed_at: new Date().toISOString(),
      })
      .select('id, amount, status, provider_refund_id')
      .single();
    if (refundInsertError) {
      return new Response(JSON.stringify({ error: 'refund_insert_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Dispatch the verified refund to the owning module.
    await supabase.rpc('apply_commerce_refund', {
      p_reference_id: booking.id,
      p_partial: refundAmount + 0.01 < Number(payment.amount),
    });
    await supabase
      .from('payments')
      .update({ status: refundAmount + 0.01 < Number(payment.amount)
        ? 'partially_refunded' : 'refunded' })
      .eq('id', payment.id);

    return new Response(JSON.stringify(refundRow), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'internal', detail: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
