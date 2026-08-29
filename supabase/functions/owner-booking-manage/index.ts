// Deno edge function: owner-side booking management.
//
// Owners may read bookings for their venues through RLS, but all status
// transitions and walk-in (offline) bookings run through this function with
// the service role, mirroring how customer refunds run through create-refund.
//
// POST body:
// {
//   action: 'create_offline',
//   venue_id, slot_id, book_date,
//   customer_name, customer_phone, idempotency_key (optional)
//   amount, tax_amount, total_amount
// }
// or
// {
//   action: 'update_status',
//   booking_id,
//   status_action: 'confirm' | 'complete' | 'cancel' | 'no_show'
// }
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { enqueueEmail, userEmail } from '../_shared/email_outbox.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// Only needed for the reject-with-refund path below. If unset in this
// environment, refund attempts fail closed (see refundRejectedBooking) and
// the booking rejection itself still succeeds — the refund can then be
// retried/actioned manually, matching create-refund's behavior.
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') ?? '';
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function bookingRef(): string {
  return `BMS-${crypto.randomUUID().replaceAll('-', '').slice(0, 6).toUpperCase()}`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'missing_auth' }, 401);
  }

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return json({ error: 'unauthorized' }, 401);
  }

  try {
    const body = await req.json();
    if (body?.action === 'create_offline') {
      return await createOfflineBooking(supabase, user.id, body);
    }
    if (body?.action === 'update_status') {
      return await updateBookingStatus(supabase, user.id, body);
    }
    if (body?.action === 'approve' || body?.action === 'reject') {
      return await decideBooking(supabase, user.id, body);
    }
    return json({ error: 'invalid_action' }, 400);
  } catch (e) {
    return json({ error: 'internal', detail: String(e) }, 500);
  }
});

// Verifies the caller owns `venue_id` and returns the venue row.
async function ownVenue(
  supabase: SupabaseClient,
  userId: string,
  venueId: string,
): Promise<{ venue: Record<string, unknown> | null; response: Response | null }> {
  const { data: venue, error } = await supabase
    .from('venues')
    .select('id, tax_rate, org_id, organizations!inner(owner_user_id)')
    .eq('id', venueId)
    .single();
  if (error || !venue) {
    return { venue: null, response: json({ error: 'venue_not_found' }, 404) };
  }
  const org = Array.isArray(venue.organizations)
    ? venue.organizations[0]
    : venue.organizations;
  if (org?.owner_user_id !== userId) {
    return { venue: null, response: json({ error: 'not_owner' }, 403) };
  }
  return { venue, response: null };
}

