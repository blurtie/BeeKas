/// Why the backend refused a sign-up. Messages and constraint names must match
/// handle_new_user, set_phone and the profiles table in supabase/migrations;
/// [copyKey] points into lib/config/copy.dart. The phone errors come from
/// set_phone after OTP (#27); GoTrue hides trigger errors from the app.
enum SignupError {
  invalidEmailDomain('errorInvalidEmailDomain'),
  accountTypeNotAllowed('errorAccountTypeNotAllowed'),
  accountTypeRequired('errorAccountTypeRequired'),
  fullNameRequired('fullNameRequired'),
  invalidCampus('errorInvalidCampus'),
  invalidPhone('errorInvalidPhone'),
  phoneTaken('errorPhoneTaken'),
  // From submit_for_review: no phone saved yet (D-04).
  phoneMissing('errorPhoneMissing'),
  // From submit_for_review: card or selfie not uploaded since the last
  // rejection.
  photosMissing('errorPhotosMissing'),
  // From GoTrue (OTP and password steps).
  invalidCode('errorInvalidCode'),
  tooSoon('errorTooSoon'),
  weakPassword('errorWeakPassword'),
  unknown('errorSignupUnknown');

  const SignupError(this.copyKey);

  final String copyKey;
}

/// [code] is the Postgres SQLSTATE or the GoTrue error code, [message] its
/// message.
SignupError signupErrorFrom(String? code, String message) {
  return switch ((code, message)) {
    ('23514', 'invalid_email_domain') => SignupError.invalidEmailDomain,
    ('23514', 'account_type_not_allowed') => SignupError.accountTypeNotAllowed,
    ('23514', 'account_type_required') => SignupError.accountTypeRequired,
    ('23502', 'full_name_required') => SignupError.fullNameRequired,
    ('23514', 'invalid_campus') => SignupError.invalidCampus,
    ('23514', _) when message.contains('profiles_phone_check') =>
      SignupError.invalidPhone,
    ('23505', _) when message.contains('profiles_phone_key') =>
      SignupError.phoneTaken,
    ('23514', 'phone_missing') => SignupError.phoneMissing,
    ('23514', 'photos_missing') => SignupError.photosMissing,
    ('otp_expired', _) => SignupError.invalidCode,
    ('over_email_send_rate_limit', _) => SignupError.tooSoon,
    ('weak_password', _) => SignupError.weakPassword,
    _ => SignupError.unknown,
  };
}

/// The wait in GoTrue's "…only request this after N seconds." message.
int? retryAfterSeconds(String message) {
  final match = RegExp(r'after (\d+) seconds?').firstMatch(message);
  return match == null ? null : int.parse(match[1]!);
}
