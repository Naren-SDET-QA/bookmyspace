import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Content-Type': 'application/json' };
const allowed = new Set(['SEARCH', 'AVAILABILITY', 'RESOURCE_DETAILS', 'GET_HELP', 'GET_OFFER', 'BOOKING_PREVIEW', 'BOOKING_HANDOFF', 'BOOKING_STATUS', 'REFUND_STATUS', 'GET_INVOICE', 'GET_QR', 'CREATE_HOLD', 'CONFIRM_BOOKING', 'CANCEL_BOOKING', 'REFUND_REQUEST']);
const mutations = new Set(['CREATE_HOLD', 'CONFIRM_BOOKING', 'CANCEL_BOOKING', 'REFUND_REQUEST']);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });

function error(error_code: string, status = 400, extra: Record<string, unknown> = {}) {
  return json({ error_code, ...extra }, status);
}

async function authenticatedClient(req: Request) {
  const authorization = req.headers.get('Authorization');
  if (!authorization || !authorization.startsWith('Bearer ')) throw new Error('UNAUTHENTICATED');
  const client = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user } } = await client.auth.getUser();
  if (!user) throw new Error('UNAUTHENTICATED');
  return { client, user };
}

async function featureEnabled(client: any, categoryId: string | null, feature: string) {
  if (!categoryId) return true;
  const { data } = await client.from('venue_categories').select('metadata').eq('id', categoryId).maybeSingle();
  if (!data) throw new Error('CATEGORY_DISABLED');
  const metadata = (data.metadata ?? {}) as Record<string, unknown>;
  if (metadata.active === false) throw new Error('CATEGORY_DISABLED');
  const nested = metadata.features as Record<string, unknown> | undefined;
  const keyByFeature: Record<string, string> = {
    SEARCH: 'searchable',
    AVAILABILITY: 'availability_enabled',
    GET_OFFER: 'offers_enabled',
    BOOKING_PREVIEW: 'bookable',
    BOOKING_HANDOFF: 'bookable',
    CREATE_HOLD: 'bookable',
    CONFIRM_BOOKING: 'bookable',
    CANCEL_BOOKING: 'bookable',
    REFUND_REQUEST: 'payments_enabled',
  };
  const key = keyByFeature[feature] ?? feature;
  const value = metadata[key] ?? metadata[feature] ?? nested?.[key] ?? nested?.[feature];
  return value !== false;
}

async function availableSlot(client: any, venueId: string, date: string, slotId: string) {
  const { data, error: availabilityError } = await client.rpc('available_time_slots', {
    p_venue_id: venueId,
    p_book_date: date,
  });
  if (availabilityError) throw availabilityError;
  return ((data ?? []) as Array<Record<string, unknown>>)
    .find((slot) => slot.slot_id === slotId && slot.is_available === true) ?? null;
}

