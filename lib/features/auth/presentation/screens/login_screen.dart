import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/test_mode.dart';
import '../../../../core/debug/debug_log.dart';
import '../../../../core/debug/test_accounts.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    if (TestMode.debugMenuEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final account = ref.read(selectedTestAccountProvider);
        if (account == null) return;
        final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(account.email);
        setState(() {
          _channel = isEmail ? _OtpChannel.email : _OtpChannel.phone;
          _otpSent = false;
          _contactController.text =
              isEmail ? account.email : (account.phone ?? account.email);
        });
        DebugLog.info(
          'TEST',
          'Prefilled login with test account ${account.role}',
          detail: isEmail ? account.email : (account.phone ?? account.email),
        );
      });
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
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
        context.go(AppRoutes.shell);
      }
    } catch (e) {
      setState(() => _error = e.toString());
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
                  const SizedBox(height: 40),
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
                    onPressed: _busy ? null : _sendOtp,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sms_outlined),
                    label: Text(_otpSent ? l10n.resendOtp : l10n.sendOtp),
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
