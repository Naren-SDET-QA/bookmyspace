import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_course_repository.dart';

Widget _app(MockCourseRepository repo) {
  return ProviderScope(
    overrides: [courseRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      home: CourseDetailScreen(courseId: 'c1'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows course details and batches with enroll buttons', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
    expect(find.text('Nexus Learning Institute'), findsOneWidget);

    await _scrollTo(tester, find.text('Weekday Batch A'));
    expect(find.text('Weekday Batch A'), findsOneWidget);
    expect(find.text('22 seats left'), findsOneWidget);
    expect(find.text('Enroll now'), findsWidgets);
  });

  testWidgets('enrolling calls the repository', (tester) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Scroll the first batch into view and tap exactly its enroll button.
    await _scrollTo(tester, find.text('Weekday Batch A'));
    final batchCard = find.ancestor(
      of: find.text('Weekday Batch A'),
      matching: find.byType(Card),
    );
    final enrollButton = find.descendant(
      of: batchCard,
      matching: find.byType(FilledButton),
    );
    await tester.tap(enrollButton);
    await tester.pumpAndSettle();

    expect(repo.lastEnrollBatchId, 'b0');
  });

  testWidgets('a full batch disables enrollment', (tester) async {
    final repo = MockCourseRepository();
    final course = MockCourseRepository.sampleCourse();
    final fullBatch = CourseBatch(
      id: 'bfull',
      courseId: course.id,
      label: 'Full Batch',
      startsOn: DateTime.now().add(const Duration(days: 30)),
      capacity: 25,
      enrolledCount: 25,
    );
    repo.courses = [
      Course(
        id: course.id,
        instituteId: course.instituteId,
        title: course.title,
        description: course.description,
        mode: course.mode,
        venueId: course.venueId,
        durationWeeks: course.durationWeeks,
        feeAmount: course.feeAmount,
        instructorName: course.instructorName,
        coverImage: course.coverImage,
        status: course.status,
        instituteName: course.instituteName,
        instituteVerified: course.instituteVerified,
        batches: [fullBatch],
      ),
    ];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Full Batch'));
    expect(find.text('Sold out'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