async function handle(body: Record<string, unknown>, client: any, userId: string) {
  const action = String(body.action ?? body.intent ?? '').toUpperCase();
  if (!allowed.has(action)) return error('INVALID_ACTION');
  if (mutations.has(action) && body.confirmed !== true) return error('CONFIRMATION_REQUIRED', 409);
  const categoryId = body.category_id == null ? null : String(body.category_id);
  if (!(await featureEnabled(client, categoryId, action))) return error('FEATURE_DISABLED', 403);
  if (!(await featureEnabled(client, categoryId, 'ai_chat'))) return error('FEATURE_DISABLED');
  const limit = Math.min(Math.max(Number(body.limit ?? 20), 1), 50);

  if (action === 'BOOKING_HANDOFF') {
    const venueId = body.venue_id;
    const slotId = body.slot_id;
    const bookDate = body.book_date ?? body.date;
    if (body.confirmed !== true) return error('CONFIRMATION_REQUIRED', 409);
    if (!venueId || !slotId || !bookDate) {
      return error('MISSING_FIELDS', 422, { fields: ['venue_id', 'slot_id', 'book_date'] });
    }
    const [{ data: venue, error: venueError }, slot] = await Promise.all([
      client.from('venues').select('id,category_id').eq('id', String(venueId)).eq('is_active', true).maybeSingle(),
      availableSlot(client, String(venueId), String(bookDate), String(slotId)),
    ]);
    if (venueError) throw venueError;
    if (!venue || !slot) return error('SLOT_UNAVAILABLE', 409);
    return json({ action, handoff: { user_id: userId, venue_id: venue.id, slot_id: slot.slot_id, book_date: String(bookDate), category_id: venue.category_id } });
  }

  if (action === 'SEARCH') {
    let query = client.from('venues').select('id,name,org_id,category_id,city,state,pricing_base_amount,avg_rating,is_verified').eq('is_active', true).limit(limit);
    if (categoryId) query = query.eq('category_id', categoryId);
    if (body.location != null) query = query.ilike('city', `%${String(body.location).slice(0, 80)}%`);
    const { data, error: queryError } = await query;
    if (queryError) throw queryError;
    return json({ action, results: data ?? [] });
  }
  if (action === 'RESOURCE_DETAILS') {
    const id = body.venue_id;
    if (!id) return error('RESOURCE_NOT_FOUND', 404);
    const { data, error: queryError } = await client.from('venues').select('id,name,org_id,category_id,city,state,description,pricing_base_amount,avg_rating,is_verified').eq('id', String(id)).eq('is_active', true).maybeSingle();
    if (queryError) throw queryError;
    return data ? json({ action, resource: data }) : error('RESOURCE_NOT_FOUND', 404);
  }
  if (action === 'AVAILABILITY') {
    const venueId = body.venue_id;
    if (!venueId || !body.date) return error('MISSING_FIELDS', 422, { fields: ['venue_id', 'date'] });
    const { data, error: queryError } = await client.rpc('available_time_slots', {
      p_venue_id: String(venueId),
      p_book_date: String(body.date),
    });
    if (queryError) throw queryError;
    return json({ action, availability: (data ?? []).filter((slot: Record<string, unknown>) => slot.is_available === true).slice(0, limit) });
  }
  if (action === 'BOOKING_PREVIEW') {
    const venueId = body.venue_id;
    const slotId = body.slot_id;
    const date = body.date;
    if (!venueId || !slotId || !date) return error('MISSING_FIELDS', 422, { fields: ['venue_id', 'slot_id', 'date'] });
    const [{ data: venue, error: venueError }, slot] = await Promise.all([
      client.from('venues').select('id,name,tax_rate,is_active').eq('id', String(venueId)).eq('is_active', true).maybeSingle(),
      availableSlot(client, String(venueId), String(date), String(slotId)),
    ]);
    if (venueError) throw venueError;
    if (!venue || !slot) return error('SLOT_UNAVAILABLE', 409);
    const amount = Number(slot.price_amount ?? 0);
    const taxAmount = Math.round(amount * Number(venue.tax_rate ?? 0)) / 100;
    return json({ action, preview: { venue: { id: venue.id, name: venue.name }, slot: { id: slot.slot_id, date: String(date), label: slot.label, start_time: slot.start_time, end_time: slot.end_time }, quantity: 1, pricing: { amount, tax_amount: taxAmount, fee_amount: 0, discount_amount: 0, total_amount: amount + taxAmount, currency: 'INR' }, requires_confirmation: true } });
  }
  if (action === 'CONFIRM_BOOKING') return json({ action, authorized: true, user_id: userId });
  if (action === 'BOOKING_STATUS') {
    const { data, error: queryError } = await client.from('bookings').select('id,booking_ref,venue_id,status,book_date,total_amount,currency,created_at').eq('user_id', userId).order('created_at', { ascending: false }).limit(limit);
    if (queryError) throw queryError;
    return json({ action, bookings: data ?? [] });
  }
  if (action === 'REFUND_STATUS') {
    const { data: bookings, error: bookingError } = await client.from('bookings').select('id').eq('user_id', userId).limit(50);
    if (bookingError) throw bookingError;
    const ids = (bookings ?? []).map((row: any) => row.id);
    if (!ids.length) return json({ action, refunds: [] });
    const { data, error: queryError } = await client.from('refunds').select('id,booking_id,amount,status,provider_refund_id,created_at,processed_at').in('booking_id', ids).limit(limit);
    if (queryError) throw queryError;
    return json({ action, refunds: data ?? [] });
  }
  if (action === 'GET_INVOICE') {
    const bookingId = body.booking_id;
    if (!bookingId) return error('MISSING_FIELDS', 422, { fields: ['booking_id'] });
    const { data, error: queryError } = await client.from('invoice_documents').select('id,invoice_number,booking_id,status,generated_at').eq('booking_id', String(bookingId)).limit(1).maybeSingle();
    if (queryError) throw queryError;
    return data ? json({ action, invoice: data }) : error('RESOURCE_NOT_FOUND', 404);
  }
  if (action === 'GET_QR') {
    const bookingId = body.booking_id;
    if (!bookingId) return error('MISSING_FIELDS', 422, { fields: ['booking_id'] });
    const { data, error: queryError } = await client.from('booking_check_ins').select('id,booking_id,method,created_at').eq('booking_id', String(bookingId)).limit(1).maybeSingle();
    if (queryError) throw queryError;
    return data ? json({ action, qr: data }) : error('RESOURCE_NOT_FOUND', 404);
  }
  if (action === 'GET_HELP') {
    const { data, error: queryError } = await client.from('help_articles').select('id,category,title,summary,steps,language').eq('enabled', true).is('archived_at', null).order('sort_order').limit(limit);
    if (queryError) throw queryError;
    return json({ action, articles: data ?? [] });
  }
  if (action === 'GET_OFFER') {
    const now = new Date().toISOString();
    let query = client.from('coupons')
      .select('id,code,description,discount_type,discount_value,max_discount_amount,min_booking_amount,starts_at,ends_at,metadata')
      .eq('is_active', true)
      .or(`starts_at.is.null,starts_at.lte.${now}`)
      .or(`ends_at.is.null,ends_at.gte.${now}`)
      .order('ends_at', { ascending: true, nullsFirst: false })
      .limit(limit);
    const { data, error: queryError } = await query;
    if (queryError) throw queryError;
    const requestedVenue = body.venue_id == null ? null : String(body.venue_id);
    const requestedCategory = categoryId;
    const offers = (data ?? [])
      .filter((row: any) => {
        const metadata = (row.metadata ?? {}) as Record<string, unknown>;
        const targetCategory = metadata.category_id == null ? null : String(metadata.category_id);
        const targetVenue = metadata.venue_id == null ? null : String(metadata.venue_id);
        return (!targetCategory || targetCategory === requestedCategory) &&
          (!targetVenue || targetVenue === requestedVenue);
      })
      .map((row: any) => ({
        id: row.id,
        code: row.code,
        title: row.metadata?.title ?? row.description ?? row.code,
        description: row.description,
        discount_type: row.discount_type,
        discount_value: row.discount_value,
        max_discount_amount: row.max_discount_amount,
        min_booking_amount: row.min_booking_amount,
        starts_at: row.starts_at,
        ends_at: row.ends_at,
      }));
    return json({ action, offers });
  }
  return error('PROVIDER_UNAVAILABLE', 503);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return error('INVALID_ACTION', 405);
  try {
    const length = Number(req.headers.get('content-length') ?? 0);
    if (length > 64_000) return error('RATE_LIMITED', 413);
    const { client, user } = await authenticatedClient(req);
    return await handle(await req.json() as Record<string, unknown>, client, user.id);
  } catch (caught) {
    const code = caught instanceof Error && ['UNAUTHENTICATED', 'CATEGORY_DISABLED'].includes(caught.message) ? caught.message : 'PROVIDER_UNAVAILABLE';
    return error(code, code === 'UNAUTHENTICATED' ? 401 : 503);
  }
});
