import 'dart:async';

import 'package:flutter/foundation.dart';

enum OtpStatus {
  idle,
  sending,
  sent,
  verifying,
  success,
  invalid,
  expired,
  rateLimited,
  networkError,
}

class OtpController extends ChangeNotifier {
  OtpStatus status = OtpStatus.idle;
  int resendSeconds = 0;
  Timer? _timer;

  bool get canResend => resendSeconds == 0;

  void sending() => _set(OtpStatus.sending);

  void sent({int countdown = 30}) {
    _set(OtpStatus.sent);
    _timer?.cancel();
    resendSeconds = countdown.clamp(0, 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds <= 1) {
        resendSeconds = 0;
        timer.cancel();
      } else {
        resendSeconds--;
      }
      notifyListeners();
    });
  }

  void verifying() => _set(OtpStatus.verifying);
  void success() {
    _timer?.cancel();
    resendSeconds = 0;
    _set(OtpStatus.success);
  }

  void invalid() => _set(OtpStatus.invalid);
  void expired() => _set(OtpStatus.expired);
  void rateLimited() => _set(OtpStatus.rateLimited);
  void networkError() => _set(OtpStatus.networkError);

  void reset() {
    _timer?.cancel();
    resendSeconds = 0;
    _set(OtpStatus.idle);
  }

  void _set(OtpStatus value) {
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
