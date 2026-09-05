import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release workflow versions artifacts and never inlines credentials', () {
    final release = File('.github/workflows/release.yml').readAsStringSync();
    expect(release, contains('tags: ["v*.*.*"]'));
    expect(release, contains('--build-name='));
    expect(release, contains('--build-number='));
    expect(release, contains('flutter build apk --release'));
    expect(release, contains('flutter build appbundle --release'));
    expect(release, contains('flutter build web --release'));
    expect(release, contains('flutter build ios --release --no-codesign'));
    expect(release, contains('secrets.ANDROID_KEYSTORE_BASE64'));
    expect(release, contains('upload-artifact'));
    expect(release, isNot(contains('play.google.com')));
    expect(release, isNot(contains('appstoreconnect')));
    expect(release, isNot(contains('peaceiris/actions-gh-pages')));
    expect(release, contains(r'${ANDROID_STOREPASSWORD}'));
    expect(release.contains(RegExp(r'storePassword=[A-Za-z0-9+/=]{16,}')), isFalse);
  });

  test('CI uploads Android, web, and unsigned iOS artifacts with build numbers', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('flutter build apk --release --build-number='));
    expect(ci, contains('flutter build appbundle --release --build-number='));
    expect(ci, contains('flutter build web --release --build-number='));
    expect(ci, contains('flutter build ios --release --no-codesign --build-number='));
    expect(ci, contains('ci-apk'));
    expect(ci, contains('ci-aab'));
    expect(ci, contains('ci-web'));
    expect(ci, contains('ci-ios-unsigned'));
  });

  test('signing and export examples are placeholders only', () {
    final key = File('android/key.properties.example').readAsStringSync();
    expect(key, contains('STORE_PASSWORD_PLACEHOLDER'));
    expect(key, contains('KEY_PASSWORD_PLACEHOLDER'));
    expect(key, contains('upload-keystore.jks'));

    final export = File('ios/ExportOptions.plist.example').readAsStringSync();
    expect(export, contains('APPLE_TEAM_ID_PLACEHOLDER'));
    expect(export, contains('app-store-connect'));
  });
}
