/// Registration rules from docs/PRD.md section 6. Patterns must match the
/// profiles constraints and handle_new_user in supabase/migrations.
library;

// Rule 1: same pattern as profiles.member_identity, after trim + lowercase.
final _binusEmail = RegExp(r'^[^@\s]+@(binus\.ac\.id|binus\.edu)$');

String normalizeEmail(String input) => input.trim().toLowerCase();

bool isBinusEmail(String input) => _binusEmail.hasMatch(normalizeEmail(input));

/// Rule 2: accepts 08…, 628… or +628…, ignoring spaces and hyphens, and
/// returns +628 followed by 8–11 digits (profiles_phone_check), or null.
String? normalizePhone(String input) {
  final s = input.replaceAll(RegExp(r'[\s-]'), '');
  final match = RegExp(r'^(?:\+62|62|0)(8[0-9]{8,11})$').firstMatch(s);
  return match == null ? null : '+62${match[1]}';
}

/// Values are the Postgres account_type enum.
enum AccountType { student, lecturer, staff }

/// Rule 5 (D-15): the types an email may have. One means the domain fixes it
/// (binus.ac.id), two means the user must pick (binus.edu), none means the
/// email is not a BINUS address yet.
List<AccountType> accountTypesFor(String email) {
  if (!isBinusEmail(email)) return const [];
  return normalizeEmail(email).endsWith('@binus.ac.id')
      ? const [AccountType.student]
      : const [AccountType.lecturer, AccountType.staff];
}

/// Rule 6 (D-12). Values are the Postgres campus enum; [copyKey] points into
/// lib/config/copy.dart.
enum Campus {
  kemanggisan,
  senayan,
  alamSutera('alam_sutera'),
  base,
  bekasi,
  bandung,
  malang,
  semarang,
  online;

  const Campus([this._code]);
  final String? _code;

  String get code => _code ?? name;
  String get copyKey => 'campus_$code';
}

enum RegistrationField { fullName, email, phone, accountType, campus }

/// A sign-up that passed [validateRegistration], normalised for the backend.
class Registration {
  const Registration({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.accountType,
    required this.campus,
  });

  final String fullName;
  final String email;
  final String phone;
  final AccountType accountType;
  final Campus campus;

  /// Sign-up metadata read by handle_new_user. account_type is only sent for
  /// binus.edu; the trigger rejects it for binus.ac.id.
  Map<String, String> get metadata => {
    'full_name': fullName,
    'phone': phone,
    'campus': campus.code,
    if (accountType != AccountType.student) 'account_type': accountType.name,
  };
}

/// Either a [Registration] or the copy key of the first problem per field.
typedef RegistrationResult = ({
  Registration? registration,
  Map<RegistrationField, String> errors,
});

RegistrationResult validateRegistration({
  required String fullName,
  required String email,
  required String phone,
  AccountType? chosenType,
  Campus? campus,
}) {
  final errors = <RegistrationField, String>{};
  final name = fullName.trim();
  if (name.isEmpty) errors[RegistrationField.fullName] = 'fullNameRequired';

  final types = accountTypesFor(email);
  if (email.trim().isEmpty) {
    errors[RegistrationField.email] = 'errorEmailRequired';
  } else if (types.isEmpty) {
    errors[RegistrationField.email] = 'errorInvalidEmailDomain';
  }
  final type = types.length == 1
      ? types.single
      : (types.contains(chosenType) ? chosenType : null);
  if (types.length > 1 && type == null) {
    errors[RegistrationField.accountType] = 'errorAccountTypeRequired';
  }

  final normalizedPhone = normalizePhone(phone);
  if (phone.trim().isEmpty) {
    errors[RegistrationField.phone] = 'errorPhoneRequired';
  } else if (normalizedPhone == null) {
    errors[RegistrationField.phone] = 'errorInvalidPhone';
  }
  if (campus == null) errors[RegistrationField.campus] = 'errorInvalidCampus';

  if (errors.isNotEmpty) return (registration: null, errors: errors);
  return (
    registration: Registration(
      fullName: name,
      email: normalizeEmail(email),
      phone: normalizedPhone!,
      accountType: type!,
      campus: campus!,
    ),
    errors: const {},
  );
}

/// What the OTP screen (#27) does once the code is verified.
enum AfterOtp {
  /// The account already has a password: show "already registered" and go to
  /// Masuk.
  alreadyRegistered,

  /// New or abandoned sign-up: apply the form via update_identity and go on
  /// to the password step.
  continueSignup,
}

/// [storedPhone] is the profile's phone; [phoneChanged] tells the user an
/// abandoned sign-up keeps its old number instead of the one just typed. A
/// null phone was released by an admin (D-04), so nothing was kept.
({AfterOtp next, bool phoneChanged}) afterOtp({
  required bool hasPassword,
  required String? storedPhone,
  required Registration submitted,
}) => (
  next: hasPassword ? AfterOtp.alreadyRegistered : AfterOtp.continueSignup,
  phoneChanged:
      !hasPassword && storedPhone != null && storedPhone != submitted.phone,
);
