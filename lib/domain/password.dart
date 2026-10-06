/// Rule 4 (D-03), matching auth.password in supabase/config.toml:
/// minimum_password_length = 8 and password_requirements = "letters_digits"
/// (ASCII letters and digits).
library;

typedef PasswordCheck = ({
  bool minLength,
  bool hasLetter,
  bool hasDigit,
  bool matches,
});

PasswordCheck checkPassword(String password, String confirmation) => (
  minLength: password.length >= 8,
  hasLetter: password.contains(RegExp('[a-zA-Z]')),
  hasDigit: password.contains(RegExp('[0-9]')),
  matches: password.isNotEmpty && password == confirmation,
);

extension PasswordCheckOk on PasswordCheck {
  bool get ok => minLength && hasLetter && hasDigit && matches;
}
