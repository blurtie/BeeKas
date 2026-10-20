/// Rule 8: what each account may do, by status and role (D-06). Guests have no
/// status. The backend enforces the same with RLS and functions.
library;

enum AccountStatus { incomplete, pending, approved, rejected }

enum Role { member, admin }

/// Everyone, guests included, may browse the catalog (D-06).
bool canBrowseCatalog(AccountStatus? status) => true;

bool canContactSeller(AccountStatus? status) =>
    status == AccountStatus.approved;

bool canCreateListing(AccountStatus? status) =>
    status == AccountStatus.approved;

/// L14-L15, admins only (D-09).
bool canReviewVerifications(Role? role) => role == Role.admin;

/// L14 flags files waiting longer than the promised 1×24 hours (L11).
bool isOverdue(DateTime submittedAt, DateTime now) =>
    now.difference(submittedAt) > const Duration(hours: 24);
