import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../auth_providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.watch(authStateProvider);
    final hasSession = ref.read(authRepositoryProvider).currentUser != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _done
                ? Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.brand,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.passwordUpdated,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.passwordUpdatedMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: Text(l10n.backToLogin),
                      ),
                    ],
                  )
                : hasSession
                ? Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.resetPasswordPrompt,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const Key('reset_password_field'),
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: l10n.newPassword,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: AppValidators.password,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('reset_password_confirm_field'),
                          controller: _confirmController,
                          obscureText: !_showPassword,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: l10n.confirmPassword,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => AppValidators.confirmPassword(
                            _passwordController.text,
                            value,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('reset_password_submit'),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.resetPassword),
                        ),
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
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(AppRoutes.login),
                          child: Text(l10n.backToLogin),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        l10n.invalidResetLink,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: Text(l10n.backToLogin),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
