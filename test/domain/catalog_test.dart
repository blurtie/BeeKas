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

  group('validateListing (PRD-katalog 6.1)', () {
    ListingDraft draft({
      bool isDonation = false,
      ListingCategory? category = ListingCategory.other,
      int photoCount = 1,
      String title = 'Macbook Air M1',
      String description = 'Mulus',
      ListingCondition? condition = ListingCondition.likeNew,
      int? price = 1000,
      int? stock = 1,
      String specs = '',
    }) => (
      isDonation: isDonation,
      category: category,
      photoCount: photoCount,
      title: title,
      description: description,
      condition: condition,
      price: price,
      stock: stock,
      specs: specs,
    );

    test('a complete sale is valid', () {
      expect(validateListing(draft()), isEmpty);
      expect(validateListing(draft(price: 50000000)), isEmpty);
    });

    test('sale price is Rp1.000-Rp50.000.000', () {
      for (final price in [null, 0, 999, 50000001]) {
        expect(validateListing(draft(price: price)), {ListingField.price});
      }
    });

    test('a donation needs no price and is Rp0', () {
      final d = draft(isDonation: true, price: null);
      expect(validateListing(d), isEmpty);
      expect(listingPrice(d), 0);
      expect(listingPrice(draft(price: 25000)), 25000);
    });

    test('stock is at least 1', () {
      expect(validateListing(draft(stock: 0)), {ListingField.stock});
      expect(validateListing(draft(stock: null)), {ListingField.stock});
    });

    test('1 to 5 photos', () {
      expect(validateListing(draft(photoCount: 0)), {ListingField.photos});
      expect(validateListing(draft(photoCount: 5)), isEmpty);
      expect(validateListing(draft(photoCount: 6)), {ListingField.photos});
    });

    test('category and condition must be chosen', () {
      expect(validateListing(draft(category: null, condition: null)), {
        ListingField.category,
        ListingField.condition,
      });
    });

    test('name up to 100 and description up to 500, not blank', () {
      expect(validateListing(draft(title: '  ')), {ListingField.title});
      expect(validateListing(draft(title: 'x' * 101)), {ListingField.title});
      expect(validateListing(draft(description: '')), {
        ListingField.description,
      });
      expect(validateListing(draft(description: 'x' * 500)), isEmpty);
      expect(validateListing(draft(description: 'x' * 501)), {
        ListingField.description,
      });
    });

    test('specs are optional, up to 10 non-empty lines', () {
      expect(specLines(' RAM 8GB \n\n SSD 256GB'), ['RAM 8GB', 'SSD 256GB']);
      expect(specLines('  \n'), isEmpty);
      expect(
        validateListing(draft(specs: List.filled(10, 'a').join('\n'))),
        isEmpty,
      );
      expect(validateListing(draft(specs: List.filled(11, 'a').join('\n'))), {
        ListingField.specs,
      });
    });

    test('K5 checks only its own fields', () {
      final errors = validateListing(draft(price: null, stock: 0, title: ''));
      expect(errors.where(k5Fields.contains), {ListingField.title});
    });
  });
}

/// Lists compare by identity inside records; compare their contents.
(String?, String?) _parts(CatalogSearch s) =>
    (s.text, s.matched?.map((c) => c.code).join(','));
