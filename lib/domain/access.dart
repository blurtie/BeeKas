/// Rule 9: what each account may do, by status, freeze and role (D-06, D-38).
/// Guests have no status. The backend enforces the same with RLS and functions.
library;

enum AccountStatus { incomplete, pending, approved, rejected }

enum Role { member, admin }

/// Everyone, guests included, may browse the catalog (D-06).
bool canBrowseCatalog(AccountStatus? status) => true;

/// A frozen account keeps browsing but does nothing else (K-26).
bool _canAct(AccountStatus? status, bool frozen) =>
    status == AccountStatus.approved && !frozen;

bool canChat(AccountStatus? status, {required bool frozen}) =>
    _canAct(status, frozen);

bool canOrder(AccountStatus? status, {required bool frozen}) =>
    _canAct(status, frozen);

bool canCreateListing(AccountStatus? status, {required bool frozen}) =>
    _canAct(status, frozen);

bool canReport(AccountStatus? status, {required bool frozen}) =>
    _canAct(status, frozen);

bool canFavorite(AccountStatus? status, {required bool frozen}) =>
    _canAct(status, frozen);

/// L14-L15, admins only (D-09).
bool canReviewVerifications(Role? role) => role == Role.admin;

/// L14 flags files waiting longer than the promised 1×24 hours (L11).
bool isOverdue(DateTime submittedAt, DateTime now) =>
    now.difference(submittedAt) > const Duration(hours: 24);
