import 'package:beekas/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codes match the report_reason enum', () {
    expect(ReportReason.values.map((r) => r.code), [
      'prohibited',
      'scam',
      'not_as_described',
      'inappropriate',
      'spam',
      'other',
    ]);
    expect(
      ReportReason.fromCode('not_as_described'),
      ReportReason.notAsDescribed,
    );
  });

  test('a note is optional except for Lainnya', () {
    expect(isValidReport(null, ''), isFalse);
    expect(isValidReport(ReportReason.spam, ''), isTrue);
    expect(isValidReport(ReportReason.other, '  '), isFalse);
    expect(isValidReport(ReportReason.other, 'Barang palsu'), isTrue);
    expect(isValidReport(ReportReason.scam, 'x' * 501), isFalse);
  });

  test('taking a listing down needs a reason', () {
    expect(isValidRemoval(' '), isFalse);
    expect(isValidRemoval('Barang terlarang'), isTrue);
  });
}
