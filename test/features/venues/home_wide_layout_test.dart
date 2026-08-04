import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/registration/domain/registration_form.dart';
import 'package:bookmyspace/features/registration/presentation/widgets/dynamic_registration_form.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../venues/mock_venue_repository.dart';

void main() {
  testWidgets('dynamic registration form validates required email', (
    tester,
  ) async {
    final form = RegistrationFormDefinition.fromJson(
      {
        'id': 'form-id',
        'name': 'Guests',
        'module_key': 'any',
        'status': 'draft',
      },
      {
        'version': 1,
        'schema': {
          'fields': [
            const RegistrationFieldDefinition(
              key: 'email',
              label: 'Email',
              type: RegistrationFieldType.email,
              order: 1,
              required: true,
            ).toJson(),
          ],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicRegistrationForm(
            definition: form,
            preview: true,
            onSubmit: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validate preview'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('wide home shows location picker and updates city', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: createAppRouter(
            initialLocation: AppRoutes.home,
            currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ongole, Andhra Pradesh'), findsOneWidget);

    await tester.tap(find.text('Ongole, Andhra Pradesh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guntur'));
    await tester.pumpAndSettle();

    expect(find.text('Guntur, Andhra Pradesh'), findsOneWidget);
  });
}
