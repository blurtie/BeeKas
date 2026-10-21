import 'package:beekas/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('a label word, EN or ID, adds its category beside the text', () {
    const labels = {
      ListingCategory.booksStationery: [
        'Books & Stationery',
        'Buku & Alat Tulis',
      ],
      ListingCategory.shoes: ['Shoes', 'Sepatu'],
    };
    Iterable<String> label(ListingCategory c) => labels[c] ?? const ['-'];

    expect(_parts(catalogSearch(' BUKU ', label)), (
      'BUKU',
      'books_stationery',
    ));
    expect(_parts(catalogSearch('books', label)), (
      'books',
      'books_stationery',
    ));
    expect(_parts(catalogSearch('sepatu', label)), ('sepatu', 'shoes'));
    expect(_parts(catalogSearch('book', label)), ('book', null));
    expect(_parts(catalogSearch('&', label)), ('&', null));
    expect(_parts(catalogSearch('  ', label)), (null, null));
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

/// Lists compare by identity inside records; compare their contents.
(String?, String?) _parts(CatalogSearch s) =>
    (s.text, s.matched?.map((c) => c.code).join(','));
