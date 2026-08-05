import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../auth_providers.dart';
import '../widgets/otp_panel.dart';

/// Prototype-style password recovery. Because the app authenticates with
/// one-time codes, "forgot password" verifies identity via an email OTP,
/// then lets the user continue into their account.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpInputKey = GlobalKey<FormFieldState<String>>();

  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithEmailOtp(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      _otpController.clear();
      _otpInputKey.currentState?.reset();
      setState(() => _otpSent = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AppException ? e.message : e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpInputKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).verifyEmailOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      if (user.id.isNotEmpty && mounted) {
        context.go(AppRoutes.shell);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.errorRequired;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
        ? null
        : l10n.errorInvalidEmail;
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Reset password',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Forgot your password?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your email and we’ll send you a one-time code to sign back in.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  enabled: !_busy && !_otpSent,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppTheme.muted,
                    ),
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppTheme.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppTheme.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppTheme.brand,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),
                PrototypeButton(
                  label: _otpSent ? 'Send new code' : 'Send code',
                  onPressed: _busy ? null : _sendOtp,
                  icon: Icons.sms_outlined,
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  OtpPanel(
                    otpController: _otpController,
                    otpFieldKey: _otpInputKey,
                    verifyLabel: 'Recover account',
                    onVerify: _verifyOtp,
                    onResend: _sendOtp,
                    busy: _busy,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _busy ? null : () => context.go(AppRoutes.login),
                  child: Text(
                    'Back to login',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
