import 'package:beekas/domain/phone_release.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lepas nomor HP note: required, short, no phone number (D-26)', () {
    expect(releaseNoteError('  '), SignupError.noteMissing);
    expect(releaseNoteError('a' * 501), SignupError.noteTooLong);
    expect(releaseNoteError('a' * 500), isNull);
    expect(releaseNoteError('nomor 0812-3456-7890'), SignupError.noteHasPhone);
    expect(releaseNoteError('+62 812 3456 7890'), SignupError.noteHasPhone);
    expect(releaseNoteError('0812.3456.78'), SignupError.noteHasPhone);
    expect(releaseNoteError('Pemilik asli lewat Bantuan, 21 Okt'), isNull);
    // ponytail: a dashed date is 8 digits too; write dates in words.
    expect(releaseNoteError('tiket 2026-10-21'), SignupError.noteHasPhone);
  });
}
