import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../auth/presentation/auth_providers.dart';
import '../owner_providers.dart';

class _FakeOwnerRepository {
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    if (email == 'owner@demo.com' && password == 'password') {
      return Owner(
        id: '1',
        userId: '00000000-0000-0000-0000-000000000002',
        email: 'owner@demo.com',
        name: 'Demo Owner',
      );
    }
    throw Exception('Invalid credentials');
  }

  Future<void> signOut() async {}
}

Widget _ownerApp() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: const AuthUser(id: 'u1', email: 'owner@demo.com')),
      ),
      ownerRepositoryProvider.overrideWithValue(_FakeOwnerRepository()),
    ],
    child: const MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const OwnerRegistrationScreen(),
          ),
        ],
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  runApp(_ownerApp());
}

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner Dashboard')),
      body: const Center(child: Text('Owner Dashboard - Coming Soon')),
    );
  }
}
