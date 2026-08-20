import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const keyId = Deno.env.get('RAZORPAY_KEY_ID')!;
const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')!;
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status, headers:{...cors,'Content-Type':'application/json'}});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  const authorization = req.headers.get('Authorization');
  if (!authorization) return json({error:'missing_auth'}, 401);
  const auth = createClient(url, anon, {global:{headers:{Authorization:authorization}}});
  const {data:{user}} = await auth.auth.getUser();
  if (!user) return json({error:'unauthorized'}, 401);
  const admin: SupabaseClient = createClient(url, service);
  try {
    const body = await req.json();
    const venueId = typeof body.venue_id === 'string' ? body.venue_id : '';
    const field = typeof body.feature === 'string' ? body.feature : '';
    if (!venueId || !['phone','whatsapp','email'].includes(field)) return json({error:'invalid_fields'}, 400);

    const {data: venue} = await admin.from('venues').select('id,org_id,is_active').eq('id', venueId).maybeSingle();
    if (!venue || venue.is_active !== true) return json({error:'invalid_venue'}, 404);
    const {data: pricing, error: pricingError} = await admin.from('pricing_features').select('feature_key,name,amount_minor,currency,version,pricing_model,duration_days').eq('feature_key', `${field.toUpperCase()}_REVEAL`).eq('is_active', true).order('version', {ascending:false}).limit(1).maybeSingle();
    if (pricingError || !pricing) return json({error:'pricing_unavailable'}, 409);
    const {data: owner} = await admin.from('organizations').select('owner_user_id').eq('id', venue.org_id).maybeSingle();
    const {data: existing} = await admin.from('business_payment_transactions').select('id,provider_order_id,amount_minor,currency,status').eq('customer_user_id', user.id).eq('venue_id', venueId).eq('field_key', field).eq('status','pending').maybeSingle();
    if (existing?.provider_order_id) return json({order_id: existing.provider_order_id, amount: Number(existing.amount_minor), currency: existing.currency});
    const {data: claim, error: claimError} = await admin.from('business_payment_transactions').insert({customer_user_id:user.id,venue_id:venueId,owner_user_id:owner?.owner_user_id ?? null,field_key:field,pricing_feature_key:pricing.feature_key,price_version:pricing.version,amount_minor:pricing.amount_minor,currency:pricing.currency}).select('id').single();
    if (claimError || !claim) return json({error: claimError?.code === '23505' ? 'payment_in_progress' : 'payment_claim_failed'}, claimError?.code === '23505' ? 409 : 500);
    const response = await fetch('https://api.razorpay.com/v1/orders', {method:'POST',headers:{Authorization:`Basic ${btoa(`${keyId}:${keySecret}`)}`,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({amount:String(pricing.amount_minor),currency:pricing.currency,receipt:`contact_${claim.id}`})});
    if (!response.ok) { await admin.from('business_payment_transactions').update({status:'failed'}).eq('id',claim.id).eq('status','pending'); return json({error:'payment_order_failed'}, 502); }
    const order = await response.json();
    await admin.from('business_payment_transactions').update({provider_order_id:order.id}).eq('id',claim.id).eq('status','pending');
    return json({order_id:order.id, amount:Number(pricing.amount_minor), currency:pricing.currency});
  } catch (_) { return json({error:'internal'}, 500); }
});
