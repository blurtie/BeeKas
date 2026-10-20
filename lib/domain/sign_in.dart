/// Where Masuk, and reopening the app with a saved session, lead (D-06).
library;

import 'access.dart';
import 'registration.dart';

/// The signed-in account, read by AuthRepository.account().
typedef Account = ({
  Role role,
  AccountStatus status,
  // Null only for seeded admins, who never reach the Daftar steps.
  AccountType? accountType,
  bool hasPassword,
  bool hasConsent,
});

enum Destination { password, consent, photos, pending, rejected, home, review }

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
