const encoder = new TextEncoder();

export async function verifyRazorpaySignature(
  rawBody: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  if (!rawBody || !signature || !secret || !/^[0-9a-f]{64}$/i.test(signature)) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody)),
  );
  const supplied = hexToBytes(signature);
  if (supplied.length !== digest.length) return false;
  let difference = 0;
  for (let i = 0; i < digest.length; i++) difference |= digest[i] ^ supplied[i];
  return difference === 0;
}

function hexToBytes(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(value.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}
