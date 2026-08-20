import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { amountDecision, bookingDecision, canFailClaim, pendingOrderResponse } from './payment_order_policy.ts';

// ============================================================
// Razorpay order creation — runs server-side so secrets stay secret.
// Called from the Flutter app after a booking hold is acquired.
// POST body: { booking_id }
// ============================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function createRazorpayOrder(amountPaise: number, receipt: string) {
  const body = new URLSearchParams({ amount: String(amountPaise), currency: 'INR', receipt });
  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  if (!res.ok) {
    throw new Error(`razorpay error ${res.status}: ${await res.text()}`);
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

  // This client is only used to validate the caller's JWT. Do not reuse it
  // for privileged database writes.
  const authClient: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await authClient.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Keep the service-role client unmodified so its database operations are
  // not downgraded to the authenticated role by the caller's JWT.
  const adminClient: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  try {
    const { booking_id, amount } = await req.json();
    if (!booking_id) {
      return new Response(JSON.stringify({ error: 'missing_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Validate server-side: the booking must belong to the user and be pending.
    const { data: booking, error: bookingError } = await adminClient
      .from('bookings')
      .select('id, user_id, total_amount, status')
      .eq('id', booking_id)
      .single();
    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: 'booking_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (bookingDecision(booking, user.id) !== 'ok') {
      return new Response(JSON.stringify({ error: 'not_authorized' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    // The amount is always taken from the DB (never from the client).
    // If supplied by an older client, still reject a mismatched amount; the
    // current Flutter client intentionally omits it and uses the DB total.
    if (amountDecision(amount, Number(booking.total_amount)) === 'amount_mismatch') {
      return new Response(JSON.stringify({ error: 'amount_mismatch' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // A retry for the same pending booking reuses the already-created order.
    // This check happens before contacting Razorpay, preventing another
    // external order from being created for a completed insert.
    const { data: existingPayment, error: existingPaymentError } = await adminClient
      .from('payments')
      .select('id, provider_order_id, amount, currency, status')
      .eq('booking_id', booking.id)
      .eq('provider', 'razorpay')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (existingPaymentError) {
      return new Response(JSON.stringify({ error: 'payment_lookup_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const existingResponse = pendingOrderResponse(existingPayment);
    if (existingResponse) {
      return new Response(
        JSON.stringify(existingResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Reserve the booking before calling Razorpay. The partial unique index
    // makes this claim atomic across concurrent Edge Function invocations.
    const { data: claim, error: claimError } = await adminClient
      .from('payments')
      .insert({
        booking_id: booking.id,
        user_id: user.id,
        provider: 'razorpay',
        amount: booking.total_amount,
        status: 'pending',
      })
      .select('id')
      .single();
    if (claimError || !claim) {
      if (claimError?.code === '23505') {
        return new Response(JSON.stringify({ error: 'payment_in_progress' }), {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify({ error: 'payment_claim_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let order: { id: string };
    try {
      order = await createRazorpayOrder(
        Math.round(Number(booking.total_amount) * 100),
        booking.id,
      );
    } catch (_) {
      // Release only this request's claim. This lets a retry claim the
      // booking again immediately after a provider-order failure.
      if (canFailClaim(claim.id, claim.id, 'pending', null)) {
        await adminClient
          .from('payments')
          .update({ status: 'failed' })
          .eq('id', claim.id)
          .eq('status', 'pending')
          .is('provider_order_id', null);
      }
      return new Response(JSON.stringify({ error: 'payment_order_failed' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // There is an unavoidable crash window after Razorpay creates the order
    // and before this update persists its provider_order_id. Reconciliation
    // must handle such orphaned claims; do not weaken the claim constraint.
    const { error: updateError } = await adminClient
      .from('payments')
      .update({ provider_order_id: order.id })
      .eq('id', claim.id)
      .eq('status', 'pending');
    if (updateError) {
      return new Response(JSON.stringify({ error: 'payment_persist_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({ order_id: order.id, amount: booking.total_amount, currency: 'INR' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: 'internal', detail: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
