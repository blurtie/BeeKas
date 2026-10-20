/// Where Masuk, and reopening the app with a saved session, lead (D-06).
library;

import 'access.dart';
import 'registration.dart';
import 'rejection.dart';
import 'signup_error.dart';

/// The signed-in account, read by AuthRepository.account().
typedef Account = ({
  Role role,
  AccountStatus status,
  // Null only for seeded admins, who never reach the Daftar steps.
  AccountType? accountType,
  bool hasPassword,
  bool hasConsent,
  // The latest rejection (L12); kept after a resubmission.
  Rejection? rejection,
});

enum Destination {
  password,
  consent,
  photos,
  pending,
  rejected,
  home,
  review;

  /// Daftar steps have no Keluar, so Masuk stays below them for Back.
  bool get resumesDaftar =>
      this == password || this == consent || this == photos;
}

/// Admins go to L14. Incomplete members resume Daftar at the first unfinished
/// step; a missing phone is asked for later by L10 (phone_missing).
Destination destinationFor(Account account) {
  if (canReviewVerifications(account.role)) return Destination.review;
  return switch (account.status) {
    AccountStatus.incomplete when !account.hasPassword => Destination.password,
    AccountStatus.incomplete when !account.hasConsent => Destination.consent,
    AccountStatus.incomplete => Destination.photos,
    AccountStatus.pending => Destination.pending,
    AccountStatus.rejected => Destination.rejected,
    AccountStatus.approved => Destination.home,
  };
}

/// Masuk's message for a failed sign-in; [error] is null when the server could
/// not be reached. Unknown email and wrong password share one message (D-04).
String signInErrorKey(SignupError? error) => switch (error) {
  null => 'errorNetwork',
  SignupError.invalidCredentials || SignupError.rateLimited => error.copyKey,
  _ => 'errorSignInFailed',
};

/// Lupa password, sending the code: null means "shown as sent". Anything that
/// could depend on whether the email has an account (per-email resend limit,
/// mail errors) is shown as sent, so the screen never reveals it. Only errors
/// that do not depend on the email are shown.
String? resetSendErrorKey(SignupError? error) => switch (error) {
  null => 'errorNetwork',
  SignupError.rateLimited => error.copyKey,
  _ => null,
};

/// The emailed codes (L5 and Lupa password) are 6 digits.
bool isOtpCode(String input) => RegExp(r'^\d{6}$').hasMatch(input.trim());

/// Lupa password, checking the code. GoTrue answers a wrong and an expired
/// code alike (otp_expired), for unknown emails too, so nothing here leaks.
String resetVerifyErrorKey(SignupError? error) => switch (error) {
  null => 'errorNetwork',
  SignupError.invalidCode || SignupError.rateLimited => error.copyKey,
  _ => 'errorResetFailed',
};
