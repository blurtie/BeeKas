import 'package:beekas/domain/access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only approved accounts contact sellers and create listings', () {
    for (final status in [null, ...AccountStatus.values]) {
      final approved = status == AccountStatus.approved;
      expect(canBrowseCatalog(status), isTrue, reason: '$status');
      expect(canContactSeller(status), approved, reason: '$status');
      expect(canCreateListing(status), approved, reason: '$status');
    }
  });

  test('only admins review verifications', () {
    expect(canReviewVerifications(Role.admin), isTrue);
    expect(canReviewVerifications(Role.member), isFalse);
    expect(canReviewVerifications(null), isFalse);
  });

  test('overdue after 24 hours', () {
    final sent = DateTime.utc(2026, 10, 20, 8);
    expect(isOverdue(sent, sent.add(const Duration(hours: 24))), isFalse);
    expect(
      isOverdue(sent, sent.add(const Duration(hours: 24, minutes: 1))),
      isTrue,
    );
  });
}
