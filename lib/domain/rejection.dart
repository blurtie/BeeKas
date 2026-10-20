/// Rule 9: why an admin rejected a submission (D-08). The names are the codes
/// reject_verification stores; the backend enforces the same rule.
library;

enum RejectionReason { card, selfie, data, other }

/// What L12 shows: the admin's reasons and optional note.
typedef Rejection = ({List<RejectionReason> reasons, String? note});

/// At least one reason; [RejectionReason.other] needs the note.
bool isValidRejection(Set<RejectionReason> reasons, String note) =>
    reasons.isNotEmpty && !isNoteMissing(reasons, note);

/// [RejectionReason.other] is chosen without saying what.
bool isNoteMissing(Set<RejectionReason> reasons, String note) =>
    reasons.contains(RejectionReason.other) && note.trim().isEmpty;
