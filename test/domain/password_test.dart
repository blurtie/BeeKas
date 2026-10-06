import 'package:beekas/domain/password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each rule is checked on its own while typing', () {
    final c = checkPassword('abcdefgh', '');
    expect(c.minLength, isTrue);
    expect(c.hasLetter, isTrue);
    expect(c.hasDigit, isFalse);
    expect(c.matches, isFalse);
    expect(c.ok, isFalse);
  });

  test('7 characters is too short, 8 is enough', () {
    expect(checkPassword('abc1234', 'abc1234').ok, isFalse);
    expect(checkPassword('abc12345', 'abc12345').ok, isTrue);
  });

  test('digits only or letters only fail', () {
    expect(checkPassword('12345678', '12345678').hasLetter, isFalse);
    expect(checkPassword('abcdefgh', 'abcdefgh').hasDigit, isFalse);
  });

  test('any letter counts, like GoTrue letters_digits', () {
    expect(checkPassword('ABCDEFG1', 'ABCDEFG1').ok, isTrue);
  });

  test('confirmation must match and be non-empty', () {
    expect(checkPassword('abc12345', 'abc12346').matches, isFalse);
    expect(checkPassword('', '').matches, isFalse);
  });
}
