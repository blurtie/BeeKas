import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/sign_in.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account(
  AccountStatus status, {
  Role role = Role.member,
  bool hasPassword = true,
  bool hasConsent = true,
}) => (
  fullName: 'Budi',
  email: 'budi@binus.ac.id',
  role: role,
  status: status,
  accountType: AccountType.student,
  hasPassword: hasPassword,
  hasConsent: hasConsent,
  rejection: null,
);

void main() {
  test('onboarding only on the first open without a session', () {
    expect(startScreens(null, onboarded: false), [StartScreen.onboarding]);
    expect(startScreens(null, onboarded: true), [StartScreen.signIn]);
    for (final onboarded in [false, true]) {
      expect(
        startScreens(_account(AccountStatus.pending), onboarded: onboarded),
        [StartScreen.account],
      );
      expect(
        startScreens(
          _account(AccountStatus.incomplete, hasConsent: false),
          onboarded: onboarded,
        ),
        [StartScreen.signIn, StartScreen.account],
      );
    }
  });

  test('members go where their status says', () {
    expect(
      destinationFor(_account(AccountStatus.pending)),
      Destination.pending,
    );
    expect(
      destinationFor(_account(AccountStatus.rejected)),
      Destination.rejected,
    );
    expect(destinationFor(_account(AccountStatus.approved)), Destination.home);
  });

  test('incomplete resumes at the first unfinished step', () {
    final s = AccountStatus.incomplete;
    expect(
      destinationFor(_account(s, hasPassword: false, hasConsent: false)),
      Destination.password,
    );
    expect(destinationFor(_account(s, hasConsent: false)), Destination.consent);
    expect(destinationFor(_account(s)), Destination.photos);
  });

  test('admins go to L14 whatever their status', () {
    for (final status in AccountStatus.values) {
      expect(
        destinationFor(_account(status, role: Role.admin)),
        Destination.review,
      );
    }
  });

  test('only the Daftar steps keep Masuk below them', () {
    expect(Destination.values.where((d) => d.resumesDaftar), [
      Destination.password,
      Destination.consent,
      Destination.photos,
    ]);
  });

  test('sign-in errors: one message for wrong email or password', () {
    expect(signInErrorKey(null), 'errorNetwork');
    expect(
      signInErrorKey(SignupError.invalidCredentials),
      'errorInvalidCredentials',
    );
    expect(signInErrorKey(SignupError.rateLimited), 'errorRateLimited');
    expect(signInErrorKey(SignupError.unknown), 'errorSignInFailed');
  });

  test('sending a reset code never tells registered from unknown emails', () {
    expect(resetSendErrorKey(null), 'errorNetwork');
    expect(resetSendErrorKey(SignupError.rateLimited), 'errorRateLimited');
    for (final e in [SignupError.tooSoon, SignupError.unknown]) {
      expect(resetSendErrorKey(e), isNull, reason: '$e');
    }
  });

  test('codes are 6 digits', () {
    expect(isOtpCode(' 123456 '), isTrue);
    for (final c in ['12345', '1234567', '12a456', '']) {
      expect(isOtpCode(c), isFalse, reason: c);
    }
  });

  test('checking a reset code', () {
    expect(resetVerifyErrorKey(null), 'errorNetwork');
    expect(resetVerifyErrorKey(SignupError.invalidCode), 'errorInvalidCode');
    expect(resetVerifyErrorKey(SignupError.rateLimited), 'errorRateLimited');
    expect(resetVerifyErrorKey(SignupError.unknown), 'errorResetFailed');
  });
}
