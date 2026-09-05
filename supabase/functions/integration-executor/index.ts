import { createClient } from 'npm:@supabase/supabase-js@2';
import { applyMapping, buildHeaders, buildRequestUrl, redactSensitive, retryDelayMs, shouldRetry } from './executor_policy.ts';
import { HttpMcpTransport, McpAdapter } from './mcp_adapter.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const client = createClient(supabaseUrl, serviceRoleKey);
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function safeError(error: unknown) {
  return redactSensitive({ error: error instanceof Error ? error.message : String(error) });
}

async function execute(req: Request) {
  const auth = req.headers.get('Authorization');
  if (!auth) return json({ error: 'missing_auth' }, 401);
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? serviceRoleKey, { global: { headers: { Authorization: auth } } });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: 'unauthorized' }, 401);

  const { data: roles } = await client.from('user_roles').select('role').eq('user_id', user.id).is('revoked_at', null);
  if (!roles?.some((row) => row.role === 'administrator' || row.role === 'super_administrator')) return json({ error: 'admin_required' }, 403);

  const body = await req.json();
  const slug = typeof body.integration_slug === 'string' ? body.integration_slug : '';
  const actionSlug = typeof body.action_slug === 'string' ? body.action_slug : '';
  if (!slug || (!actionSlug && body.operation !== 'list_tools')) return json({ error: 'missing_action' }, 400);

  const { data: integration, error: integrationError } = await client.from('integrations').select('*').eq('slug', slug).is('archived_at', null).maybeSingle();
  if (integrationError || !integration) return json({ error: 'integration_not_found' }, 404);
  if (integration.organization_id) {
    const { data: org } = await client.from('organizations').select('id, owner_user_id, deleted_at').eq('id', integration.organization_id).maybeSingle();
    const ownsTenant = org?.owner_user_id === user.id && !org?.deleted_at;
    const isPlatformAdmin = roles?.some((row) => row.role === 'administrator' || row.role === 'super_administrator');
    if (!ownsTenant && !isPlatformAdmin) return json({ error: 'tenant_forbidden' }, 403);
    const { data: config } = await client.from('organization_configurations').select('features, configuration_version').eq('organization_id', integration.organization_id).maybeSingle();
    const features = (config?.features ?? {}) as Record<string, unknown>;
    if (features.integrations !== true) return json({ error: 'FEATURE_DISABLED', feature: 'integrations', tenant: integration.organization_id, reason: 'tenant_configuration' }, 409);
  }
  if (!integration.enabled || integration.status !== 'enabled') return json({ error: 'integration_disabled' }, 409);
  if (integration.type === 'MCP') {
    if (!integration.base_url) return json({ error: 'mcp_endpoint_missing' }, 400);
    const { data: credential } = await client.from('integration_credentials').select('secret_reference').eq('integration_id', integration.id).eq('environment', integration.environment).eq('active', true).limit(1).maybeSingle();
    const secret = credential?.secret_reference ? Deno.env.get(credential.secret_reference) : undefined;
    if (credential?.secret_reference && !secret) return json({ error: 'credential_unavailable' }, 503);
    const headers = buildHeaders(integration.configuration?.headers ?? {}, integration.authentication_type, secret, integration.configuration?.custom_header ?? 'X-API-Key');
    const adapter = new McpAdapter(new HttpMcpTransport(integration.base_url, headers, integration.configuration?.timeout_ms ?? 10000));
    try {
      if (body.operation === 'list_tools') {
        const tools = await adapter.listTools();
        for (const tool of tools) await client.from('integration_tools').upsert({ integration_id: integration.id, tool_name: tool.name, description: tool.description ?? null, input_schema: tool.inputSchema ?? {}, enabled: true, discovered_at: new Date().toISOString() }, { onConflict: 'integration_id,tool_name' });
        return json({ tools: tools.map((tool) => ({ name: tool.name, description: tool.description, input_schema: tool.inputSchema })) });
      }
      const toolName = typeof body.tool_name === 'string' ? body.tool_name : '';
      if (!toolName) return json({ error: 'missing_tool' }, 400);
      const { data: tool } = await client.from('integration_tools').select('tool_name').eq('integration_id', integration.id).eq('tool_name', toolName).eq('enabled', true).maybeSingle();
      if (!tool) return json({ error: 'tool_disabled' }, 409);
      const result = await adapter.callTool(toolName, (body.arguments ?? {}) as Record<string, unknown>);
      await client.from('integration_logs').insert({ integration_id: integration.id, request_id: crypto.randomUUID(), status: 'success', error_message: null });
      return json({ data: result });
    } catch (_) {
      await client.from('integration_logs').insert({ integration_id: integration.id, request_id: crypto.randomUUID(), status: 'failed', error_code: 'mcp_error', error_message: 'MCP request failed' });
      return json({ error: 'mcp_unavailable' }, 502);
    }
  }
  const { data: action, error: actionError } = await client.from('integration_actions').select('*').eq('integration_id', integration.id).eq('slug', actionSlug).maybeSingle();
  if (actionError || !action) return json({ error: 'action_not_found' }, 404);
  if (!action.enabled) return json({ error: 'action_disabled' }, 409);
  const testConnection = body.operation === 'test_connection';

  const query = { ...((body.input?.path ?? {}) as Record<string, unknown>), ...((body.input?.query ?? {}) as Record<string, unknown>) };
  const url = buildRequestUrl(integration.base_url ?? '', action.endpoint ?? '', query);
  const { data: credential } = await client.from('integration_credentials').select('secret_reference').eq('integration_id', integration.id).eq('environment', integration.environment).eq('active', true).limit(1).maybeSingle();
  let secret: string | undefined;
  if (credential?.secret_reference) {
    secret = Deno.env.get(credential.secret_reference);
    if (!secret) return json({ error: 'credential_unavailable' }, 503);
  }
  const headers = buildHeaders(action.headers_template ?? {}, integration.authentication_type, secret, integration.configuration?.custom_header ?? 'X-API-Key');
  if (integration.configuration?.content_type) headers.set('Content-Type', String(integration.configuration.content_type));
  const { data: mappings } = await client.from('integration_mappings').select('source_path,target_path,direction').eq('action_id', action.id).eq('enabled', true);
  const requestMappings = (mappings ?? []).filter((mapping) => mapping.direction === 'request');
  const responseMappings = (mappings ?? []).filter((mapping) => mapping.direction === 'response');
  const mappedBody = applyMapping((body.input?.body ?? {}) as Record<string, unknown>, requestMappings);

  const maxAttempts = Number(action.retry_config?.max_attempts ?? 1);
  const started = Date.now();
  let attempt = 1;
  let response: Response | undefined;
  try {
    while (attempt <= Math.min(Math.max(maxAttempts, 1), 4)) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), action.timeout_ms);
      try {
        response = await fetch(url, { method: action.method, headers, body: ['GET', 'DELETE'].includes(action.method) ? undefined : JSON.stringify(mappedBody), signal: controller.signal });
      } finally { clearTimeout(timer); }
      if (response.ok || !shouldRetry(response.status, attempt, maxAttempts)) break;
      await new Promise((resolve) => setTimeout(resolve, retryDelayMs(attempt)));
      attempt++;
    }
    const externalResult = response?.status === 204 ? null : await response?.json().catch(() => null);
    const result = externalResult && typeof externalResult === 'object'
      ? applyMapping(externalResult as Record<string, unknown>, responseMappings)
      : externalResult;
    const success = Boolean(response?.ok);
    await client.from('integration_logs').insert({ integration_id: integration.id, action_id: action.id, request_id: crypto.randomUUID(), status: success ? 'success' : 'failed', duration_ms: Date.now() - started, error_code: success ? null : `http_${response?.status ?? 599}`, error_message: success ? null : 'integration request failed' });
    if (testConnection) return json(success ? { status: 'SUCCESS' } : { status: 'SAFE_ERROR' }, success ? 200 : 502);
    return json(success ? { data: result } : { error: 'integration_request_failed' }, success ? 200 : 502);
  } catch (error) {
    await client.from('integration_logs').insert({ integration_id: integration.id, action_id: action.id, request_id: crypto.randomUUID(), status: 'failed', duration_ms: Date.now() - started, error_code: 'executor_error', error_message: String(safeError(error)) });
    return testConnection ? json({ status: 'SAFE_ERROR' }, 502) : json({ error: 'integration_unavailable' }, 502);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try { return await execute(req); } catch (_) { return json({ error: 'invalid_request' }, 400); }
});
