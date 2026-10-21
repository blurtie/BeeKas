import 'package:beekas/domain/access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only approved, unfrozen accounts act; everyone browses (rule 9)', () {
    for (final status in [null, ...AccountStatus.values]) {
      for (final frozen in [false, true]) {
        final allowed = status == AccountStatus.approved && !frozen;
        final why = '$status frozen=$frozen';
        expect(canBrowseCatalog(status), isTrue, reason: why);
        expect(canChat(status, frozen: frozen), allowed, reason: why);
        expect(canOrder(status, frozen: frozen), allowed, reason: why);
        expect(canCreateListing(status, frozen: frozen), allowed, reason: why);
        expect(canReport(status, frozen: frozen), allowed, reason: why);
        expect(canFavorite(status, frozen: frozen), allowed, reason: why);
      }
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
