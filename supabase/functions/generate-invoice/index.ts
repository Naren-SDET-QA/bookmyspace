import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
// Pinned, server-only dependencies. They are never bundled into Flutter.
// @ts-ignore npm package declarations are resolved by the Supabase Edge runtime.
import { PDFDocument, StandardFonts, rgb } from 'npm:pdf-lib@1.17.1';
// @ts-ignore npm package declarations are resolved by the Supabase Edge runtime.
import QRCode from 'npm:qrcode@1.5.4';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Content-Type': 'application/json' };

function response(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers: cors }); }
function safeRef(invoiceNumber: string, bookingRef: string) { return `BMS-INVOICE:${invoiceNumber}:${bookingRef}`; }

async function authorised(client: SupabaseClient, authHeader: string, booking: any, userId: string) {
  if (booking.user_id === userId) return true;
  const { data: roles } = await client.from('user_roles').select('role').eq('user_id', userId).is('revoked_at', null);
  if ((roles ?? []).some((r: any) => ['administrator', 'super_administrator'].includes(r.role))) return true;
  const { data: org } = await client.from('organizations').select('owner_user_id').eq('id', booking.venues?.org_id).maybeSingle();
  return org?.owner_user_id === userId;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const auth = req.headers.get('Authorization');
  if (!auth) return response({ error: 'missing_auth' }, 401);
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') ?? '', { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return response({ error: 'unauthorized' }, 401);
  const admin = createClient(url, serviceKey);
  try {
    const { booking_id } = await req.json();
    if (!booking_id) return response({ error: 'missing_booking_id' }, 400);
    const { data: booking, error: bookingError } = await admin.from('bookings')
      .select('id, booking_ref, user_id, status, amount, tax_amount, total_amount, currency, book_date, start_time, end_time, venues(name, city, org_id), payments(id, status, provider_payment_id, amount, currency, created_at)')
      .eq('id', booking_id).single();
    if (bookingError || !booking) return response({ error: 'booking_not_found' }, 404);
    if (!await authorised(admin, auth, booking, user.id)) return response({ error: 'forbidden' }, 403);
    if (!['confirmed', 'completed', 'refunded', 'no_show'].includes(booking.status)) return response({ error: 'booking_not_invoiceable' }, 409);
    const payment = (booking.payments ?? []).find((p: any) => ['captured', 'refunded', 'partially_refunded'].includes(p.status)) ?? (booking.payments ?? [])[0];
    const invoiceNumber = `BMS-${new Date().getUTCFullYear()}-${String(booking.booking_ref).replace(/[^A-Za-z0-9]/g, '').slice(-12)}`;
    const { data: existing } = await admin.from('invoice_documents').select('*').eq('booking_id', booking.id).maybeSingle();
    if (existing?.status === 'generated' && existing.storage_path) {
      const { data: signed } = await admin.storage.from('invoices').createSignedUrl(existing.storage_path, 900);
      return response({ invoice: existing, signed_url: signed?.signedUrl ?? null });
    }
    const { data: invoice, error: invoiceError } = await admin.from('invoice_documents').upsert({ invoice_number: existing?.invoice_number ?? invoiceNumber, booking_id: booking.id, payment_id: payment?.id ?? null, status: 'pending' }, { onConflict: 'booking_id' }).select().single();
    if (invoiceError || !invoice) return response({ error: 'invoice_claim_failed' }, 500);
    const verify = safeRef(invoice.invoice_number, booking.booking_ref);
    const qrPng = await QRCode.toBuffer(verify, { type: 'png', width: 180, margin: 1 });
    const pdf = await PDFDocument.create();
    const page = pdf.addPage([595, 842]);
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
    const qr = await pdf.embedPng(qrPng);
    const text = (value: string, x: number, y: number, size = 11, isBold = false) => page.drawText(value.slice(0, 180), { x, y, size, font: isBold ? bold : font, color: rgb(0.12, 0.16, 0.25) });
    text('BOOKMYSPACE', 48, 790, 22, true); text('TAX INVOICE / PAYMENT RECEIPT', 48, 760, 13, true);
    text(`Invoice: ${invoice.invoice_number}`, 48, 725); text(`Booking: ${booking.booking_ref}`, 48, 706);
    text(`Property: ${booking.venues?.name ?? 'BookMySpace venue'}`, 48, 670, 12, true); text(`Location: ${booking.venues?.city ?? ''}`, 48, 650);
    text(`Date: ${booking.book_date}`, 48, 615); text(`Time: ${String(booking.start_time).slice(0, 5)} - ${String(booking.end_time).slice(0, 5)}`, 48, 595);
    text(`Base amount: ${booking.currency} ${booking.amount}`, 48, 540); text(`Tax/GST: ${booking.currency} ${booking.tax_amount}`, 48, 520); text(`Total: ${booking.currency} ${booking.total_amount}`, 48, 485, 13, true);
    text(`Payment reference: ${payment?.provider_payment_id ?? 'offline'}`, 48, 445); text(`Verification reference: ${verify}`, 48, 405, 9);
    page.drawImage(qr, { x: 400, y: 480, width: 130, height: 130 });
    text('This document contains no payment secrets. Verify using the reference above.', 48, 90, 9);
    const bytes = await pdf.save();
    const path = `${booking.user_id}/${booking.id}/${invoice.invoice_number}.pdf`;
    const upload = await admin.storage.from('invoices').upload(path, bytes, { contentType: 'application/pdf', upsert: true });
    if (upload.error) { await admin.from('invoice_documents').update({ status: 'failed', error_message: 'storage_upload_failed' }).eq('id', invoice.id); return response({ error: 'invoice_storage_failed' }, 500); }
    const { data: generated, error: generatedError } = await admin.from('invoice_documents').update({ storage_path: path, status: 'generated', generated_at: new Date().toISOString(), error_message: null }).eq('id', invoice.id).select().single();
    if (generatedError || !generated) return response({ error: 'invoice_finalize_failed' }, 500);
    const { data: signed } = await admin.storage.from('invoices').createSignedUrl(path, 900);
    const { data: customer } = await admin.auth.admin.getUserById(booking.user_id);
    if (customer.user?.email) await admin.from('email_outbox').upsert({ event_key: `invoice.generated.customer.${invoice.id}`, event_type: 'invoice.generated', recipient_email: customer.user.email, recipient_name: String(customer.user.user_metadata?.full_name ?? ''), booking_id: booking.id, payment_id: payment?.id ?? null, invoice_id: invoice.id, template_name: 'invoice-generated', payload: { invoice_number: invoice.invoice_number, booking_ref: booking.booking_ref, amount: booking.total_amount }, attachment_metadata: [{ bucket: 'invoices', path, filename: `${invoice.invoice_number}.pdf` }], status: 'pending', next_attempt_at: new Date().toISOString() }, { onConflict: 'event_key', ignoreDuplicates: true });
    return response({ invoice: generated, signed_url: signed?.signedUrl ?? null });
  } catch (_) { return response({ error: 'invoice_generation_failed' }, 500); }
});
