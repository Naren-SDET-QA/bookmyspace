import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../auth_providers.dart';
import '../widgets/channel_toggle.dart';
import '../widgets/otp_panel.dart';

/// Prototype-style signup. Reuses the OTP-based authentication flow —
/// an email/phone OTP creates + verifies the Supabase account.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

enum _SignupChannel { email, phone }

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpInputKey = GlobalKey<FormFieldState<String>>();

  _SignupChannel _channel = _SignupChannel.email;
  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
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
      final repo = ref.read(authRepositoryProvider);
      final contact = _contactController.text.trim();
      if (_channel == _SignupChannel.email) {
        await repo.signInWithEmailOtp(contact);
      } else {
        await repo.signInWithPhoneOtp(contact);
      }
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
      final repo = ref.read(authRepositoryProvider);
      final contact = _contactController.text.trim();
      final token = _otpController.text.trim();
      final user = _channel == _SignupChannel.email
          ? await repo.verifyEmailOtp(contact, token)
          : await repo.verifyPhoneOtp(contact, token);
      if (user.id.isNotEmpty && mounted) {
        context.go(AppRoutes.shell);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateName(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : l10n.errorRequired;

  String? _validateContact(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.errorRequired;
    if (_channel == _SignupChannel.email) {
      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
          ? null
          : l10n.errorInvalidEmail;
    }
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v)
        ? null
        : l10n.errorInvalidPhone;
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmail = _channel == _SignupChannel.email;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Create account',
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6DFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.brand,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No passwords needed — we verify with a one-time code.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy && !_otpSent,
                  autocorrect: false,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    hintText: 'e.g. Anil Kumar',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
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
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                ChannelToggle(
                  channels: const ['Email', 'Phone'],
                  selectedIndex: _channel == _SignupChannel.email ? 0 : 1,
                  onChanged: (_) {
                    setState(() {
                      _channel = _channel == _SignupChannel.email
                          ? _SignupChannel.phone
                          : _SignupChannel.email;
                      _otpSent = false;
                      _otpController.clear();
                      _contactController.clear();
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactController,
                  enabled: !_busy && !_otpSent,
                  keyboardType: isEmail
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  autocorrect: false,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: isEmail ? l10n.email : l10n.phone,
                    hintText: isEmail ? 'you@example.com' : '98XXXXXXXX',
                    prefixIcon: Icon(
                      isEmail
                          ? Icons.mail_outline_rounded
                          : Icons.phone_outlined,
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
                  validator: _validateContact,
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
                    verifyLabel: 'Create account',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.go(AppRoutes.login),
                      child: Text(
                        l10n.login,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


