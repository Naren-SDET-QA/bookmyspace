export function renderEmail(template: string, payload: Record<string, unknown>): { subject: string; html: string } {
  const title = String(payload.title ?? (template === 'invoice-generated' ? 'Invoice available' : 'BookMySpace update'));
  const message = String(payload.message ?? 'There is an update to your BookMySpace booking.');
  const reference = payload.booking_ref ? `<p><strong>Booking:</strong> ${escapeHtml(String(payload.booking_ref))}</p>` : '';
  const amount = payload.amount ? `<p><strong>Amount:</strong> ${escapeHtml(String(payload.amount))}</p>` : '';
  const invoice = payload.invoice_number ? `<p><strong>Invoice:</strong> ${escapeHtml(String(payload.invoice_number))}</p>` : '';
  const subject = template === 'invoice-generated'
    ? `BookMySpace - Invoice ${String(payload.invoice_number ?? '')}`
    : `BookMySpace - ${title}`;
  return {
    subject,
    html: `<!doctype html><html><body style="margin:0;background:#f5f7fb;font-family:Arial,sans-serif;color:#172033"><div style="max-width:600px;margin:24px auto;background:#fff;padding:32px;border-radius:12px"><h1 style="color:#3155d9">BookMySpace</h1><h2>${escapeHtml(title)}</h2><p>${escapeHtml(message)}</p>${invoice}${reference}${amount}<hr><p style="font-size:12px;color:#68738a">This is an automated BookMySpace email. Please do not reply with payment credentials.</p></div></body></html>`,
  };
}

function escapeHtml(value: string): string {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
