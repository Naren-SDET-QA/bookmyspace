import { createClient } from 'npm:@supabase/supabase-js@2';
import { alertIsDue, metricsWindow, nextRecoveryState } from './observability_policy.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const adminClient = createClient(url, serviceKey);
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Content-Type': 'application/json' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });

async function requireActor(req: Request, body: Record<string, unknown>) {
  const authorization = req.headers.get('Authorization');
  if (!authorization) throw new Error('unauthorized');
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') ?? serviceKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) throw new Error('unauthorized');
  const { data: roles } = await adminClient.from('user_roles').select('role').eq('user_id', user.id).is('revoked_at', null);
  const isPlatformAdmin = !!roles?.some((row) => row.role === 'administrator' || row.role === 'super_administrator');
  const organizationId = body.organization_id == null ? null : String(body.organization_id);
  const categoryId = body.category_id == null ? null : String(body.category_id);
  if (isPlatformAdmin) return { user, isPlatformAdmin, organizationId, categoryId };
  if (!organizationId) throw new Error('organization_scope_required');
  const { data: organization } = await adminClient.from('organizations').select('id').eq('id', organizationId).eq('owner_user_id', user.id).eq('is_active', true).maybeSingle();
  if (!organization) throw new Error('organization_forbidden');
  if (categoryId) {
    const [{ data: venue }, { data: configured }] = await Promise.all([
      adminClient.from('venues').select('id').eq('org_id', organizationId).eq('category_id', categoryId).limit(1).maybeSingle(),
      adminClient.from('organization_category_configurations').select('organization_id').eq('organization_id', organizationId).eq('category_id', categoryId).limit(1).maybeSingle(),
    ]);
    if (!venue && !configured) throw new Error('category_forbidden');
  }
  return { user, isPlatformAdmin, organizationId, categoryId };
}

async function evaluateAlerts(scope: { isPlatformAdmin: boolean; organizationId: string | null; categoryId: string | null }) {
  let query = adminClient.from('alert_rules').select('id,organization_id,category_id,feature,threshold,duration_seconds,enabled').eq('enabled', true).limit(200);
  if (!scope.isPlatformAdmin && scope.organizationId) query = query.eq('organization_id', scope.organizationId);
  if (scope.categoryId) query = query.eq('category_id', scope.categoryId);
  const { data: rules, error } = await query;
  if (error) throw error;
  const triggered: string[] = [];
  for (const rule of rules ?? []) {
    const since = new Date(Date.now() - Math.max(Number(rule.duration_seconds ?? 300), 1) * 1000).toISOString();
    let errorsQuery = adminClient.from('error_events').select('id', { count: 'exact', head: true }).eq('feature', rule.feature).gte('created_at', since);
    if (rule.organization_id) errorsQuery = errorsQuery.eq('organization_id', rule.organization_id);
    if (rule.category_id) errorsQuery = errorsQuery.eq('category_id', rule.category_id);
    const { count } = await errorsQuery;
    const { data: previous } = await adminClient.from('recovery_events').select('created_at').eq('feature', rule.feature).eq('action', `alert:${rule.id}`).order('created_at', { ascending: false }).limit(1).maybeSingle();
    if (!alertIsDue({ enabled: true, threshold: Number(rule.threshold), value: count ?? 0, lastTriggeredAt: previous?.created_at ? new Date(previous.created_at) : null, cooldownSeconds: Number(rule.duration_seconds ?? 300) }, new Date())) continue;
    await adminClient.from('recovery_events').insert({ feature: rule.feature, action: `alert:${rule.id}`, status: 'triggered', correlation_id: String(rule.id), details: { count: count ?? 0, organization_id: rule.organization_id } });
    triggered.push(String(rule.id));
  }
  return { triggered };
}

