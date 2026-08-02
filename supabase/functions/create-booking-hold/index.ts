// Deno edge function: create a booking hold atomically on the server.
//
// Called from the Flutter app AFTER the user picks a venue/date/slot and
// BEFORE payment. Returns the hold id + expiry so the client can start
// the Razorpay flow.
//
// POST body:
// {
//   venue_id, slot_id, book_date, idempotency_key,
//   amount, hold_minutes?
// }
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Authorise via the user's JWT (RLS-safe identity).
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

  // Resolve the authenticated user id from the JWT.
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const { venue_id, slot_id, book_date, idempotency_key, amount, hold_minutes } = body;

    if (!venue_id || !slot_id || !book_date || !idempotency_key || !amount) {
      return new Response(JSON.stringify({ error: 'missing_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Server-side amount validation: always re-fetch the authoritative price.
    const { data: slot, error: slotError } = await supabase
      .from('time_slots')
      .select('id, price_amount')
      .eq('id', slot_id)
      .single();
    if (slotError || !slot) {
      return new Response(JSON.stringify({ error: 'invalid_slot' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (Math.abs(Number(amount) - Number(slot.price_amount)) > 0.01) {
      return new Response(JSON.stringify({ error: 'amount_mismatch' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Atomic hold acquisition in the database.
    const { data: holdId, error: holdError } = await supabase.rpc(
      'acquire_booking_hold',
      {
        p_venue_id: venue_id,
        p_slot_id: slot_id,
        p_book_date: book_date,
        p_user_id: user.id,
        p_idempotency_key: idempotency_key,
        p_amount: amount,
        p_hold_minutes: hold_minutes ?? 10,
      },
    );
    if (holdError) {
      const msg = holdError.message?.includes('slot unavailable')
        ? 'slot_unavailable'
        : 'hold_failed';
      return new Response(JSON.stringify({ error: msg }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({ hold_id: holdId, expires_in_minutes: hold_minutes ?? 10 }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: 'internal', detail: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
