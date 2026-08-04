/**
 * API certification for booking + payment order (no secrets logged).
 * Usage: node scripts/certify_payment_api.mjs
 */
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'https://ehxuygrsyaknhhsaihhx.supabase.co';
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
if (!ANON_KEY) {
  console.error('Set SUPABASE_ANON_KEY env var');
  process.exit(1);
}

const email = `cert-${Date.now()}@example.com`;
const password = `Cert-${Date.now()}-x9!`;

async function api(path, { method = 'GET', body, token } = {}) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: {
      apikey: ANON_KEY,
      Authorization: token ? `Bearer ${token}` : `Bearer ${ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: res.status, data };
}

const results = {};

try {
  const signup = await api('/auth/v1/signup', {
    method: 'POST',
    body: { email, password },
  });
  const token = signup.data?.access_token;
  if (!token) {
    results.signup = { fail: signup.status, data: signup.data };
    throw new Error('signup_failed');
  }
  results.signup = { pass: true, email };

  const venueId = 'e2e40000-0000-4000-8000-000000000001';
  const bookDate = new Date();
  bookDate.setDate(bookDate.getDate() + 21);
  const dateStr = bookDate.toISOString().slice(0, 10);

  const slots = await api('/rest/v1/rpc/available_time_slots', {
    method: 'POST',
    token,
    body: { p_venue_id: venueId, p_book_date: dateStr },
  });
  const available = (slots.data ?? []).filter((s) => s.is_available);
  results.slots = {
    pass: available.length > 0,
    count: available.length,
    first: available[0]?.label,
  };

  const slotId = available[0]?.slot_id;
  const hold = await api('/rest/v1/rpc/acquire_booking_hold_for_current_user', {
    method: 'POST',
    token,
    body: {
      p_venue_id: venueId,
      p_slot_id: slotId,
      p_book_date: dateStr,
      p_amount: 5000,
      p_hold_minutes: 10,
    },
  });
  const holdId = hold.data;
  results.hold = { pass: !!holdId, holdId };

  const booking = await api('/rest/v1/rpc/create_booking_from_hold_for_current_user', {
    method: 'POST',
    token,
    body: { p_hold_id: holdId, p_booking_ref: `CERT-${Date.now()}` },
  });
  const bookingId = booking.data;
  results.booking = { pass: !!bookingId, bookingId };

  const orderRes = await fetch(`${SUPABASE_URL}/functions/v1/create-payment-order`, {
    method: 'POST',
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ booking_id: bookingId }),
  });
  const order = await orderRes.json();
  const keyId = order?.key_id ?? '';
  results.paymentOrder = {
    pass: orderRes.ok && order?.order_id && keyId.startsWith('rzp_test_'),
    status: orderRes.status,
    hasOrderId: !!order?.order_id,
    keyIdPrefix: keyId.slice(0, 12),
    error: order?.error,
  };
} catch (e) {
  results.error = String(e.message ?? e);
}

console.log(JSON.stringify(results, null, 2));
