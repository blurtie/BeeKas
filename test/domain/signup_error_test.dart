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

  test('maps submit_for_review photos_missing', () {
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
    expect(
      signupErrorFrom('invalid_credentials', 'Invalid login credentials'),
      SignupError.invalidCredentials,
    );
    expect(
      signupErrorFrom('over_request_rate_limit', 'Request rate limit reached'),
      SignupError.rateLimited,
    );
  });

  test('maps the review functions (review.sql)', () {
    expect(signupErrorFrom('23514', 'not_pending'), SignupError.notPending);
    expect(
      signupErrorFrom('23514', 'reason_missing'),
      SignupError.reasonMissing,
    );
    expect(signupErrorFrom('23514', 'note_missing'), SignupError.noteMissing);
    expect(signupErrorFrom('23514', 'no_phone'), SignupError.noPhone);
    expect(
      signupErrorFrom('23514', 'note_has_phone'),
      SignupError.noteHasPhone,
    );
    expect(signupErrorFrom('23514', 'note_too_long'), SignupError.noteTooLong);
    expect(signupErrorFrom('42501', 'not_admin'), SignupError.notAdmin);
  });

  test('maps create_listing refusals', () {
    expect(signupErrorFrom('23514', 'no_quota'), SignupError.noQuota);
    expect(signupErrorFrom('42501', 'not_allowed'), SignupError.notAllowed);
  });

  test('maps send_message refusals', () {
    expect(
      signupErrorFrom('42501', 'chat_not_allowed'),
      SignupError.chatNotAllowed,
    );
    expect(
      signupErrorFrom('23514', 'listing_unavailable'),
      SignupError.listingUnavailable,
    );
  });

  test('maps a second pending payment (D-43), checked or raced', () {
    expect(
      signupErrorFrom('23514', 'payment_pending'),
      SignupError.paymentPending,
    );
    expect(
      signupErrorFrom(
        '23505',
        'duplicate key value violates unique constraint "payments_one_pending"',
      ),
      SignupError.paymentPending,
    );
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

  test('maps the order functions (#85)', () {
    expect(
      signupErrorFrom('23514', 'listing_has_orders'),
      SignupError.listingHasOrders,
    );
    expect(signupErrorFrom('23514', 'sold_out'), SignupError.soldOut);
    expect(signupErrorFrom('23514', 'own_listing'), SignupError.ownListing);
    expect(
      signupErrorFrom('23514', 'listing_unavailable'),
      SignupError.listingUnavailable,
    );
    expect(
      signupErrorFrom('23514', 'donation_limit'),
      SignupError.donationLimit,
    );
    expect(
      signupErrorFrom('23514', 'already_ordered'),
      SignupError.alreadyOrdered,
    );
    expect(
      signupErrorFrom(
        '23505',
        'duplicate key value violates unique constraint "orders_one_running"',
      ),
      SignupError.alreadyOrdered,
    );
    expect(
      signupErrorFrom('23514', 'order_transition'),
      SignupError.orderTransition,
    );
    expect(signupErrorFrom('42501', 'not_party'), SignupError.notParty);
    expect(
      signupErrorFrom('23514', 'cod_time_missing'),
      SignupError.codTimeMissing,
    );
    expect(signupErrorFrom('23514', 'cod_time_past'), SignupError.codTimePast);
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
