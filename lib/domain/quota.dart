/// Rule 4: listing quota (D-29, K-08). The backend enforces the same in
/// create_listing and the quota_balances check constraint.
library;

/// Given once, when an account first becomes approved (K-08).
const startingQuota = 1;

/// D-46: a donation takes no token (quota), so it can always be listed.
bool canList(int balance, {bool donation = false}) => donation || balance >= 1;

int quotaAfterListing(int balance, {bool donation = false}) {
  if (!canList(balance, donation: donation)) {
    throw ArgumentError.value(balance, 'balance');
  }
  return donation ? balance : balance - 1;
}
