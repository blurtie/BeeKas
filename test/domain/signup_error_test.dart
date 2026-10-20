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
      signupErrorFrom('23502', 'full_name_required'),
      SignupError.fullNameRequired,
    );
    expect(
      signupErrorFrom('23514', 'invalid_campus'),
      SignupError.invalidCampus,
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

  test('maps submit_for_review without a phone', () {
    expect(signupErrorFrom('23514', 'phone_missing'), SignupError.phoneMissing);
    expect(
      signupErrorFrom('23514', 'photos_missing'),
      SignupError.photosMissing,
    );
    expect(
      signupErrorFrom('23514', 'illegal_status_transition'),
      SignupError.illegalTransition,
    );
  });

  test('maps GoTrue errors from the OTP and password steps', () {
    // GoTrue gives a wrong and an expired code the same error.
    expect(
      signupErrorFrom('otp_expired', 'Token has expired or is invalid'),
      SignupError.invalidCode,
    );
    expect(
      signupErrorFrom('over_email_send_rate_limit', 'x'),
      SignupError.tooSoon,
    );
    expect(signupErrorFrom('weak_password', 'x'), SignupError.weakPassword);
  });

  test('reads the wait from a rate-limit message', () {
    expect(
      retryAfterSeconds(
        'For security purposes, you can only request this after 42 seconds.',
      ),
      42,
    );
    expect(retryAfterSeconds('Too many requests'), isNull);
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
