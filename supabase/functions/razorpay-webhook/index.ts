// Deno edge function: Razorpay webhook receiver.
//
// SECURITY: verifies the Razorpay webhook signature before processing.
// IDEMPOTENT: webhook_event_id uniqueness guarantees a webhook is never
// processed twice, so a payment can never create a duplicate booking.
//
// Razorpay signs the raw body with HMAC-SHA256 using the webhook secret.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { enqueueEmail, userEmail } from '../_shared/email_outbox.ts';

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
  const eventId: string = event.id ?? event.payload?.payment?.entity?.id ?? crypto.randomUUID();
  const eventType: string = event.event ?? 'unknown';

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  // Idempotency: register the event; skip if it was already handled.
  const { data: registered, error: registerError } = await supabase.rpc('register_webhook_event', {
    p_provider: 'razorpay',
    p_event_id: eventId,
    p_event_type: eventType,
    p_payload: event,
  });
  if (registerError || registered == null) {
    return new Response(JSON.stringify({ error: 'webhook_registration_failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  if (registered === false) {
    return new Response(JSON.stringify({ status: 'duplicate' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const releaseEvent = async () => {
    await supabase
      .from('webhook_events')
      .delete()
      .eq('provider', 'razorpay')
      .eq('event_id', eventId);
  };

  const markEventProcessed = async () => {
    const { error } = await supabase
      .from('webhook_events')
      .update({ processed: true, processed_at: new Date().toISOString() })
      .eq('provider', 'razorpay')
      .eq('event_id', eventId);
    return error;
  };

  // Only payment.captured confirms a booking. Payment.failed releases the hold.
  if (eventType === 'payment.captured') {
    const paymentEntity = event.payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    const paymentId = paymentEntity?.id;
    const providerAmount = Number(paymentEntity?.amount);
    const providerCurrency = String(paymentEntity?.currency ?? '').toUpperCase();
    if (!orderId || !paymentId || !Number.isFinite(providerAmount)) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'invalid_payment_payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Contact-access orders are intentionally separate from booking payments.
    // They use the same verified webhook and Razorpay credentials, but never
    // enter the booking lifecycle.
    const { data: contactTransaction } = await supabase
      .from('business_payment_transactions')
      .select('id, customer_user_id, venue_id, field_key, pricing_feature_key, price_version, amount_minor, currency, status, entitlement_expires_at, reveal_limit')
      .eq('provider_order_id', orderId)
      .maybeSingle();
    if (contactTransaction) {
      if (providerCurrency !== String(contactTransaction.currency).toUpperCase() || providerAmount !== Number(contactTransaction.amount_minor)) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'payment_amount_or_currency_mismatch' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      if (contactTransaction.status === 'captured') {
        await markEventProcessed();
        return new Response(JSON.stringify({ status: 'already_captured' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      const { error: entitlementError } = await supabase.from('contact_entitlements').upsert({
        customer_user_id: contactTransaction.customer_user_id,
        venue_id: contactTransaction.venue_id,
        field_key: contactTransaction.field_key,
        pricing_feature_key: contactTransaction.pricing_feature_key,
        price_version: contactTransaction.price_version,
        amount_minor: contactTransaction.amount_minor,
        currency: contactTransaction.currency,
        payment_id: null,
        transaction_id: contactTransaction.id,
        expires_at: contactTransaction.entitlement_expires_at,
      }, { onConflict: 'customer_user_id,venue_id,field_key' });
      if (entitlementError) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'entitlement_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      const { error: transactionError } = await supabase.from('business_payment_transactions').update({ status: 'captured', provider_payment_id: paymentId, captured_at: new Date().toISOString() }).eq('id', contactTransaction.id).eq('status', 'pending');
      if (transactionError) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'transaction_update_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      await markEventProcessed();
      return new Response(JSON.stringify({ status: 'contact_entitlement_granted' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // Registration payments share Razorpay verification but have their own
    // lifecycle record; booking payment behavior below is unchanged.
    const { data: registrationPayment } = await supabase
      .from('module_registration_payments')
      .select('id, submission_id, user_id, amount_minor, currency, status')
      .eq('provider_order_id', orderId)
      .maybeSingle();
    if (registrationPayment) {
      if (providerCurrency !== String(registrationPayment.currency).toUpperCase() ||
          providerAmount !== Number(registrationPayment.amount_minor)) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'payment_amount_or_currency_mismatch' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      if (registrationPayment.status === 'paid') {
        await markEventProcessed();
        return new Response(JSON.stringify({ status: 'already_paid' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      const { error: registrationUpdateError } = await supabase
        .from('module_registration_payments')
        .update({ status: 'paid', provider_payment_id: paymentId, updated_at: new Date().toISOString() })
        .eq('id', registrationPayment.id)
        .in('status', ['pending', 'processing']);
      if (registrationUpdateError) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'registration_payment_update_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      const recipient = await userEmail(supabase, registrationPayment.user_id);
      if (recipient) await enqueueEmail(supabase, {
        eventKey: `registration.payment_success.customer.${registrationPayment.submission_id}`,
        eventType: 'registration.payment_success',
        recipientEmail: recipient.email,
        recipientName: recipient.name,
        paymentId: registrationPayment.id,
        templateName: 'payment-receipt',
        payload: { registration_id: registrationPayment.submission_id, amount_minor: registrationPayment.amount_minor, currency: registrationPayment.currency },
      });
      const processedError = await markEventProcessed();
      if (processedError) { await releaseEvent(); return new Response(JSON.stringify({ error: 'webhook_state_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }); }
      return new Response(JSON.stringify({ status: 'registration_paid' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .select('id, booking_id, amount, currency, status, provider_payment_id')
      .eq('provider_order_id', orderId)
      .maybeSingle();
    if (paymentError || !payment) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'payment_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (
      providerCurrency !== String(payment.currency ?? '').toUpperCase() ||
      providerAmount !== Math.round(Number(payment.amount) * 100)
    ) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'payment_amount_or_currency_mismatch' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (payment.status === 'captured') {
      const processedError = await markEventProcessed();
      if (processedError) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'webhook_state_failed' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify({ status: 'already_captured' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('status, user_id, booking_ref, total_amount, venue_id')
      .eq('id', payment.booking_id)
      .single();
    if (bookingError || !booking) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'booking_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (booking.status !== 'confirmed') {
      const { error: confirmError } = await supabase.rpc('confirm_booking', {
        p_booking_id: payment.booking_id,
        p_payment_ref: paymentId,
      });
      if (confirmError) {
        await releaseEvent();
        return new Response(JSON.stringify({ error: 'booking_confirmation_failed' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const { data: confirmedBooking, error: confirmedBookingError } = await supabase
      .from('bookings')
      .select('status')
      .eq('id', payment.booking_id)
      .single();
    if (confirmedBookingError || confirmedBooking?.status !== 'confirmed') {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'booking_confirmation_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: paymentUpdateError } = await supabase
      .from('payments')
      .update({ status: 'captured', provider_payment_id: paymentId })
      .eq('id', payment.id);
    if (paymentUpdateError) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'payment_update_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const customer = await userEmail(supabase, booking.user_id);
    if (customer) {
      await enqueueEmail(supabase, {
        eventKey: `booking.confirmed.customer.${payment.booking_id}`,
        eventType: 'booking.confirmed',
        recipientEmail: customer.email,
        recipientName: customer.name,
        bookingId: payment.booking_id,
        paymentId: payment.id,
        templateName: 'booking-confirmed',
        payload: { title: 'Booking confirmed', message: 'Your payment was verified and your booking is confirmed.', booking_ref: booking.booking_ref, amount: booking.total_amount },
      });
      await enqueueEmail(supabase, {
        eventKey: `payment.receipt.customer.${payment.id}`,
        eventType: 'payment.receipt',
        recipientEmail: customer.email,
        recipientName: customer.name,
        bookingId: payment.booking_id,
        paymentId: payment.id,
        templateName: 'payment-receipt',
        payload: { title: 'Payment receipt', message: 'Your Razorpay payment was received.', booking_ref: booking.booking_ref, amount: booking.total_amount },
      });
    }
    const { data: venue } = await supabase.from('venues').select('org_id').eq('id', booking.venue_id).maybeSingle();
    if (venue?.org_id) {
      const { data: organization } = await supabase.from('organizations').select('owner_user_id').eq('id', venue.org_id).maybeSingle();
      if (organization?.owner_user_id) {
        const owner = await userEmail(supabase, organization.owner_user_id);
        if (owner) await enqueueEmail(supabase, {
          eventKey: `booking.received.owner.${payment.booking_id}`,
          eventType: 'booking.received',
          recipientEmail: owner.email,
          recipientName: owner.name,
          bookingId: payment.booking_id,
          paymentId: payment.id,
          templateName: 'owner-new-booking',
          payload: { title: 'New booking received', message: 'A paid booking was confirmed for your listing.', booking_ref: booking.booking_ref, amount: booking.total_amount },
        });
      }
    }

    const { data: confirmedBooking } = await supabase
      .from('bookings')
      .select('user_id, booking_ref')
      .eq('id', payment.booking_id)
      .maybeSingle();
    if (confirmedBooking?.user_id) {
      await supabase.from('notifications').insert({
        user_id: confirmedBooking.user_id,
        title: 'Booking confirmed',
        body: `Your booking ${confirmedBooking.booking_ref ?? ''} is confirmed.`,
        type: 'booking_confirmed',
        data: { booking_id: payment.booking_id },
      });
    }

    const processedError = await markEventProcessed();
    if (processedError) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'webhook_state_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ status: 'confirmed' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (eventType === 'payment.failed') {
    // Mark payment failed; the reconciliation job / hold expiry frees the slot.
    const { error: failedPaymentError } = await supabase
      .from('payments')
      .update({ status: 'failed' })
      .eq('provider_order_id', event.payload?.payment?.entity?.order_id ?? '');
    if (failedPaymentError) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'payment_update_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const processedError = await markEventProcessed();
    if (processedError) {
      await releaseEvent();
      return new Response(JSON.stringify({ error: 'webhook_state_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({ status: 'recorded_failed' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (eventType === 'refund.created' || eventType === 'refund.processed') {
    const paymentId = event.payload?.refund?.entity?.payment_id;
    if (paymentId) {
      const { data: tx } = await supabase.from('business_payment_transactions').select('id').eq('provider_payment_id', paymentId).maybeSingle();
      if (tx) {
        await supabase.from('business_payment_transactions').update({ status: 'refunded' }).eq('id', tx.id);
        await supabase.from('contact_entitlements').update({ expires_at: new Date().toISOString() }).eq('transaction_id', tx.id);
      }
    }
    const processedError = await markEventProcessed();
    if (processedError) { await releaseEvent(); return new Response(JSON.stringify({ error: 'webhook_state_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }); }
    return new Response(JSON.stringify({ status: 'refund_recorded' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }

  return new Response(JSON.stringify({ status: 'ignored' }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
