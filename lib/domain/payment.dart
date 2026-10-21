/// Rule 5: QRIS payments (D-29, PRD-katalog 5.3). The backend enforces the
/// same in the payments table, confirm_payment and reject_payment.
library;

/// One payment path for all three kinds (5.3); Boost and Featured come with
/// K22.
enum PaymentKind {
  package(15000),
  boost(3000),
  featured(5000);

  const PaymentKind(this.amount);

  /// The expected amount in rupiah.
  final int amount;

  static PaymentKind fromCode(String code) => values.byName(code);
}

/// A confirmed package adds this many listings to the quota.
const packageListings = 3;

enum PaymentStatus {
  pending,
  confirmed,
  rejected;

  static PaymentStatus fromCode(String code) => values.byName(code);
}

const maxRejectionReason = 500;

/// Tolak needs a reason the member will read (5.3).
bool isValidPaymentRejection(String reason) {
  final r = reason.trim();
  return r.isNotEmpty && r.length <= maxRejectionReason;
}

/// What the admin typed as received: digits only, 1 up to a Postgres integer.
int? receivedAmount(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d{1,9}$').hasMatch(t)) return null;
  final amount = int.parse(t);
  return amount > 0 ? amount : null;
}
