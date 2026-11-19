/// Lapor (K16) and the admin report console (K19): D-38 K-22, PRD-katalog
/// 6.13. The backend enforces the same in submit_report.
library;

/// K-22: fixed codes, matching the report_reason enum.
enum ReportReason {
  prohibited('prohibited'),
  scam('scam'),
  notAsDescribed('not_as_described'),
  inappropriate('inappropriate'),
  spam('spam'),
  other('other');

  const ReportReason(this.code);
  final String code;
  String get copyKey => 'reportReason_$code';

  static ReportReason fromCode(String code) =>
      values.firstWhere((r) => r.code == code);
}

/// The note is optional, except for Lainnya (6.13); at most 500 characters.
bool isValidReport(ReportReason? reason, String note) {
  final n = note.trim();
  if (reason == null || n.length > 500) return false;
  return reason != ReportReason.other || n.isNotEmpty;
}

/// Turunkan needs a reason the seller reads in Barang Saya.
bool isValidRemoval(String reason) => reason.trim().isNotEmpty;