// Mirrors create-refund/index.ts's Razorpay call exactly (same provider,
// same auth scheme). Duplicated locally rather than imported so this
// function's dependency surface stays self-contained.
async function createRazorpayRefund(
  paymentId: string,
  amountPaise: number,
  reason: string,
): Promise<{ id: string }> {
  const body = new URLSearchParams({
    amount: String(amountPaise),
    notes: reason || 'booking_owner_rejected',
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

// Verified-fix: owner_decide_booking() (SQL) correctly marks the booking
// 'rejected' but — being plpgsql — cannot call the Razorpay HTTP API, so no
// refund was ever issued on rejection. This runs after a successful reject
// decision and issues the refund the same way create-refund does for
// customer-initiated refunds, then links it back to the approval event the
// RPC already inserted. Refund failure here does NOT undo the rejection —
// the booking is correctly rejected either way — but is reported in the
// response so the caller can prompt for a manual refund.
async function refundRejectedBooking(
  supabase: SupabaseClient,
  bookingId: string,
  approvalEventId: string | null,
): Promise<{ refund_status: string; refund_id?: string; detail?: string }> {
  const { data: payment, error: paymentError } = await supabase
    .from('payments')
    .select('id, provider_payment_id, amount, status, method')
    .eq('booking_id', bookingId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (paymentError || !payment) {
    return { refund_status: 'not_applicable', detail: 'no payment found for booking' };
  }
  if (payment.method === 'offline') {
    return { refund_status: 'not_applicable', detail: 'offline payment — settle with customer directly' };
  }
  if (payment.status !== 'captured' || !payment.provider_payment_id) {
    return { refund_status: 'not_applicable', detail: `payment status is '${payment.status}', nothing to refund` };
  }

  const { data: existingRefund } = await supabase
    .from('refunds')
    .select('id, status')
    .eq('payment_id', payment.id)
    .maybeSingle();
  if (existingRefund) {
    return { refund_status: existingRefund.status, refund_id: existingRefund.id, detail: 'refund already existed for this payment' };
  }

  if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    return { refund_status: 'failed', detail: 'RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET not configured in this environment' };
  }

  const { data: initiatedRefund, error: initiatedError } = await supabase
    .from('refunds')
    .insert({
      payment_id: payment.id,
      booking_id: bookingId,
      amount: Number(payment.amount),
      reason: 'owner_rejected_booking',
      status: 'requested',
    })
    .select('id')
    .single();
  if (initiatedError || !initiatedRefund) {
    return { refund_status: 'failed', detail: initiatedError?.message ?? 'refund_insert_failed' };
  }

  try {
    const refund = await createRazorpayRefund(
      payment.provider_payment_id,
      Math.round(Number(payment.amount) * 100),
      'owner_rejected_booking',
    );
    await supabase
      .from('refunds')
      .update({ status: 'processed', provider_refund_id: refund.id, processed_at: new Date().toISOString() })
      .eq('id', initiatedRefund.id);
    await supabase.from('payments').update({ status: 'refunded' }).eq('id', payment.id);
    if (approvalEventId) {
      await supabase.from('booking_approval_events').update({ refund_id: initiatedRefund.id }).eq('id', approvalEventId);
    }
    return { refund_status: 'processed', refund_id: initiatedRefund.id };
  } catch (e) {
    // Refund row stays 'requested' so it's visible for manual follow-up
    // (matches create-refund's approach of never silently losing a
    // refund request).
    return { refund_status: 'failed', refund_id: initiatedRefund.id, detail: String(e) };
  }
}

async function decideBooking(supabase: SupabaseClient, userId: string, body: Record<string, unknown>): Promise<Response> {
  const bookingId = String(body.booking_id ?? '').trim();
  const decision = body.action === 'approve' ? 'approve' : 'reject';
  if (!bookingId) return json({ error: 'missing_fields' }, 400);
  const { data, error } = await supabase.rpc('owner_decide_booking', {
    p_booking_id: bookingId,
    p_decision: decision,
  });
  if (error) {
    if (error.code === '42501') return json({ error: 'not_owner' }, 403);
    if (error.code === '23P01') return json({ error: 'slot_unavailable' }, 409);
    if (error.code === '55000') return json({ error: 'invalid_transition' }, 409);
    return json({ error: 'decision_failed' }, 500);
  }
  const result = (data ?? { booking_id: bookingId, status: decision === 'approve' ? 'confirmed' : 'rejected' }) as Record<string, unknown>;
  if (decision === 'reject') {
    const approvalEventId = typeof result.approval_event_id === 'string' ? result.approval_event_id : null;
    const refundResult = await refundRejectedBooking(supabase, bookingId, approvalEventId);
    return json({ ...result, ...refundResult }, 200);
  }
  return json(result, 200);
}

async function createOfflineBooking(
  supabase: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const { venue_id, slot_id, book_date, customer_name, customer_phone, amount, tax_amount, total_amount, idempotency_key } = body;
  if (
    !venue_id || !slot_id || !book_date ||
    !customer_name || !customer_phone ||
    amount == null || tax_amount == null || total_amount == null
  ) {
    return json({ error: 'missing_fields' }, 400);
  }

  const { venue, response } = await ownVenue(supabase, userId, String(venue_id));
  if (response) return response;

  // Authoritative price + tax validation, mirroring create-booking-hold.
  const { data: slot, error: slotError } = await supabase
    .from('time_slots')
    .select('id, start_time, end_time, price_amount, is_active')
    .eq('id', String(slot_id))
    .single();
  if (slotError || !slot || slot.is_active === false) {
    return json({ error: 'invalid_slot' }, 400);
  }
  if (Math.abs(Number(amount) - Number(slot.price_amount)) > 0.01) {
    return json({ error: 'amount_mismatch' }, 400);
  }
  const taxRate = Number(venue.tax_rate ?? 0);
  const expectedTax = Math.round(Number(amount) * taxRate) / 100;
  if (Math.abs(Number(tax_amount) - expectedTax) > 0.01) {
    return json({ error: 'amount_mismatch' }, 400);
  }
  if (Math.abs(Number(total_amount) - (Number(amount) + Number(tax_amount))) > 0.01) {
    return json({ error: 'amount_mismatch' }, 400);
  }

  // A lost response must be safe to retry. Metadata keeps this extension
  // backward-compatible with the existing booking schema and RLS contract.
  const idempotencyKey = String(idempotency_key ?? '').trim();
  if (idempotencyKey) {
    const { data: existing } = await supabase
      .from('bookings')
      .select('*, venues(id, name, city), time_slots(id, label), payments(method, provider_payment_id, status, created_at)')
      .eq('venue_id', String(venue_id))
      .not('status', 'in', '(cancelled,refunded)')
      .contains('metadata', { offline_idempotency_key: idempotencyKey })
      .maybeSingle();
    if (existing) return json({ booking: existing, idempotent: true }, 200);
  }

  const metadata = {
    offline_booking: true,
    customer_name: String(customer_name),
    customer_phone: String(customer_phone),
    ...(idempotencyKey ? { offline_idempotency_key: idempotencyKey } : {}),
  };

  // Insert the booking (the exclusion constraint rejects overlaps).
  const { data: booking, error: bookingError } = await supabase
    .from('bookings')
    .insert({
      booking_ref: bookingRef(),
      user_id: userId,
      venue_id: String(venue_id),
      slot_id: String(slot_id),
      book_date: String(book_date),
      start_time: slot.start_time,
      end_time: slot.end_time,
      status: 'confirmed',
      quantity: 1,
      amount: Number(amount),
      tax_amount: Number(tax_amount),
      total_amount: Number(total_amount),
      currency: 'INR',
      metadata,
      confirmed_at: new Date().toISOString(),
    })
    .select('id, booking_ref')
    .single();
  if (bookingError) {
    if (String(bookingError.code) === '23P01') {
      return json({ error: 'slot_unavailable' }, 409);
    }
    return json({ error: 'booking_create_failed', detail: bookingError.message }, 500);
  }

  // Offline payments are captured at the door — recorded for accounting.
  const { error: paymentError } = await supabase
    .from('payments')
    .insert({
      booking_id: booking.id,
      user_id: userId,
      provider: 'offline',
      provider_order_id: `OFFLINE-${booking.id}`,
      amount: Number(total_amount),
      currency: 'INR',
      status: 'captured',
      method: 'offline',
      is_refundable: false,
      metadata: { offline: true, customer_name: String(customer_name) },
    });
  if (paymentError) {
    await supabase.from('bookings').delete().eq('id', booking.id);
    return json({ error: 'payment_create_failed', detail: paymentError.message }, 500);
  }

  try {
    await supabase.from('notifications').insert({
      user_id: userId,
      title: 'Offline booking recorded',
      body: `Walk-in booking ${booking.booking_ref} was added to your venue inventory.`,
      type: 'booking_confirmed',
      data: { booking_id: booking.id, offline: true },
    });
  } catch (_) {
    // Offline booking/payment state is authoritative; notification is best-effort.
  }

  const { data: full } = await supabase
    .from('bookings')
    .select('*, venues(id, name, city), time_slots(id, label)')
    .eq('id', booking.id)
    .single();

  return json({ booking: full ?? booking }, 200);
}

async function updateBookingStatus(
  supabase: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const { booking_id, status_action } = body;
  if (!booking_id || !status_action) {
    return json({ error: 'missing_fields' }, 400);
  }
  if (!['confirm', 'complete', 'cancel', 'no_show'].includes(String(status_action))) {
    return json({ error: 'invalid_action' }, 400);
  }

  const { data: booking, error: bookingError } = await supabase
    .from('bookings')
    .select('id, venue_id, user_id, status, venue:venues!inner(org_id, organizations!inner(owner_user_id))')
    .eq('id', String(booking_id))
    .single();
  if (bookingError || !booking) {
    return json({ error: 'booking_not_found' }, 404);
  }
  const venue = Array.isArray(booking.venue) ? booking.venue[0] : booking.venue;
  const org = Array.isArray(venue?.organizations)
    ? venue.organizations[0]
    : venue?.organizations;
  if (org?.owner_user_id !== userId) {
    return json({ error: 'not_owner' }, 403);
  }

  const status = booking.status;
  let next: string | null = null;
  switch (status_action) {
    case 'confirm':
      if (status !== 'pending') return json({ error: 'invalid_transition' }, 409);
      next = 'confirmed';
      break;
    case 'complete':
      if (status !== 'confirmed') return json({ error: 'invalid_transition' }, 409);
      next = 'completed';
      break;
    case 'cancel':
      if (status === 'pending') {
        next = 'cancelled';
      } else if (status === 'confirmed') {
        // Only offline (walk-in) payments can be cancelled by the owner;
        // online payments must go through the customer refund flow.
        const { data: payment } = await supabase
          .from('payments')
          .select('method')
          .eq('booking_id', String(booking_id))
          .maybeSingle();
        if (payment?.method !== 'offline') {
          return json({ error: 'confirmed_payment_required' }, 409);
        }
        next = 'cancelled';
      } else {
        return json({ error: 'invalid_transition' }, 409);
      }
      break;
    case 'no_show':
      if (status !== 'confirmed') return json({ error: 'invalid_transition' }, 409);
      next = 'no_show';
      break;
  }

  const update: Record<string, unknown> = { status: next, updated_at: new Date().toISOString() };
  if (next === 'confirmed') update.confirmed_at = new Date().toISOString();
  if (next === 'cancelled') update.cancelled_at = new Date().toISOString();

  const { data: updated, error: updateError } = await supabase
    .from('bookings')
    .update(update)
    .eq('id', String(booking_id))
    .select('*, venues(id, name, city), time_slots(id, label)')
    .single();
  if (updateError) {
    return json({ error: 'update_failed', detail: updateError.message }, 500);
  }

  // Notify the customer about the status change (best-effort, never blocks).
  const customerUserId = booking.user_id as string | undefined;
  if (customerUserId && next) {
    const notif = notificationForStatus(next);
    if (notif) {
      await supabase.from('notifications').insert({
        user_id: customerUserId,
        title: notif.title,
        body: notif.body,
        type: notif.type,
        data: { booking_id },
      });
    }
    const customer = await userEmail(supabase, customerUserId);
    if (customer && next === 'cancelled') {
      await enqueueEmail(supabase, {
        eventKey: `booking.cancelled.customer.${booking_id}`,
        eventType: 'booking.cancelled',
        recipientEmail: customer.email,
        recipientName: customer.name,
        bookingId: String(booking_id),
        templateName: 'booking-cancelled',
        payload: { title: 'Booking cancelled', message: 'Your booking was cancelled by the venue.', booking_ref: String(booking_id) },
      });
    }
  }

  return json({ booking: updated }, 200);
}

function notificationForStatus(
  status: string,
): { title: string; body: string; type: string } | null {
  switch (status) {
    case 'confirmed':
      return {
        title: 'Booking confirmed',
        body: 'Your booking has been confirmed by the venue owner.',
        type: 'booking_confirmed',
      };
    case 'completed':
      return {
        title: 'Booking completed',
        body: 'Your booking has been marked as completed.',
        type: 'system',
      };
    case 'cancelled':
      return {
        title: 'Booking cancelled',
        body: 'Your booking has been cancelled by the venue owner.',
        type: 'booking_cancelled',
      };
    case 'no_show':
      return {
        title: 'Booking marked no-show',
        body: 'Your booking has been marked as a no-show.',
        type: 'system',
      };
    default:
      return null;
  }
}
