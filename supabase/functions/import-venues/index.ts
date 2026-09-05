import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(url, service);
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const clean = (v: unknown) => typeof v === 'string' ? v.trim() : '';
function escapeRx(v: string) { return v.replace(/[\\"{}()[\].+*?$^|]/g, '\\$&'); }
function validate(body: unknown) { const b = body as Record<string, unknown> | null; const state=clean(b?.state), city=clean(b?.city ?? b?.town), category=clean(b?.category); if (!state || !city || !category || state.length>120 || city.length>120 || category.length>80) return null; return { state, city, category }; }
async function handler(req: Request) {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const auth = req.headers.get('authorization'); if (!auth?.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await userClient.auth.getUser(); if (!user) return json({ error: 'unauthorized' }, 401);
  const { data: roles } = await admin.from('user_roles').select('role').eq('user_id', user.id).is('revoked_at', null);
  if (!(roles ?? []).some((r) => ['administrator', 'super_administrator', 'venue_manager'].includes(r.role))) return json({ error: 'forbidden' }, 403);
  const input = validate(await req.json().catch(() => null)); if (!input) return json({ error: 'invalid_request' }, 400);
  const { data: job, error: jobError } = await admin.from('venue_discovery_jobs').insert({ requested_state: input.state, requested_city: input.city, requested_category: input.category, source: 'osm', status: 'RUNNING' }).select('id').single();
  if (jobError) return json({ error: 'job_create_failed' }, 500);
  try {
    const query = `[out:json][timeout:25];area["name"="${input.state}"]->.state;(nwr["name"](area.state)["amenity"~"${escapeRx(input.category)}",i];nwr["name"](area.state)["leisure"~"${escapeRx(input.category)}",i];);out center tags;`;
    const response = await fetch('https://overpass-api.de/api/interpreter', { method: 'POST', body: new URLSearchParams({ data: query }), signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error(`overpass_http_${response.status}`);
    const payload = await response.json(); if (!Array.isArray(payload?.elements)) throw new Error('malformed_overpass_response');
    let staged=0, duplicates=0; const discovered: Record<string, unknown>[] = [];
    for (const element of payload.elements) {
      const tags = element.tags ?? {}; const lat=Number(element.lat ?? element.center?.lat), lon=Number(element.lon ?? element.center?.lon), name=clean(tags.name); const id=element.id == null ? '' : `${element.type ?? 'element'}/${element.id}`;
      if (!name || !id || !Number.isFinite(lat) || !Number.isFinite(lon)) continue;
      discovered.push({ source:'osm', sourcePlaceId:id, name, address:tags['addr:full'] ?? null, city:tags['addr:city'] ?? null, state:tags['addr:state'] ?? null, phone:tags.phone ?? null, website:tags.website ?? null, openingHours:tags.opening_hours ?? null, category:input.category, latitude:lat, longitude:lon, sourceUrl:`https://www.openstreetmap.org/${element.type}/${element.id}`, rawMetadata:tags });
      const { data: existing } = await admin.from('venue_discovery_staging').select('id').eq('source','osm').eq('source_place_id',id).maybeSingle(); if (existing) duplicates++;
      const { error } = await admin.rpc('stage_discovered_venue', { p_source:'osm', p_source_place_id:id, p_name:name, p_address:tags['addr:full'] ?? null, p_city:tags['addr:city'] ?? null, p_district:tags['addr:district'] ?? null, p_state:tags['addr:state'] ?? null, p_latitude:lat, p_longitude:lon, p_phone:tags.phone ?? null, p_website:tags.website ?? null, p_category:input.category, p_source_url:`https://www.openstreetmap.org/${element.type}/${element.id}`, p_raw_metadata:tags, p_job_id:job.id }); if (!error && !existing) staged++;
    }
    await admin.from('venue_discovery_jobs').update({ status:'COMPLETED', completed_at:new Date().toISOString(), discovered_count:payload.elements.length, staged_count:staged, duplicate_count:duplicates }).eq('id',job.id);
    return json({ job_id: job.id, discovered_count: payload.elements.length, staged_count: staged, duplicate_count: duplicates, venues: discovered });
  } catch (e) { await admin.from('venue_discovery_jobs').update({ status:'FAILED', completed_at:new Date().toISOString(), error_message: e instanceof Error ? e.message : 'discovery_failed' }).eq('id',job.id); return json({ error:'discovery_failed', job_id:job.id }, 502); }
}
Deno.serve(handler);
