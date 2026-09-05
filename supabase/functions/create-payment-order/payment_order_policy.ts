// The amount actually charged online: the venue's configured booking
// token (a partial/deposit amount, venues.booking_token_amount) when one
// is set, clamped to never exceed the booking's full price; the full
// price otherwise. A venue with no token configured (the default — there
// is currently no owner-facing UI to set one) charges in full, exactly
// as before this existed, so this is purely additive/backward-compatible.
export function resolveChargeAmount(
  totalAmount: number,
  tokenAmount: number | null | undefined,
): number {
  if (tokenAmount == null) return totalAmount;
  const token = Number(tokenAmount);
  if (!Number.isFinite(token) || token <= 0) return totalAmount;
  return Math.min(token, totalAmount);
}

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
