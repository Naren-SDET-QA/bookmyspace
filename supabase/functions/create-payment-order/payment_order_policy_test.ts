import {
  amountDecision,
  bookingDecision,
  canFailClaim,
  claimFailure,
  insertFailure,
  pendingOrderResponse,
} from './payment_order_policy.ts';

Deno.test('booking authorization rejects missing and non-pending bookings', () => {
  if (bookingDecision(null, 'user-1') !== 'booking_not_found') throw new Error('missing booking');
  if (bookingDecision({ user_id: 'user-2', status: 'pending' }, 'user-1') !== 'not_authorized') {
    throw new Error('wrong owner accepted');
  }
  if (bookingDecision({ user_id: 'user-1', status: 'confirmed' }, 'user-1') !== 'not_authorized') {
    throw new Error('non-pending booking accepted');
  }
  if (bookingDecision({ user_id: 'user-1', status: 'pending' }, 'user-1') !== 'ok') {
    throw new Error('valid booking rejected');
  }
});

Deno.test('amount validation uses the authoritative booking amount', () => {
  if (amountDecision(null, 413) !== 'ok') throw new Error('omitted amount rejected');
  if (amountDecision(413, 413) !== 'ok') throw new Error('matching amount rejected');
  if (amountDecision(412, 413) !== 'amount_mismatch') throw new Error('mismatch accepted');
});

Deno.test('existing pending order is reused', () => {
  const response = pendingOrderResponse({
    provider_order_id: 'order_test',
    amount: 413,
    currency: 'INR',
  });
  if (response?.order_id !== 'order_test' || response.amount !== 413) {
    throw new Error('pending order was not reused');
  }
  if (pendingOrderResponse(null) !== null) throw new Error('empty payment reused');
});

Deno.test('only unique violations map to duplicate; other DB errors remain failures', () => {
  const duplicate = insertFailure({ code: '23505' });
  if (duplicate.error !== 'payment_duplicate' || duplicate.status !== 409) {
    throw new Error('unique violation mapping changed');
  }
  const rls = insertFailure({ code: '42501' });
  if (rls.error !== 'payment_insert_failed' || rls.status !== 500) {
    throw new Error('RLS error was mislabeled');
  }
});

Deno.test('atomic claim distinguishes in-progress retry from claim failure', () => {
  const success = claimFailure(null, { id: 'claim-1' });
  if (success.error !== null) throw new Error('successful claim rejected');
  const concurrent = claimFailure({ code: '23505' }, null);
  if (concurrent.error !== 'payment_in_progress' || concurrent.status !== 409) {
    throw new Error('concurrent claim was not reported as in progress');
  }
  const failed = claimFailure({ code: '42501' }, null);
  if (failed.error !== 'payment_claim_failed' || failed.status !== 500) {
    throw new Error('claim failure was mislabeled');
  }
});

Deno.test('claim cleanup is scoped to the current pending claim', () => {
  if (!canFailClaim('claim-1', 'claim-1', 'pending', null)) {
    throw new Error('current claim was not cleanable');
  }
  if (canFailClaim('claim-1', 'claim-2', 'pending', null)) {
    throw new Error('another request claim was cleanable');
  }
  if (canFailClaim('claim-1', 'claim-1', 'failed', null)) {
    throw new Error('failed claim was changed');
  }
  if (canFailClaim('claim-1', 'claim-1', 'pending', 'order_test')) {
    throw new Error('persisted provider order was changed');
  }
});
