// Creates Razorpay orders without runtime package downloads.
// POST body: { commerce_reference_id } or legacy { booking_id }

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') ?? '';
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    console.error('create-payment-order: Razorpay credentials are not configured');
    return json({ error: 'payment_not_configured' }, 424);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing_auth' }, 401);

  const userResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: SUPABASE_SERVICE_ROLE_KEY },
  });
  if (!userResponse.ok) return json({ error: 'unauthorized' }, 401);
  const user = await userResponse.json();

  try {
    const { commerce_reference_id, booking_id } = await req.json();
    if (!commerce_reference_id && !booking_id) return json({ error: 'missing_fields' }, 400);

    const referenceFilter = commerce_reference_id
      ? `id=eq.${encodeURIComponent(commerce_reference_id)}`
      : `legacy_booking_id=eq.${encodeURIComponent(booking_id)}`;
    const bookingResponse = await adminRequest(
      `/rest/v1/commerce_references?${referenceFilter}` +
        '&select=id,legacy_booking_id,customer_user_id,amount,currency,booking_status,payment_status&limit=1',
    );
    const bookings = bookingResponse.ok ? await bookingResponse.json() : [];
    const booking = bookings[0];
    if (!booking) return json({ error: 'booking_not_found' }, 404);
    if (booking.customer_user_id !== user.id ||
        booking.booking_status !== 'payment_pending') {
      return json({ error: 'not_authorized' }, 403);
    }
    if (Number(booking.amount) <= 0) {
      return json({ error: 'invalid_amount' }, 400);
    }

    const existingResponse = await adminRequest(
      `/rest/v1/payments?commerce_reference_id=eq.${encodeURIComponent(booking.id)}` +
        '&status=in.(pending,authorized,captured)&select=provider_order_id,amount,currency&limit=1',
    );
    const existing = existingResponse.ok ? (await existingResponse.json())[0] : null;
    if (existing?.provider_order_id) {
      return json({
        order_id: existing.provider_order_id,
        amount: existing.amount,
        currency: existing.currency ?? 'INR',
        key_id: RAZORPAY_KEY_ID,
      }, 200);
    }

    const orderResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        amount: String(Math.round(Number(booking.amount) * 100)),
        currency: booking.currency,
        receipt: booking.id,
      }),
      signal: AbortSignal.timeout(12_000),
    });
    if (!orderResponse.ok) {
      console.error('create-payment-order: Razorpay rejected order', orderResponse.status);
      return json({ error: 'provider_error' }, 502);
    }
    const order = await orderResponse.json();

    const insertResponse = await adminRequest('/rest/v1/payments', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        booking_id: booking.legacy_booking_id,
        commerce_reference_id: booking.id,
        user_id: user.id,
        provider: 'razorpay',
        provider_order_id: order.id,
        amount: booking.amount,
        currency: booking.currency,
        status: 'pending',
      }),
    });
    if (!insertResponse.ok) {
      console.error('create-payment-order: payment insert failed', insertResponse.status);
      return json({ error: 'payment_duplicate' }, 409);
    }

    return json(
      {
        order_id: order.id,
        amount: booking.amount,
        currency: booking.currency,
        key_id: RAZORPAY_KEY_ID,
      },
      200,
    );
  } catch (error) {
    const timedOut = error instanceof DOMException && error.name === 'TimeoutError';
    console.error(
      'create-payment-order failed',
      timedOut ? 'razorpay_timeout' : String(error),
    );
    return json(
      { error: timedOut ? 'payment_timeout' : 'internal' },
      timedOut ? 504 : 500,
    );
  }
});

function adminRequest(path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
