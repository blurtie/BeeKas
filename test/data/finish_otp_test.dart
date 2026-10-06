import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_signup_repository.dart';

const reg = Registration(
  fullName: 'Ana',
  email: 'a@binus.ac.id',
  phone: '+6281234567890',
  accountType: AccountType.student,
  campus: Campus.senayan,
);

void main() {
  test('finished account: signs out, touches nothing', () async {
    final repo = FakeSignupRepository(
      hasPassword: true,
      phone: '+6281111111111',
    );
    final r = await finishOtp(repo, reg);
    expect(r.next, AfterOtp.alreadyRegistered);
    expect(repo.calls, ['account', 'signOut']);
  });

  test('new sign-up: applies the form and saves the phone', () async {
    final repo = FakeSignupRepository();
    final r = await finishOtp(repo, reg);
    expect(r, (
      next: AfterOtp.continueSignup,
      phoneError: null,
      keptPhone: null,
    ));
    expect(repo.calls, ['account', 'updateIdentity', 'setPhone']);
    expect(repo.phone, reg.phone);
  });

  test('taken number: continues but asks for another', () async {
    final repo = FakeSignupRepository(
      errors: {
        'setPhone': [const SignupException(SignupError.phoneTaken)],
      },
    );
    final r = await finishOtp(repo, reg);
    expect(r.phoneError, SignupError.phoneTaken);
    expect(repo.phone, isNull);
  });

  test('other set_phone errors are not swallowed', () async {
    final repo = FakeSignupRepository(
      errors: {
        'setPhone': [const SignupException(null)],
      },
    );
    expect(finishOtp(repo, reg), throwsA(isA<SignupException>()));
  });

  test('abandoned sign-up keeps its old number', () async {
    final repo = FakeSignupRepository(phone: '+6281111111111');
    final r = await finishOtp(repo, reg);
    expect(r.keptPhone, '+6281111111111');
    expect(repo.calls, ['account', 'updateIdentity']);
  });
}
