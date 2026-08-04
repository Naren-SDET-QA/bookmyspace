import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import { verifyRazorpaySignature } from '../_shared/razorpay_signature.ts';

const secret = 'test_webhook_secret';
const body = '{"event":"payment.captured","id":"evt_test"}';
const valid = createHmac('sha256', secret).update(body).digest('hex');

test('accepts a valid Razorpay HMAC', async () => {
  assert.equal(await verifyRazorpaySignature(body, valid, secret), true);
});

test('rejects invalid, missing, and malformed signatures', async () => {
  assert.equal(await verifyRazorpaySignature(body, '0'.repeat(64), secret), false);
  assert.equal(await verifyRazorpaySignature(body, '', secret), false);
  assert.equal(await verifyRazorpaySignature(body, 'not-hex', secret), false);
});

test('signature is bound to the exact raw body', async () => {
  assert.equal(await verifyRazorpaySignature(`${body} `, valid, secret), false);
});
