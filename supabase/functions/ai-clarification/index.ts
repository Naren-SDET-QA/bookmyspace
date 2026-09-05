import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Content-Type': 'application/json' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
const fail = (error_code: string, status = 400, fields: string[] = []) => json({ error_code, ...(fields.length ? { fields } : {}) }, status);
const states = new Set(['NEW', 'WAITING_FOR_FIELD', 'WAITING_FOR_CLARIFICATION', 'READY', 'EXPIRED', 'CANCELLED']);
async function observe(client: any, event: string, userId: string, categoryId?: string) {
  try {
    await client.from('analytics_events').insert({ event_type: event, user_id: userId, properties: { category_id: categoryId ?? null, source: 'ai_clarification' } });
  } catch (_) { /* observability is non-authoritative */ }
}

function safeFields(metadata: Record<string, unknown>) {
  const raw = Array.isArray(metadata.fields) ? metadata.fields : [];
  return raw.filter((item) => item && typeof item === 'object' && typeof (item as Record<string, unknown>).key === 'string')
    .map((item) => { const field = item as Record<string, unknown>; return { key: field.key, label: field.label ?? field.key, type: field.type ?? 'text', required: field.required === true, options: Array.isArray(field.options) ? field.options.slice(0, 100) : [], validation: typeof field.validation === 'object' && field.validation ? field.validation : {} }; });
}

function active(field: Record<string, unknown>, answers: Record<string, unknown>) {
  const when = field.validation as Record<string, unknown>;
  if (!when || typeof when.when !== 'object' || !when.when) return true;
  const condition = when.when as Record<string, unknown>;
  return answers[condition.field as string]?.toString() === condition.equals?.toString();
}

function validate(fields: Record<string, unknown>[], answers: Record<string, unknown>) {
  const allowed = new Set(fields.map((field) => String(field.key)));
  for (const key of Object.keys(answers)) if (!allowed.has(key)) return { error: 'INVALID_FIELD', field: key };
  const missing = fields.filter((field) => field.required === true && active(field, answers) && (answers[String(field.key)] == null || answers[String(field.key)] === '')).map((field) => String(field.key));
  for (const field of fields) {
    if (!active(field, answers) || answers[String(field.key)] == null) continue;
    const options = Array.isArray(field.options) ? field.options : [];
    if (options.length && (field.type === 'dropdown' || field.type === 'radio') && !options.map(String).includes(String(answers[String(field.key)]))) return { error: 'INVALID_OPTION', field: field.key };
  }
  return missing.length ? { error: 'MISSING_FIELDS', fields: missing } : { error: null, fields: [] };
}

