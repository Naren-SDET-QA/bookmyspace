import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../auth_providers.dart';
import '../otp_controller.dart';

/// Authentication entry screen.
///
/// Supports email OTP, phone OTP and Google / Apple social sign-in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _OtpChannel { email, phone }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpInputKey = GlobalKey<FormFieldState<String>>();

  _OtpChannel _channel = _OtpChannel.email;
  bool _otpSent = false;
  bool _busy = false;
  bool _otpBusy = false;
  String? _error;
  final _otpState = OtpController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _otpState.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _passwordEmailController.dispose();
    _passwordController.dispose();
    _otpState.dispose();
    super.dispose();
  }

  /// Navigates away after a successful sign-in.
  ///
  /// If this screen was reached via `push` (e.g. a "Sign in to continue"
  /// prompt from a screen such as the booking flow) there is a previous
  /// route to return to, and popping back to it preserves whatever state
  /// that screen was holding. Otherwise (reached via the router's own
  /// auth redirect, or the login tab) there is nothing to pop back to, so
  /// this falls back to the existing behaviour of going to the shell.
  void _onSignedIn() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.shell);
    }
  }

  Future<void> _sendOtp() async {
    if (_otpSent && !_otpState.canResend) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final contact = _contactController.text.trim();
      if (_channel == _OtpChannel.email) {
        await repo.signInWithEmailOtp(contact);
      } else {
        await repo.signInWithPhoneOtp(contact);
      }
      _otpState.sent();
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpInputKey.currentState!.validate()) return;
    setState(() {
      _otpBusy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final contact = _contactController.text.trim();
      final token = _otpController.text.trim();
      final user = _channel == _OtpChannel.email
          ? await repo.verifyEmailOtp(contact, token)
          : await repo.verifyPhoneOtp(contact, token);
      if (user.id.isNotEmpty && mounted) {
        _otpState.success();
        _onSignedIn();
      }
    } catch (e) {
      _otpState.invalid();
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _otpBusy = false);
    }
  }

  Future<void> _passwordLogin() async {
    final email = _passwordEmailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.errorRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signInWithPassword(email, password);
      if (user.id.isNotEmpty && mounted) _onSignedIn();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _socialSignIn(Future<dynamic> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action.call();
      if (mounted) _onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleChannel() {
    setState(() {
      _channel = _channel == _OtpChannel.email
          ? _OtpChannel.phone
          : _OtpChannel.email;
      _otpSent = false;
      _otpController.clear();
      _contactController.clear();
    });
  }

  String? _validateContact(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.errorRequired;
    if (_channel == _OtpChannel.email) {
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
      return ok ? null : l10n.errorInvalidEmail;
    }
    final ok = RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v);
    return ok ? null : l10n.errorInvalidPhone;
  }

  String? _validateOtp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.errorRequired;
    return RegExp(r'^\d{6}$').hasMatch(v) ? null : l10n.errorRequired;
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmail = _channel == _OtpChannel.email;
    final authConfig = ref.watch(authConfigurationProvider).valueOrNull;
    if (authConfig == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!authConfig.authenticationEnabled) {
      return Scaffold(body: Center(child: Text(l10n.authUnavailable)));
    }
    final emailOtp = authConfig.canUseEmailOtp;
    final phoneOtp = authConfig.canUsePhone;
    final password = authConfig.canUsePassword;
    final canOtp = emailOtp || phoneOtp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 72,
                    color: AppTheme.brand,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (authConfig.canUseGoogle)
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _socialSignIn(
                              ref.read(authRepositoryProvider).signInWithGoogle,
                            ),
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: Text(l10n.continueWithGoogle),
                    ),
                  const SizedBox(height: 16),
                  if (authConfig.canUseApple)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _socialSignIn(
                              ref.read(authRepositoryProvider).signInWithApple,
                            ),
                      icon: const Icon(Icons.apple_rounded),
                      label: Text(l10n.continueWithApple),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l10n.orDivider,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (canOtp)
                    SegmentedButton<_OtpChannel>(
                      segments: [
                        if (emailOtp)
                          ButtonSegment(
                            value: _OtpChannel.email,
                            label: Text(l10n.email),
                          ),
                        if (phoneOtp)
                          ButtonSegment(
                            value: _OtpChannel.phone,
                            label: Text(l10n.phone),
                          ),
                      ],
                      selected: {_channel},
                      onSelectionChanged: (s) => _toggleChannel(),
                    ),
                  if (canOtp) const SizedBox(height: 16),
                  if (canOtp)
                    TextFormField(
                      controller: _contactController,
                      enabled: !_busy && !_otpSent,
                      keyboardType: isEmail
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: isEmail ? l10n.email : l10n.phone,
                        prefixIcon: Icon(
                          isEmail ? Icons.mail_outline : Icons.phone_outlined,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validateContact,
                    ),
                  if (canOtp) const SizedBox(height: 16),
                  if (canOtp)
                    FilledButton.tonalIcon(
                      onPressed: _busy || (_otpSent && !_otpState.canResend)
                          ? null
                          : _sendOtp,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sms_outlined),
                      label: Text(_otpSent ? l10n.resendOtp : l10n.sendOtp),
                    ),
                  if (_otpSent && canOtp) ...[
                    const SizedBox(height: 8),
                    Text(
                      _otpState.resendSeconds > 0
                          ? l10n.otpSentResendIn(_otpState.resendSeconds)
                          : l10n.otpSent,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: _otpInputKey,
                      controller: _otpController,
                      enabled: !_otpBusy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: l10n.otpPlaceholder,
                        prefixIcon: const Icon(Icons.verified_outlined),
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: _validateOtp,
                      onFieldSubmitted: (_) => _verifyOtp(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _otpBusy ? null : _verifyOtp,
                      child: _otpBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.verifyOtp),
                    ),
                    TextButton(
                      onPressed: _otpState.canResend && !_busy
                          ? _sendOtp
                          : null,
                      child: Text(
                        _otpState.canResend
                            ? l10n.resendOtp
                            : l10n.otpResendIn(_otpState.resendSeconds),
                      ),
                    ),
                  ],
                  if (password) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordEmailController,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _passwordLogin,
                      child: Text(l10n.login),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.push(AppRoutes.forgotPassword),
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (authConfig.signupEnabled)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.push(AppRoutes.unifiedRegistration),
                      child: Text(l10n.createProfile),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go(AppRoutes.shell),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
