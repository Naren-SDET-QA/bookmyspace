import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { createHmac } from 'node:crypto';

// ============================================================
// Razorpay order creation — runs server-side so secrets stay secret.
// Called from the Flutter app after a booking hold is acquired.
// POST body: { booking_id, hold_id, amount }
// ============================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
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

  const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { booking_id, amount } = await req.json();
    if (!booking_id) {
      return new Response(JSON.stringify({ error: 'missing_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Validate server-side: the booking must belong to the user and be pending.
    const { data: booking, error: bookingError } = await supabase
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
    if (booking.user_id !== user.id || booking.status !== 'pending') {
      return new Response(JSON.stringify({ error: 'not_authorized' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    // The amount is always taken from the DB (never from the client).
    // The server remains authoritative. Older clients may omit amount because
    // the repository contract only sends booking_id; when supplied, validate it.
    if (amount != null && Math.abs(Number(amount) - Number(booking.total_amount)) > 0.01) {
      return new Response(JSON.stringify({ error: 'amount_mismatch' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const order = await createRazorpayOrder(
      Math.round(Number(booking.total_amount) * 100),
      booking.id,
    );

    const { error: insertError } = await supabase.from('payments').insert({
      booking_id: booking.id,
      user_id: user.id,
      provider: 'razorpay',
      provider_order_id: order.id,
      amount: booking.total_amount,
      status: 'pending',
    });
    if (insertError) {
      return new Response(JSON.stringify({ error: 'payment_duplicate' }), {
        status: 409,
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
