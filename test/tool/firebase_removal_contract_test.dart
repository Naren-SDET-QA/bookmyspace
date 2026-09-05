import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String read(String relativePath) =>
      File('$root${Platform.pathSeparator}$relativePath').readAsStringSync();

  test('Firebase packages and startup integration are absent', () {
    final pubspec = read('pubspec.yaml');
    final main = read('lib/main.dart');

    expect(pubspec, isNot(contains('firebase_core')));
    expect(pubspec, isNot(contains('firebase_analytics')));
    expect(pubspec, isNot(contains('firebase_crashlytics')));
    expect(pubspec, isNot(contains('firebase_performance')));
    expect(main, isNot(contains('initializeFirebase')));
    expect(main, contains('initSupabase'));
    expect(main, contains('OneSignalPushService'));
  });

  test('venue repository has no Firebase logging dependency', () {
    final source =
        read('lib/features/venues/infrastructure/supabase_venue_repository.dart');
    expect(source, isNot(contains('core/firebase')));
    expect(source, isNot(contains('ErrorLogger')));
  });
}
