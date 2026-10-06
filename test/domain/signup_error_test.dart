import 'package:beekas/config/copy.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps backend rejections from the sign-up trigger', () {
    expect(
      signupErrorFrom('23514', 'invalid_email_domain'),
      SignupError.invalidEmailDomain,
    );
    expect(
      signupErrorFrom('23514', 'account_type_not_allowed'),
      SignupError.accountTypeNotAllowed,
    );
    expect(
      signupErrorFrom('23514', 'account_type_required'),
      SignupError.accountTypeRequired,
    );
    expect(
      signupErrorFrom('23502', 'phone_required'),
      SignupError.phoneRequired,
    );
    expect(
      signupErrorFrom(
        '23505',
        'duplicate key value violates unique constraint "profiles_phone_key"',
      ),
      SignupError.phoneTaken,
    );
    expect(
      signupErrorFrom(
        '23514',
        'new row for relation "profiles" violates check constraint "profiles_phone_check"',
      ),
      SignupError.invalidPhone,
    );
  });

  test('anything else is unknown', () {
    expect(signupErrorFrom(null, 'Network down'), SignupError.unknown);
    expect(signupErrorFrom('23514', 'something_new'), SignupError.unknown);
  });

  test('every error has text in both languages', () {
    for (final error in SignupError.values) {
      for (final lang in Lang.values) {
        expect(copy[lang]![error.copyKey], isNotNull, reason: '$error $lang');
      }
    }
  });
}
