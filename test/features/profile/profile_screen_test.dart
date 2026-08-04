import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/mock_auth_repository.dart';

Widget _app(
  MockAuthRepository repository, {
  AppAccessRole role = AppAccessRole.customer,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.profile,
    routes: [
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('Login page')),
      ),
      GoRoute(
        path: AppRoutes.ownerRegistration,
        builder: (_, _) => const Scaffold(body: Text('Owner registration')),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (_, _) => const Scaffold(body: Text('Owner dashboard')),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, _) => const Scaffold(body: Text('Admin dashboard')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      appAccessRoleProvider.overrideWith((ref) async => role),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('guest profile shows sign in', (tester) async {
    final repository = MockAuthRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Guest User'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    repository.dispose();
  });

  testWidgets('authenticated profile shows identity and signs out', (
    tester,
  ) async {
    final repository = MockAuthRepository(
      initialUser: const AuthUser(
        id: 'customer-id',
        email: 'customer@example.com',
        fullName: 'Customer Name',
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Customer Name'), findsOneWidget);
    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(repository.currentUser, isNull);
    expect(find.text('Login page'), findsOneWidget);
    repository.dispose();
  });

  testWidgets('customer sees become an owner action', (tester) async {
    final repository = MockAuthRepository(
      initialUser: const AuthUser(id: 'customer-id', email: 'c@example.com'),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Become an owner'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
    expect(find.text('Admin dashboard'), findsNothing);

    await tester.tap(find.text('Become an owner'));
    await tester.pumpAndSettle();
    expect(find.text('Owner registration'), findsOneWidget);
    repository.dispose();
  });

  testWidgets('owner sees owner dashboard shortcut', (tester) async {
    final repository = MockAuthRepository(
      initialUser: const AuthUser(id: 'owner-id', email: 'o@example.com'),
    );
    await tester.pumpWidget(
      _app(repository, role: AppAccessRole.owner),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner dashboard'), findsOneWidget);
    expect(find.text('Become an owner'), findsNothing);
    repository.dispose();
  });

  testWidgets('admin sees admin dashboard shortcut', (tester) async {
    final repository = MockAuthRepository(
      initialUser: const AuthUser(id: 'admin-id', email: 'a@example.com'),
    );
    await tester.pumpWidget(
      _app(repository, role: AppAccessRole.admin),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin dashboard'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
    repository.dispose();
  });
}
