/// Catalog rules (#74, #77): categories, the Beranda shortcuts, search and
/// prices.
/// Pure Dart; the screens look labels up with each enum's copyKey.
library;

import 'registration.dart';

/// The 9 categories of Daftar-12; [code] matches the listing_category enum.
enum ListingCategory {
  laptopComputer('laptop_computer'),
  phoneGadget('phone_gadget'),
  accessories('accessories'),
  clothing('clothing'),
  shoes('shoes'),
  bags('bags'),
  booksStationery('books_stationery'),
  campusSupplies('campus_supplies'),
  other('other');

  const ListingCategory(this.code);
  final String code;
  String get copyKey => 'category_$code';

  static ListingCategory fromCode(String code) =>
      values.firstWhere((c) => c.code == code);
}

enum ListingCondition {
  likeNew('like_new'),
  usedGood('used_good'),
  usedFlawed('used_flawed');

  const ListingCondition(this.code);
  final String code;
  String get copyKey => 'condition_$code';

  static ListingCondition fromCode(String code) =>
      values.firstWhere((c) => c.code == code);
}

/// Beranda shortcuts and the Kategori chips. Accessories (watches,
/// headphones) sit in both Elektronik and Fashion.
enum CategoryGroup {
  all(ListingCategory.values),
  electronics([
    ListingCategory.laptopComputer,
    ListingCategory.phoneGadget,
    ListingCategory.accessories,
  ]),
  fashion([
    ListingCategory.clothing,
    ListingCategory.shoes,
    ListingCategory.bags,
    ListingCategory.accessories,
  ]),
  books([ListingCategory.booksStationery]),
  supplies([ListingCategory.campusSupplies]);

  const CategoryGroup(this.categories);
  final List<ListingCategory> categories;
  String get copyKey => 'group_$name';
}

/// An active listing as the catalog shows it: the seller's public data only
/// (D-26). [photos] are URLs, in order; [previousPrice] is the struck-through
/// price after a drop. [createdAt] with [id] is the paging cursor; it stays
/// the server's string, since a web DateTime drops the microseconds.
typedef Listing = ({
  String id,
  String title,
  String description,
  ListingCategory category,
  ListingCondition condition,
  int price,
  int? previousPrice,
  int stock,
  Campus campus,
  String? warranty,
  List<String> specs,
  bool isDonation,
  List<String> photos,
  String sellerName,
  Campus sellerCampus,
  bool sellerVerified,
  String createdAt,
});

/// Listings per catalog page; a shorter page is the last one.
const catalogPageSize = 20;

/// What the catalog asks the server for: listings whose title or seller
/// name contains [text], or whose category is in [matched]; [categories]
/// (a shortcut group) further restricts them, null meaning every category.
typedef CatalogSearch = ({
  String? text,
  List<ListingCategory>? matched,
  List<ListingCategory>? categories,
});

final _labelWordSplit = RegExp(r'[\s&]+');

/// A query equal to a word of a category label in any language ([labels]),
/// ignoring case and "&", also matches that category (K-02, D-41); labels
/// live in the app, not the database.
CatalogSearch catalogSearch(
  String query,
  Iterable<String> Function(ListingCategory) labels,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return (text: null, matched: null, categories: null);
  final matched = [
    for (final c in ListingCategory.values)
      if (labels(c)
          .any((l) => l.toLowerCase().split(_labelWordSplit).contains(q)))
        c,
  ];
  return (
    text: query.trim(),
    matched: matched.isEmpty ? null : matched,
    categories: null,
  );
}

/// "Rp 6.500.000".
String formatRupiah(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer('Rp ');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// The drop as a whole percent, rounded (7.5M → 6.5M is 13).
int? discountPercent(int price, int? previousPrice) =>
    previousPrice == null || previousPrice <= price
    ? null
    : ((previousPrice - price) * 100 / previousPrice).round();
