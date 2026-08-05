import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../domain/auth_user.dart';
import '../auth_providers.dart';
import '../widgets/otp_panel.dart';

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
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Brand gradient header (prototype `--grad`) ----
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '📍',
                          style: TextStyle(
                            fontSize: 36,
                            fontFamilyFallback: AppTheme.emojiFontFallbacks,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'BookMySpace',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome back 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to discover, book and celebrate.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (socialAuthEnabled) ...[
                        _SocialButton(
                          icon: Icons.g_mobiledata_rounded,
                          label: l10n.continueWithGoogle,
                          onPressed: _busy
                              ? null
                              : () => _socialSignIn(
                                  ref.read(
                                    authRepositoryProvider,
                                  ).signInWithGoogle,
                                ),
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          icon: Icons.apple_rounded,
                          label: l10n.continueWithApple,
                          onPressed: _busy
                              ? null
                              : () => _socialSignIn(
                                  ref.read(
                                    authRepositoryProvider,
                                  ).signInWithApple,
                                ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'OR',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Google and Apple sign-in are unavailable in local mode. Use email OTP below.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (AppConfig.developmentTestLoginEnabled) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PrototypeVisuals.badgeFeatBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFE3A8),
                            ),
                          ),
                          child: Text(
                            'TEST MODE',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
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
                        const SizedBox(height: 8),
                      ],
                      // ---- Contact channel toggle ----
                      _ChannelToggle(
                        channel: _channel,
                        onChanged: _toggleChannel,
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
                          hintText: isEmail
                              ? 'you@example.com'
                              : '98XXXXXXXX',
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
                      // ---- Send code ----
                      PrototypeButton(
                        label: _resendSeconds > 0
                            ? 'Resend code in ${_resendSeconds}s'
                            : _otpSent
                            ? l10n.resendOtp
                            : l10n.sendOtp,
                        onPressed: _busy || _resendSeconds > 0
                            ? null
                            : _sendOtp,
                        icon: Icons.sms_outlined,
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        OtpPanel(
                          otpController: _otpController,
                          otpFieldKey: _otpInputKey,
                          verifyLabel: l10n.verifyOtp,
                          onVerify: _verifyOtp,
                          busy: _otpBusy,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New here?',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.go(AppRoutes.signup),
                            child: Text(
                              l10n.signUp,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.go(AppRoutes.forgotPassword),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({required this.channel, required this.onChanged});

  final _OtpChannel channel;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _toggle(context, _OtpChannel.email, 'Email'),
          _toggle(context, _OtpChannel.phone, 'Phone'),
        ],
      ),
    );
  }

  Widget _toggle(BuildContext context, _OtpChannel value, String label) {
    final selected = channel == value;
    return Expanded(
      child: GestureDetector(
        onTap: onChanged,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppTheme.ink : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppTheme.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.ink),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
