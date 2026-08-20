export function bookingDecision(
  booking: { user_id: string; status: string } | null,
  userId: string,
): 'booking_not_found' | 'not_authorized' | 'ok' {
  if (!booking) return 'booking_not_found';
  if (booking.user_id !== userId || booking.status !== 'pending') {
    return 'not_authorized';
  }
  return 'ok';
}

export function amountDecision(
  suppliedAmount: unknown,
  authoritativeAmount: number,
): 'ok' | 'amount_mismatch' {
  if (suppliedAmount == null) return 'ok';
  return Math.abs(Number(suppliedAmount) - authoritativeAmount) > 0.01
    ? 'amount_mismatch'
    : 'ok';
}

export function pendingOrderResponse(
  payment: { provider_order_id?: string | null; amount: number; currency?: string | null } | null,
) {
  if (!payment?.provider_order_id) return null;
  return {
    order_id: payment.provider_order_id,
    amount: Number(payment.amount),
    currency: payment.currency ?? 'INR',
  };
}

export function insertFailure(error: { code?: string | null }) {
  return error.code === '23505'
    ? { error: 'payment_duplicate', status: 409 }
    : { error: 'payment_insert_failed', status: 500 };
}

export function claimFailure(error: { code?: string | null } | null, claim: unknown) {
  if (!error && claim) return { error: null, status: 200 };
  if (error?.code === '23505') return { error: 'payment_in_progress', status: 409 };
  return { error: 'payment_claim_failed', status: 500 };
}

export function canFailClaim(
  claimId: string,
  currentClaimId: string,
  status: string,
  providerOrderId: string | null,
) {
  return claimId === currentClaimId && status === 'pending' && providerOrderId == null;
}
