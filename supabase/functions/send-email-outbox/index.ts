import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { renderEmail } from '../_shared/email_templates.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const provider = Deno.env.get('EMAIL_PROVIDER') ?? 'disabled';
const resendKey = Deno.env.get('RESEND_API_KEY') ?? '';
const sender = Deno.env.get('EMAIL_FROM') ?? '';
const cors = { 'Content-Type': 'application/json' };

async function sendWithProvider(job: Record<string, any>): Promise<void> {
  if (provider === 'mock') return;
  if (provider !== 'resend' || !resendKey || !sender) throw new Error('email_provider_not_configured');
  const rendered = renderEmail(job.template_name, job.payload ?? {});
  const attachments = [];
  const storageClient = createClient(url, serviceKey);
  for (const item of (job.attachment_metadata ?? [])) {
    if (!item?.bucket || !item?.path) continue;
    const { data, error } = await storageClient.storage.from(String(item.bucket)).download(String(item.path));
    if (error || !data) throw new Error('email_attachment_unavailable');
    const bytes = new Uint8Array(await data.arrayBuffer());
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    attachments.push({ filename: String(item.filename ?? 'attachment.pdf'), content: btoa(binary) });
  }
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: sender, to: [job.recipient_email], subject: rendered.subject, html: rendered.html, ...(attachments.length ? { attachments } : {}) }),
  });
  if (!response.ok) throw new Error(`email_provider_http_${response.status}`);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const client: SupabaseClient = createClient(url, serviceKey);
  const { data: jobs, error } = await client.rpc('claim_email_outbox_batch', { p_limit: 10 });
  if (error) return new Response(JSON.stringify({ error: 'claim_failed' }), { status: 500, headers: cors });
  let sent = 0;
  for (const job of jobs ?? []) {
    try {
      await sendWithProvider(job);
      await client.rpc('set_email_outbox_result', { p_id: job.id, p_status: 'sent' });
      sent++;
    } catch (error) {
      const safe = error instanceof Error ? error.message.slice(0, 200) : 'email_send_failed';
      await client.rpc('set_email_outbox_result', { p_id: job.id, p_status: 'failed', p_error: safe, p_retry_after_seconds: Math.min(3600, 30 * (2 ** Math.min(job.attempts, 7))) });
    }
  }
  return new Response(JSON.stringify({ claimed: jobs?.length ?? 0, sent, provider }), { status: 200, headers: cors });
});
