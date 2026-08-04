import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const resendKey = Deno.env.get('RESEND_API_KEY') ?? '';
const emailFrom = Deno.env.get('TRANSACTIONAL_EMAIL_FROM') ?? '';
const whatsappToken = Deno.env.get('WHATSAPP_ACCESS_TOKEN') ?? '';
const whatsappPhoneId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID') ?? '';
const whatsappTemplate = Deno.env.get('WHATSAPP_TEMPLATE_NAME') ?? '';
const whatsappLanguage = Deno.env.get('WHATSAPP_TEMPLATE_LANGUAGE') ?? 'en';
const cronSecret = Deno.env.get('NOTIFICATION_CRON_SECRET') ?? '';

Deno.serve(async (req) => {
  if (!cronSecret || req.headers.get('x-cron-secret') !== cronSecret) {
    return response({ error: 'unauthorized' }, 401);
  }
  const supabase = createClient(url, serviceKey);
  const { data: deliveries, error } = await supabase.rpc('claim_notification_deliveries', { p_limit: 25 });
  if (error) return response({ error: 'claim_failed' }, 500);
  let delivered = 0;
  for (const delivery of deliveries ?? []) {
    try {
      const { data: notification } = await supabase.from('notifications')
        .select('user_id,title,body').eq('id', delivery.notification_id).single();
      const { data: profile } = await supabase.from('profiles')
        .select('email,phone,whatsapp').eq('id', notification.user_id).single();
      if (delivery.channel === 'email') await sendEmail(profile.email, notification.title, notification.body);
      else if (delivery.channel === 'whatsapp') await sendWhatsApp(profile.whatsapp || profile.phone, notification.body);
      else throw new Error('channel_not_configured');
      await finish(supabase, delivery.id, true);
      delivered++;
    } catch (e) {
      await finish(supabase, delivery.id, false, e instanceof Error ? e.message : 'delivery_failed');
    }
  }
  return response({ claimed: deliveries?.length ?? 0, delivered }, 200);
});

async function sendEmail(to: string, subject: string, text: string) {
  if (!resendKey || !emailFrom || !to) throw new Error('email_not_configured');
  const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: {
    Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json',
  }, body: JSON.stringify({ from: emailFrom, to: [to], subject, text }), signal: AbortSignal.timeout(12_000) });
  if (!r.ok) throw new Error(`email_provider_${r.status}`);
}

async function sendWhatsApp(to: string, body: string) {
  if (!whatsappToken || !whatsappPhoneId || !to) throw new Error('whatsapp_not_configured');
  const message = whatsappTemplate
    ? { messaging_product: 'whatsapp', to: String(to).replace(/\D/g,''), type: 'template',
        template: { name: whatsappTemplate, language: { code: whatsappLanguage },
          components: [{ type: 'body', parameters: [{ type: 'text', text: body }] }] } }
    : { messaging_product: 'whatsapp', to: String(to).replace(/\D/g,''), type: 'text', text: { body } };
  const r = await fetch(`https://graph.facebook.com/v22.0/${whatsappPhoneId}/messages`, { method: 'POST', headers: {
    Authorization: `Bearer ${whatsappToken}`, 'Content-Type': 'application/json',
  }, body: JSON.stringify(message), signal: AbortSignal.timeout(12_000) });
  if (!r.ok) throw new Error(`whatsapp_provider_${r.status}`);
}

async function finish(client: ReturnType<typeof createClient>, id: string, ok: boolean, error?: string) {
  await client.rpc('complete_notification_delivery', { p_delivery_id: id, p_success: ok, p_error: error ?? null });
}
function response(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
