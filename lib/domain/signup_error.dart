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
  unknown('errorSignupUnknown');

  const SignupError(this.copyKey);

  final String copyKey;
}

/// [code] is the Postgres SQLSTATE the auth API returns, [message] its message.
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
    _ => SignupError.unknown,
  };
}
