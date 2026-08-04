import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../owner/presentation/owner_providers.dart';
import '../../domain/auth_callback.dart';
import '../../domain/auth_user.dart';
import '../auth_providers.dart';

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key, this.callbackUri});

  final Uri? callbackUri;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  final _emailController = TextEditingController();
  bool _resending = false;
  bool _resent = false;
  bool _finishing = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _finish(AuthUser user) async {
    if (_finishing) return;
    _finishing = true;
    try {
      final client = ref.read(supabaseProvider);
      final metadata = client.auth.currentUser?.userMetadata ?? const {};
      if (metadata['pending_role'] == 'owner') {
        await client.rpc<void>(
          'save_owner_profile',
          params: {'p_name': metadata['name']?.toString() ?? user.fullName},
        );
        ref.invalidate(currentOwnerProvider);
      }
      ref.invalidate(appAccessRoleProvider);
      final role = await ref.read(appAccessRoleProvider.future);
      if (!mounted) return;
      context.go(
        role == AppAccessRole.owner || role == AppAccessRole.admin
            ? AppRoutes.ownerDashboard
            : AppRoutes.home,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email used during signup.');
      return;
    }
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendSignupConfirmation(email);
      if (mounted) setState(() => _resent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callbackError =
        authCallbackErrorFromUri(widget.callbackUri ?? Uri.base) ??
        (authCallbackInitializationError == null
            ? null
            : AuthCallbackError(
                code: authCallbackInitializationError!.code ?? 'access_denied',
                description: authCallbackInitializationError!.message,
              ));
    final auth = callbackError == null ? ref.watch(authStateProvider) : null;
    final authenticatedUser = auth?.asData?.value;
    if (authenticatedUser != null && !_finishing) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _finish(authenticatedUser),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Email confirmation')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: callbackError != null
                ? _expiredContent(callbackError)
                : _finishingContent(auth!),
          ),
        ),
      ),
    );
  }

  Widget _finishingContent(AsyncValue<AuthUser?> auth) {
    if (_error != null) return _errorContent(_error!);
    if (auth.hasError) return _errorContent(auth.error.toString());
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('Confirming your email and preparing your dashboard…'),
      ],
    );
  }

  Widget _expiredContent(AuthCallbackError error) {
    final title = error.isExpired
        ? 'This confirmation link has expired'
        : 'We could not confirm this email';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.link_off_rounded, size: 58, color: AppTheme.danger),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Request a fresh email below. Only the newest confirmation link will work.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Signup email'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _resending ? null : _resend,
          icon: const Icon(Icons.outgoing_mail),
          label: Text(_resending ? 'Sending…' : 'Resend confirmation'),
        ),
        if (_resent) ...[
          const SizedBox(height: 12),
          const Text(
            'Confirmation sent. Open the latest email.',
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        ],
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _errorContent(String message) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, size: 54),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      TextButton(
        onPressed: () => context.go(AppRoutes.login),
        child: const Text('Back to login'),
      ),
    ],
  );
}
