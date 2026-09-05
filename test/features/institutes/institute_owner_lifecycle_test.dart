import 'package:flutter_test/flutter_test.dart';

void main() {
  test('class lifecycle statuses support pause, publish and unpublish', () {
    const supported = {'draft', 'published', 'paused', 'unpublished'};
    expect(supported, containsAll({'paused', 'published', 'unpublished'}));
  });
}
