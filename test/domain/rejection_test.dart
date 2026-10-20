import 'package:beekas/domain/rejection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule 9: a rejection needs a reason; Other needs a note', () {
    const card = RejectionReason.card;
    const other = RejectionReason.other;
    expect(isValidRejection({}, ''), isFalse);
    expect(isValidRejection({}, 'Blurry'), isFalse);
    expect(isValidRejection({card}, ''), isTrue);
    expect(isValidRejection({other}, '  '), isFalse);
    expect(isValidRejection({other}, 'Expired card'), isTrue);
    expect(isValidRejection({card, other}, ''), isFalse);
  });

  test('reason names are the backend codes', () {
    expect(RejectionReason.values.map((r) => r.name), [
      'card',
      'selfie',
      'data',
      'other',
    ]);
  });
}
