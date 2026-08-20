import { SupabaseClient } from 'npm:@supabase/supabase-js@2';

export type EmailEvent = {
  eventKey: string;
  eventType: string;
  recipientEmail: string;
  recipientName?: string | null;
  bookingId?: string | null;
  paymentId?: string | null;
  refundId?: string | null;
  invoiceId?: string | null;
  templateName: string;
  payload?: Record<string, unknown>;
  attachmentMetadata?: unknown[];
};

export function deterministicEmailKey(eventType: string, subjectId: string, audience: string): string {
  return `${eventType}.${audience}.${subjectId}`;
}

export async function enqueueEmail(client: SupabaseClient, event: EmailEvent): Promise<boolean> {
  const { error } = await client.from('email_outbox').upsert({
    event_key: event.eventKey,
    event_type: event.eventType,
    recipient_email: event.recipientEmail,
    recipient_name: event.recipientName ?? null,
    booking_id: event.bookingId ?? null,
    payment_id: event.paymentId ?? null,
    refund_id: event.refundId ?? null,
    invoice_id: event.invoiceId ?? null,
    template_name: event.templateName,
    payload: event.payload ?? {},
    attachment_metadata: event.attachmentMetadata ?? [],
    status: 'pending',
    next_attempt_at: new Date().toISOString(),
  }, { onConflict: 'event_key', ignoreDuplicates: true });
  return !error;
}

export async function userEmail(client: SupabaseClient, userId: string): Promise<{ email: string; name: string } | null> {
  const { data, error } = await client.auth.admin.getUserById(userId);
  if (error || !data.user?.email) return null;
  return { email: data.user.email, name: String(data.user.user_metadata?.full_name ?? data.user.user_metadata?.name ?? '') };
}