async function metrics(range: string, scope: { isPlatformAdmin: boolean; organizationId: string | null; categoryId: string | null }) {
  const since = new Date(Date.now() - metricsWindow(range) * 1000).toISOString();
  // Keep the generated Supabase query-builder type from recursively expanding
  // through this small reusable scope helper (TS2589). The runtime contract is
  // unchanged: only organization/category predicates are appended here.
  const scoped = (query: any): any => {
    if (!scope.isPlatformAdmin && scope.organizationId) query = query.eq('organization_id', scope.organizationId);
    if (scope.categoryId) query = query.eq('category_id', scope.categoryId);
    return query;
  };
  const [{ count: errors }, { count: recoveries }, { count: alerts }, { data: checks }] = await Promise.all([
    scoped(adminClient.from('error_events').select('id', { count: 'exact', head: true }).gte('created_at', since)),
    scoped(adminClient.from('recovery_events').select('id', { count: 'exact', head: true }).gte('created_at', since)),
    scoped(adminClient.from('recovery_events').select('id', { count: 'exact', head: true }).like('action', 'alert:%').gte('created_at', since)),
    scoped(adminClient.from('health_checks').select('response_ms').gte('checked_at', since).limit(1000)),
  ]);
  const values = (checks ?? []).map((row: { response_ms?: unknown }) => Number(row.response_ms)).filter((value: number) => Number.isFinite(value));
  return { range, errors: errors ?? 0, recoveries: recoveries ?? 0, alerts: alerts ?? 0, average_latency_ms: values.length ? values.reduce((a: number, b: number) => a + b, 0) / values.length : 0 };
}

async function recover(body: Record<string, unknown>) {
  const feature = String(body.feature ?? 'unknown');
  const provider = body.provider == null ? null : String(body.provider);
  const organizationId = body.organization_id == null ? null : String(body.organization_id);
  const categoryId = body.category_id == null ? null : String(body.category_id);
  const correlation = String(body.correlation_id ?? crypto.randomUUID());
  const { data: events } = await adminClient.from('recovery_events').select('status,details').eq('feature', feature).eq('correlation_id', correlation).order('created_at', { ascending: false }).limit(1);
  const latest = events?.[0];
  const attempts = Number((latest?.details as Record<string, unknown> | undefined)?.attempts ?? 0);
  const state = nextRecoveryState(String(latest?.status ?? 'HEALTHY'), attempts, Math.min(Number(body.max_retries ?? 3), 4));
  await adminClient.from('observability_recovery_state').upsert({ organization_id: organizationId, category_id: categoryId, component: feature, provider, state, failure_count: attempts, retry_count: state === 'RETRYING' ? attempts + 1 : attempts, opened_at: state === 'CIRCUIT_OPEN' ? new Date().toISOString() : null, next_retry_at: state === 'CIRCUIT_OPEN' ? new Date(Date.now() + 60_000).toISOString() : null, last_success_at: state === 'HEALTHY' ? new Date().toISOString() : null, last_error: body.error == null ? null : 'redacted', updated_at: new Date().toISOString() }, { onConflict: 'organization_id,category_id,component,provider' });
  await adminClient.from('recovery_events').insert({ feature, action: 'recovery', status: state, correlation_id: correlation, details: { attempts: state === 'RETRYING' ? attempts + 1 : attempts } });
  return { state, correlation_id: correlation };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    const body = await req.json() as Record<string, unknown>;
    const scope = await requireActor(req, body);
    if (body.operation === 'evaluate_alerts') return json(await evaluateAlerts(scope));
    if (body.operation === 'metrics') return json(await metrics(String(body.range ?? '24h'), scope));
    if (body.operation === 'recover') return json(await recover({...body, organization_id: scope.organizationId, category_id: scope.categoryId}));
    return json({ error: 'unsupported_operation' }, 400);
  } catch (error) {
    const message = error instanceof Error && ['unauthorized', 'admin_required', 'organization_scope_required', 'organization_forbidden', 'category_forbidden'].includes(error.message) ? error.message : 'observability_unavailable';
    return json({ error: message }, message === 'unauthorized' ? 401 : 403);
  }
});
