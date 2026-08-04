import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_user.dart';
import '../auth_providers.dart';

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
  final _otpInputKey = GlobalKey<FormFieldState<String>>();

  _OtpChannel _channel = _OtpChannel.email;
  bool _otpSent = false;
  bool _busy = false;
  bool _otpBusy = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  String? _error;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _contactController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_busy || _resendSeconds > 0) return;
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
      if (!mounted) return;
      _otpController.clear();
      _otpInputKey.currentState?.reset();
      setState(() => _otpSent = true);
      _startResendCooldown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AppException ? e.message : e.toString();
          if (e is AppException && e.code == 'over_email_send_rate_limit') {
            _error =
                'Too many code requests. Please wait a minute and try again.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
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
        context.go(AppRoutes.shell);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _otpBusy = false);
    }
  }

  Future<void> _socialSignIn(Future<dynamic> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action.call();
      if (mounted) context.go(AppRoutes.shell);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _developmentTestLogin(AppAccessRole expectedRole) async {
    if (!AppConfig.developmentTestLoginEnabled || _busy) return;
    final roleName = expectedRole.name;
    final credentials = AppConfig.developmentTestCredentials[roleName];
    if (credentials == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithPassword(credentials.email, credentials.password);
      final actualRole = await repo.resolveAccessRole();
      if (actualRole != expectedRole) {
        await repo.signOut();
        throw AppError(
          'Role mismatch: this account is ${actualRole.name}, not $roleName.',
        );
      }
      if (!mounted) return;
      context.go(switch (actualRole) {
        AppAccessRole.customer => AppRoutes.shell,
        AppAccessRole.owner => AppRoutes.ownerDashboard,
        AppAccessRole.admin => AppRoutes.adminDashboard,
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
      _resendTimer?.cancel();
      _resendSeconds = 0;
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
    final socialAuthEnabled = AppConfig.environment != AppEnvironment.local;

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
                  if (AppConfig.developmentTestLoginEnabled) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'TEST MODE',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final role in AppAccessRole.values)
                      if (AppConfig.developmentTestCredentials.containsKey(
                        role.name,
                      )) ...[
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _developmentTestLogin(role),
                          icon: const Icon(Icons.science_outlined),
                          label: Text(
                            '${role.name[0].toUpperCase()}${role.name.substring(1)} Test Login',
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _busy || !socialAuthEnabled
                        ? null
                        : () => _socialSignIn(
                            ref.read(authRepositoryProvider).signInWithGoogle,
                          ),
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: Text(l10n.continueWithGoogle),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy || !socialAuthEnabled
                        ? null
                        : () => _socialSignIn(
                            ref.read(authRepositoryProvider).signInWithApple,
                          ),
                    icon: const Icon(Icons.apple_rounded),
                    label: Text(l10n.continueWithApple),
                  ),
                  const SizedBox(height: 24),
                  if (!socialAuthEnabled) ...[
                    Text(
                      'Google and Apple sign-in are unavailable in local mode. Use email OTP below.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: theme.textTheme.labelLarge),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<_OtpChannel>(
                    segments: [
                      ButtonSegment(
                        value: _OtpChannel.email,
                        label: Text(l10n.email),
                      ),
                      ButtonSegment(
                        value: _OtpChannel.phone,
                        label: Text(l10n.phone),
                      ),
                    ],
                    selected: {_channel},
                    onSelectionChanged: (s) => _toggleChannel(),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _busy || _resendSeconds > 0 ? null : _sendOtp,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sms_outlined),
                    label: Text(
                      _resendSeconds > 0
                          ? 'Resend code in ${_resendSeconds}s'
                          : _otpSent
                          ? l10n.resendOtp
                          : l10n.sendOtp,
                    ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.otpSent,
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
