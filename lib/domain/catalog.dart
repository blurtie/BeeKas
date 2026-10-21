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

/// What the catalog asks the server for: [text] matches titles and seller
/// names there; [categories] null means every category.
typedef CatalogSearch = ({String? text, List<ListingCategory>? categories});

/// A query equal to a category label in the current language ([label]),
/// ignoring case, filters by that category; labels live in the app, not the
/// database (K-02). Anything else is passed on as text.
CatalogSearch catalogSearch(
  String query,
  String Function(ListingCategory) label,
) {
  final q = query.trim();
  if (q.isEmpty) return (text: null, categories: null);
  final match = ListingCategory.values
      .where((c) => label(c).toLowerCase() == q.toLowerCase())
      .toList();
  return match.isEmpty
      ? (text: q, categories: null)
      : (text: null, categories: match);
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
