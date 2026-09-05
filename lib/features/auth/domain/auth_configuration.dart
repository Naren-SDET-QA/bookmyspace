class AuthConfiguration {
  const AuthConfiguration({
    this.authenticationEnabled = false,
    this.signupEnabled = false,
    this.phoneLoginEnabled = false,
    this.phoneOtpEnabled = false,
    this.emailLoginEnabled = false,
    this.emailOtpEnabled = false,
    this.passwordLoginEnabled = false,
    this.googleLoginEnabled = false,
    this.appleLoginEnabled = false,
  });

  final bool authenticationEnabled;
  final bool signupEnabled;
  final bool phoneLoginEnabled;
  final bool phoneOtpEnabled;
  final bool emailLoginEnabled;
  final bool emailOtpEnabled;
  final bool passwordLoginEnabled;
  final bool googleLoginEnabled;
  final bool appleLoginEnabled;

  bool get canUsePhone =>
      authenticationEnabled && phoneLoginEnabled && phoneOtpEnabled;
  bool get canUseEmailOtp =>
      authenticationEnabled && emailLoginEnabled && emailOtpEnabled;
  bool get canUsePassword =>
      authenticationEnabled && emailLoginEnabled && passwordLoginEnabled;
  bool get canUseGoogle => authenticationEnabled && googleLoginEnabled;
  bool get canUseApple => authenticationEnabled && appleLoginEnabled;

  factory AuthConfiguration.fromJson(Object? raw) {
    if (raw is! Map) return const AuthConfiguration();
    final map = Map<String, dynamic>.from(raw);
    bool flag(String key) => map[key] == true;
    return AuthConfiguration(
      authenticationEnabled: flag('authentication_enabled'),
      signupEnabled: flag('signup_enabled'),
      phoneLoginEnabled: flag('phone_login_enabled'),
      phoneOtpEnabled: flag('phone_otp_enabled'),
      emailLoginEnabled: flag('email_login_enabled'),
      emailOtpEnabled: flag('email_otp_enabled'),
      passwordLoginEnabled: flag('password_login_enabled'),
      googleLoginEnabled: flag('google_login_enabled'),
      appleLoginEnabled: flag('apple_login_enabled'),
    );
  }
}
