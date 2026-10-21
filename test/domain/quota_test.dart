import 'package:beekas/domain/quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a newly approved seller starts with one listing (K-08)', () {
    expect(startingQuota, 1);
    expect(canList(startingQuota), isTrue);
    expect(quotaAfterListing(startingQuota), 0);
  });

  test('listing needs at least one quota', () {
    expect(canList(0), isFalse);
    expect(canList(3), isTrue);
  });

  test('listing takes one quota; never below zero', () {
    expect(quotaAfterListing(3), 2);
    expect(() => quotaAfterListing(0), throwsArgumentError);
  });
}
