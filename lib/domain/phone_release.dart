import 'signup_error.dart';

/// Why a Lepas nomor HP note is refused, or null; mirrors release_phone. A
/// phone number is 8+ digits in a row once spaces, dots and dashes go (D-26).
SignupError? releaseNoteError(String note) {
  final trimmed = note.trim();
  if (trimmed.isEmpty) return SignupError.noteMissing;
  if (trimmed.length > 500) return SignupError.noteTooLong;
  if (RegExp(r'\d{8}').hasMatch(trimmed.replaceAll(RegExp(r'[\s.-]'), ''))) {
    return SignupError.noteHasPhone;
  }
  return null;
}
