/// Rule 4: listing quota (D-29, K-08). The backend enforces the same in
/// create_listing and the quota_balances check constraint.
library;

/// Given once, when an account first becomes approved (K-08).
const startingQuota = 1;

bool canList(int balance) => balance >= 1;

int quotaAfterListing(int balance) {
  if (!canList(balance)) throw ArgumentError.value(balance, 'balance');
  return balance - 1;
}
