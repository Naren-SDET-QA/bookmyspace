import 'package:bookmyspace/core/validators/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppValidators', () {
    group('email', () {
      test('returns null for valid email', () {
        expect(AppValidators.email('user@example.com'), isNull);
        expect(AppValidators.email('test.name+tag@domain.co'), isNull);
      });

      test('returns error for empty/null', () {
        expect(AppValidators.email(null), isNotNull);
        expect(AppValidators.email(''), isNotNull);
        expect(AppValidators.email('   '), isNotNull);
      });

      test('returns error for invalid email', () {
        expect(AppValidators.email('notanemail'), isNotNull);
        expect(AppValidators.email('@domain.com'), isNotNull);
        expect(AppValidators.email('user@'), isNotNull);
      });
    });

    group('phone', () {
      test('returns null for valid phone', () {
        expect(AppValidators.phone('9876543210'), isNull);
        expect(AppValidators.phone('+919876543210'), isNull);
      });

      test('returns error for empty/null', () {
        expect(AppValidators.phone(null), isNotNull);
        expect(AppValidators.phone(''), isNotNull);
      });

      test('returns error for invalid phone', () {
        expect(AppValidators.phone('123'), isNotNull);
        expect(AppValidators.phone('abcdefghij'), isNotNull);
      });
    });

    group('name', () {
      test('returns null for valid name', () {
        expect(AppValidators.name('Naren'), isNull);
        expect(AppValidators.name("O'Brien-Smith"), isNull);
      });

      test('returns error for empty/null', () {
        expect(AppValidators.name(null), isNotNull);
        expect(AppValidators.name(''), isNotNull);
      });

      test('returns error for invalid name', () {
        expect(AppValidators.name('A'), isNotNull);
        expect(AppValidators.name('12345'), isNotNull);
      });
    });

    group('otp', () {
      test('returns null for valid OTP', () {
        expect(AppValidators.otp('1234'), isNull);
        expect(AppValidators.otp('123456'), isNull);
      });

      test('returns error for invalid OTP', () {
        expect(AppValidators.otp('12'), isNotNull);
        expect(AppValidators.otp('abcdef'), isNotNull);
      });
    });

    group('password', () {
      test('returns null for valid password', () {
        expect(AppValidators.password('password1'), isNull);
        expect(AppValidators.password('MyP4ssword'), isNull);
      });

      test('returns error for short password', () {
        expect(AppValidators.password('pass1'), isNotNull);
      });

      test('returns error for password without letter', () {
        expect(AppValidators.password('12345678'), isNotNull);
      });

      test('returns error for password without number', () {
        expect(AppValidators.password('password'), isNotNull);
      });
    });

    group('required', () {
      test('returns null for non-empty value', () {
        expect(AppValidators.required('hello'), isNull);
      });

      test('returns error for empty/null', () {
        expect(AppValidators.required(null), isNotNull);
        expect(AppValidators.required(''), isNotNull);
      });

      test('respects minLength', () {
        expect(AppValidators.required('ab', minLength: 3), isNotNull);
        expect(AppValidators.required('abc', minLength: 3), isNull);
      });
    });

    group('priceRange', () {
      test('returns null for valid ranges', () {
        expect(AppValidators.priceRange(min: 100, max: 500), isNull);
        expect(AppValidators.priceRange(min: null, max: 500), isNull);
        expect(AppValidators.priceRange(), isNull);
      });

      test('rejects negative values', () {
        expect(AppValidators.priceRange(min: -1), isNotNull);
        expect(AppValidators.priceRange(max: -5), isNotNull);
      });

      test('rejects min greater than max', () {
        expect(AppValidators.priceRange(min: 1000, max: 100), isNotNull);
      });
    });

    group('subject', () {
      test('returns null for valid subject', () {
        expect(AppValidators.subject('Help with booking'), isNull);
      });

      test('returns error for too short subject', () {
        expect(AppValidators.subject('Hi'), isNotNull);
      });
    });

    group('description', () {
      test('returns null for valid description', () {
        expect(
          AppValidators.description('This is a long enough description.'),
          isNull,
        );
      });

      test('returns error for short description', () {
        expect(AppValidators.description('short'), isNotNull);
      });
    });

    group('positiveInt', () {
      test('returns null for valid capacity', () {
        expect(AppValidators.positiveInt('50', fieldName: 'capacity'), isNull);
      });

      test('rejects zero and negative', () {
        expect(AppValidators.positiveInt('0'), isNotNull);
        expect(AppValidators.positiveInt('-1'), isNotNull);
      });

      test('rejects non-numeric', () {
        expect(AppValidators.positiveInt('abc'), isNotNull);
      });
    });

    group('nonNegativePrice', () {
      test('returns null for valid price', () {
        expect(AppValidators.nonNegativePrice('0'), isNull);
        expect(AppValidators.nonNegativePrice('1500.50'), isNull);
      });

      test('rejects negative price', () {
        expect(AppValidators.nonNegativePrice('-10'), isNotNull);
      });
    });
  });
}
