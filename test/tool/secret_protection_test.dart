import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gitignore and gitleaks config cover secret classes without printing values', () {
    final gitignore = File('.gitignore').readAsStringSync();
    expect(gitignore, contains('.env'));
    expect(gitignore, contains('*.keystore'));
    expect(gitignore, contains('*.jks'));
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('google-services.json'));
    expect(gitignore, contains('GoogleService-Info.plist'));
    expect(gitignore, contains('*.keystore.base64'));
    expect(gitignore, contains('*.p12'));
    expect(gitignore, contains('*.pem'));

    final gitleaks = File('gitleaks.toml').readAsStringSync();
    expect(gitleaks, contains('useDefault = true'));
    expect(gitleaks, contains('allowlist'));

    final workflow = File('.github/workflows/secret-scan.yml').readAsStringSync();
    expect(workflow, contains('gitleaks'));
    expect(workflow, contains('--redact'));
    expect(workflow, contains('gitleaks.toml'));
  });
}
