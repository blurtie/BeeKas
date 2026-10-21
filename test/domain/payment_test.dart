import 'package:beekas/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each kind has its price (D-29)', () {
    expect(PaymentKind.package.amount, 15000);
    expect(PaymentKind.boost.amount, 3000);
    expect(PaymentKind.featured.amount, 5000);
  });

  test('a package buys 3 listings', () {
    expect(packageListings, 3);
  });

  test('kinds and statuses read from their backend codes', () {
    expect(PaymentKind.fromCode('package'), PaymentKind.package);
    expect(PaymentKind.fromCode('featured'), PaymentKind.featured);
    expect(PaymentStatus.fromCode('pending'), PaymentStatus.pending);
    expect(PaymentStatus.fromCode('confirmed'), PaymentStatus.confirmed);
    expect(PaymentStatus.fromCode('rejected'), PaymentStatus.rejected);
    expect(() => PaymentStatus.fromCode('refunded'), throwsArgumentError);
  });

  test('rejecting needs a reason of up to 500 characters (rule 5)', () {
    expect(isValidPaymentRejection(''), isFalse);
    expect(isValidPaymentRejection('   '), isFalse);
    expect(isValidPaymentRejection('Bukti buram'), isTrue);
    expect(isValidPaymentRejection('a' * 500), isTrue);
    expect(isValidPaymentRejection('a' * 501), isFalse);
  });

  test('the amount received is a whole rupiah amount above 0', () {
    expect(receivedAmount('15000'), 15000);
    expect(receivedAmount(' 15000 '), 15000);
    expect(receivedAmount('0'), isNull);
    expect(receivedAmount(''), isNull);
    expect(receivedAmount('15.000'), isNull);
    expect(receivedAmount('-5'), isNull);
    expect(receivedAmount('9999999999'), isNull);
  });
}
