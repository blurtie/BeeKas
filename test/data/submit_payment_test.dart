import 'dart:typed_data';

import 'package:beekas/data/payment_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/payment.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_payment_repository.dart';

void main() {
  final proof = Uint8List(1);

  test('uploads the proof, then records the payment', () async {
    final repo = FakePaymentRepository();
    await submitPayment(repo, PaymentKind.package, proof);
    expect(repo.submitted, [proof]);
    expect(repo.uploads, hasLength(1));
  });

  test('a waiting payment stops it before the upload (D-43)', () async {
    final repo = FakePaymentRepository()..add(PaymentStatus.pending);
    await expectLater(
      submitPayment(repo, PaymentKind.package, proof),
      throwsA(
        isA<SignupException>().having(
          (e) => e.error,
          'error',
          SignupError.paymentPending,
        ),
      ),
    );
    expect(repo.uploads, isEmpty);
  });

  test('the proof is deleted when submit_payment refuses', () async {
    final repo = FakePaymentRepository()
      ..errors['recordPayment'] = const SignupException(
        SignupError.paymentPending,
      );
    await expectLater(
      submitPayment(repo, PaymentKind.package, proof),
      throwsA(isA<SignupException>()),
    );
    expect(repo.uploads, isEmpty);
    expect(repo.payments, isEmpty);
  });

  for (final error in [null, SignupError.unknown]) {
    test('the proof stays when the outcome is unknown ($error)', () async {
      final repo = FakePaymentRepository()
        ..errors['recordPayment'] = SignupException(error);
      await expectLater(
        submitPayment(repo, PaymentKind.package, proof),
        throwsA(isA<SignupException>()),
      );
      expect(repo.uploads, hasLength(1));
    });
  }

  test('a failed delete still reports the refusal', () async {
    final repo = FakePaymentRepository()
      ..errors['recordPayment'] = const SignupException(SignupError.notAllowed)
      ..errors['deleteProof'] = const SignupException(null);
    await expectLater(
      submitPayment(repo, PaymentKind.package, proof),
      throwsA(
        isA<SignupException>().having(
          (e) => e.error,
          'error',
          SignupError.notAllowed,
        ),
      ),
    );
  });
}
