import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Owner model round-trips JSON', () {
    const owner = Owner(
      id: '1',
      userId: '00000000-0000-0000-0000-000000000002',
      email: 'owner@demo.com',
      name: 'Demo Owner',
    );
    final json = {
      'id': owner.id,
      'user_id': owner.userId,
      'email': owner.email,
      'name': owner.name,
    };
    final parsed = Owner.fromJson(json);
    expect(parsed.id, owner.id);
    expect(parsed.email, owner.email);
    expect(parsed.name, owner.name);
  });
}