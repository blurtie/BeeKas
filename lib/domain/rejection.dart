/// Rule 9: why an admin rejected a submission (D-08). The names are the codes
/// reject_verification stores; the backend enforces the same rule.
library;

enum RejectionReason { card, selfie, data, other }

/// One rejection of one attempt (D-25): L12 shows the latest, L15 all.
typedef Rejection = ({
  List<RejectionReason> reasons,
  String? note,
  DateTime rejectedAt,
});

/// A verification_rejections row, or an entry of pending_verifications'
/// rejections.
Rejection rejectionFrom(Map<String, dynamic> row) => (
  reasons: [
    for (final code in row['reasons'] as List<dynamic>)
      RejectionReason.values.byName(code as String),
  ],
  note: row['note'] as String?,
  rejectedAt: DateTime.parse(row['rejected_at'] as String),
);

/// At least one reason; [RejectionReason.other] needs the note.
bool isValidRejection(Set<RejectionReason> reasons, String note) =>
    reasons.isNotEmpty && !isNoteMissing(reasons, note);

/// [RejectionReason.other] is chosen without saying what.
bool isNoteMissing(Set<RejectionReason> reasons, String note) =>
    reasons.contains(RejectionReason.other) && note.trim().isEmpty;
