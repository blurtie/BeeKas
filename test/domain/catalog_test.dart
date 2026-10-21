import 'package:beekas/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';

void main() {
  test('formatRupiah groups thousands with dots', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(1000), 'Rp 1.000');
    expect(formatRupiah(35000), 'Rp 35.000');
    expect(formatRupiah(6500000), 'Rp 6.500.000');
    expect(formatRupiah(50000000), 'Rp 50.000.000');
  });

  test('discountPercent rounds the drop; none without a higher old price', () {
    expect(discountPercent(6500000, 7500000), 13);
    expect(discountPercent(6500000, null), isNull);
    expect(discountPercent(6500000, 6500000), isNull);
  });

  test('search matches title, category label, or seller, ignoring case', () {
    final listing = fakeListing(
      'Macbook Air M1',
      category: ListingCategory.laptopComputer,
      sellerName: 'Nadia Contoh',
    );
    String label(ListingCategory c) => 'Laptop & Komputer';
    for (final q in ['macbook', 'KOMPUTER', 'nadia', '  ', '']) {
      expect(matchesSearch(listing, q, label), isTrue, reason: q);
    }
    expect(matchesSearch(listing, 'jaket', label), isFalse);
  });

  test('All has every category; Accessories is electronics and fashion', () {
    expect(CategoryGroup.all.categories, ListingCategory.values);
    expect(
      CategoryGroup.electronics.categories,
      contains(ListingCategory.accessories),
    );
    expect(
      CategoryGroup.fashion.categories,
      contains(ListingCategory.accessories),
    );
  });

  test('codes round-trip with the database enums', () {
    for (final c in ListingCategory.values) {
      expect(ListingCategory.fromCode(c.code), c);
    }
    for (final c in ListingCondition.values) {
      expect(ListingCondition.fromCode(c.code), c);
    }
  });
}
