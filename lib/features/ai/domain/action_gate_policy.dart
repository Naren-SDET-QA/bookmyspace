enum UniversalAction {
  search,
  availability,
  resourceDetails,
  price,
  createHold,
  confirmBooking,
  bookingStatus,
  cancelBooking,
  refundStatus,
  getInvoice,
  getQr,
  getHelp,
  getOffer,
}

enum ActionGateError {
  unauthenticated,
  confirmationRequired,
  unauthorizedInput,
}

class ActionGateResult {
  const ActionGateResult._({this.error});
  const ActionGateResult.allowed() : this._();
  const ActionGateResult.denied(ActionGateError error) : this._(error: error);
  final ActionGateError? error;
  bool get allowed => error == null;
}

class ActionGatePolicy {
  static const _mutating = {
    UniversalAction.createHold,
    UniversalAction.confirmBooking,
    UniversalAction.cancelBooking,
  };

  static const _protectedFields = {
    'user_id',
    'organization_id',
    'tenant_id',
    'venue_id',
    'category_id',
    'resource_id',
    'price',
    'tax',
    'total',
    'discount',
    'refund_amount',
    'role',
    'permissions',
  };

  static ActionGateResult check({
    required UniversalAction action,
    required bool authenticated,
    bool confirmed = false,
    Map<String, dynamic> suppliedFields = const {},
  }) {
    if (!authenticated) return const ActionGateResult.denied(ActionGateError.unauthenticated);
    if (_mutating.contains(action) && !confirmed) {
      return const ActionGateResult.denied(ActionGateError.confirmationRequired);
    }
    if (suppliedFields.keys.any(_protectedFields.contains)) {
      return const ActionGateResult.denied(ActionGateError.unauthorizedInput);
    }
    return const ActionGateResult.allowed();
  }
}