async function auth(req: Request): Promise<{ client: any; user: { id: string } }> {
  const bearer = req.headers.get('Authorization');
  if (!bearer?.startsWith('Bearer ')) throw new Error('UNAUTHENTICATED');
  const client = createClient(url, anonKey, { global: { headers: { Authorization: bearer } } });
  const { data: { user } } = await client.auth.getUser();
  if (!user) throw new Error('UNAUTHENTICATED');
  return { client, user };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers });
  if (req.method !== 'POST') return fail('INVALID_REQUEST', 405);
  try {
    if (Number(req.headers.get('content-length') ?? 0) > 64_000) return fail('REQUEST_TOO_LARGE', 413);
    const body = await req.json() as Record<string, unknown>;
    const { client, user } = await auth(req);
    const action = String(body.action ?? '').toUpperCase();
    if (!['START_CLARIFICATION', 'GET_CLARIFICATION', 'SUBMIT_ANSWER', 'CORRECT_ANSWER', 'CANCEL_CLARIFICATION'].includes(action)) return fail('INVALID_ACTION');
    const sessionId = body.session_id == null ? null : String(body.session_id);
    if (action !== 'START_CLARIFICATION' && !sessionId) return fail('INVALID_SESSION', 422);
    if (action === 'START_CLARIFICATION') {
      const request = String(body.request ?? '').slice(0, 500);
      const { data: categories, error } = await client.from('venue_categories').select('id,slug,name,metadata').limit(100);
      if (error) throw error;
      const normalized = request.toLowerCase().replaceAll('_', ' ');
      const matches = (categories ?? []).filter((category: any) => { const metadata = (category.metadata ?? {}) as Record<string, unknown>; const aliases = [category.slug, category.name, ...(Array.isArray(metadata.aliases) ? metadata.aliases : []), ...(Array.isArray(metadata.ai_aliases) ? metadata.ai_aliases : [])].map(String); return metadata.active !== false && aliases.some((alias) => normalized.includes(alias.toLowerCase().replaceAll('_', ' '))); });
      if (!matches.length) return fail('CATEGORY_NOT_FOUND', 404);
      if (matches.length > 1) return fail('CATEGORY_CLARIFICATION_REQUIRED', 409);
      const category = matches[0];
      await observe(client, 'clarification_started', user.id, category.id);
      await observe(client, 'category_discovered', user.id, category.id);
      const fields = safeFields((category.metadata ?? {}) as Record<string, unknown>);
      const key = crypto.randomUUID();
      const expires = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      const result = validate(fields, {});
      const state = result.error === 'MISSING_FIELDS' ? 'WAITING_FOR_FIELD' : 'READY';
      const { data, error: insertError } = await client.from('ai_clarification_sessions').insert({ user_id: user.id, session_key: key, category_id: category.id, category_slug: category.slug, state, answers: {}, expires_at: expires }).select('id,session_key,category_id,category_slug,state,answers,expires_at').single();
      if (insertError) throw insertError;
      return json({ status: state === 'READY' ? 'READY' : 'MISSING_FIELDS', session: data, category: { id: category.id, slug: category.slug, name: category.name }, fields, missing_fields: result.fields });
    }
    const { data: session, error: sessionError } = await client.from('ai_clarification_sessions').select('id,session_key,category_id,category_slug,state,answers,expires_at').eq('id', sessionId).eq('user_id', user.id).maybeSingle();
    if (sessionError) throw sessionError;
    if (!session) return fail('NOT_FOUND', 404);
    if (new Date(session.expires_at) <= new Date() && !['EXPIRED', 'CANCELLED'].includes(session.state)) {
      const { data: expired } = await client.from('ai_clarification_sessions').update({ state: 'EXPIRED', updated_at: new Date().toISOString() }).eq('id', session.id).eq('user_id', user.id).neq('state', 'EXPIRED').select('id').maybeSingle();
      if (expired) await observe(client, 'clarification_expired', user.id, session.category_id);
      return fail('EXPIRED', 410);
    }
    if (session.state === 'EXPIRED' || session.state === 'CANCELLED') return fail(session.state, 410);
    if (action === 'GET_CLARIFICATION') return json({ status: session.state, session });
    if (action === 'CANCEL_CLARIFICATION') { await client.from('ai_clarification_sessions').update({ state: 'CANCELLED', updated_at: new Date().toISOString() }).eq('id', session.id).eq('user_id', user.id); return json({ status: 'CANCELLED' }); }
    const { data: category, error: categoryError } = await client.from('venue_categories').select('id,slug,name,metadata').eq('id', session.category_id).maybeSingle();
    if (categoryError) throw categoryError;
    if (!category || (category.metadata as Record<string, unknown> | null)?.active === false) return fail('FEATURE_DISABLED', 403);
    const fields = safeFields((category.metadata ?? {}) as Record<string, unknown>);
    const key = String(body.field ?? '');
    if (!fields.some((field) => field.key === key)) return fail('INVALID_FIELD', 422, [key]);
    const answers = { ...((session.answers ?? {}) as Record<string, unknown>), [key]: body.value };
    const result = validate(fields, answers);
    await observe(client, 'answer_submitted', user.id, category.id);
    if (result.error) await observe(client, 'validation_failed', user.id, category.id);
    const nextState = result.error ? 'WAITING_FOR_FIELD' : 'READY';
    const { error: updateError } = await client.from('ai_clarification_sessions').update({ answers, state: nextState, updated_at: new Date().toISOString() }).eq('id', session.id).eq('user_id', user.id);
    if (updateError) throw updateError;
    await observe(client, result.error ? 'field_requested' : 'clarification_completed', user.id, category.id);
    return json({ status: result.error ? 'MISSING_FIELDS' : 'READY', session_id: session.id, answers, fields, missing_fields: result.fields ?? [], ...(result.error ? { error_code: result.error } : {}) });
  } catch (error) {
    const code = error instanceof Error && ['UNAUTHENTICATED'].includes(error.message) ? error.message : 'SAFE_ERROR';
    return fail(code, code === 'UNAUTHENTICATED' ? 401 : 400);
  }
});
