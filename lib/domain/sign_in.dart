/// Where Masuk, and reopening the app with a saved session, lead (D-06).
library;

import 'access.dart';
import 'registration.dart';
import 'signup_error.dart';

/// The signed-in account, read by AuthRepository.account().
typedef Account = ({
  Role role,
  AccountStatus status,
  // Null only for seeded admins, who never reach the Daftar steps.
  AccountType? accountType,
  bool hasPassword,
  bool hasConsent,
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
