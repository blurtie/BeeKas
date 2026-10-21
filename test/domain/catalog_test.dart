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

  test('a category label, EN or ID, becomes a category filter; else text', () {
    final en = {
      ListingCategory.laptopComputer: 'Laptops & Computers',
      ListingCategory.clothing: 'Clothing',
    };
    final id = {
      ListingCategory.laptopComputer: 'Laptop & Komputer',
      ListingCategory.clothing: 'Pakaian',
    };
    String Function(ListingCategory) labels(Map<ListingCategory, String> m) =>
        (c) => m[c] ?? '-';

    expect(_parts(catalogSearch(' laptops & COMPUTERS ', labels(en))), (
      null,
      'laptop_computer',
    ));
    expect(_parts(catalogSearch('pakaian', labels(id))), (null, 'clothing'));
    expect(_parts(catalogSearch('Clothing', labels(id))), ('Clothing', null));
    expect(_parts(catalogSearch(' macbook ', labels(en))), ('macbook', null));
    expect(_parts(catalogSearch('  ', labels(en))), (null, null));
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
    (s.text, s.categories?.map((c) => c.code).join(','));
