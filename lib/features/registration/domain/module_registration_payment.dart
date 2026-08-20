enum ModuleRegistrationPaymentStatus {
  notRequired,
  pending,
  processing,
  paid,
  failed,
  refunded,
  partiallyRefunded,
}

ModuleRegistrationPaymentStatus registrationPaymentStatus(String value) =>
    switch (value) {
      'not_required' => ModuleRegistrationPaymentStatus.notRequired,
      'processing' => ModuleRegistrationPaymentStatus.processing,
      'paid' => ModuleRegistrationPaymentStatus.paid,
      'failed' => ModuleRegistrationPaymentStatus.failed,
      'refunded' => ModuleRegistrationPaymentStatus.refunded,
      'partially_refunded' => ModuleRegistrationPaymentStatus.partiallyRefunded,
      _ => ModuleRegistrationPaymentStatus.pending,
    };
