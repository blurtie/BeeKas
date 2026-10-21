/// Catalog rules (#74, #77): categories, the Beranda shortcuts, search and
/// prices.
/// Pure Dart; the screens look labels up with each enum's copyKey.
library;

import 'dart:math';

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

/// What K5 and K6 hold before Pasang (PRD-katalog 5.2). [specs] is the raw
/// text, one spec per line.
typedef ListingDraft = ({
  bool isDonation,
  ListingCategory? category,
  int photoCount,
  String title,
  String description,
  ListingCondition? condition,
  int? price,
  int? stock,
  String specs,
});

enum ListingField {
  category,
  photos,
  title,
  description,
  condition,
  price,
  stock,
  specs;

  String get copyKey => 'listingError_$name';
}

/// The fields on K5; the rest are on K6.
const k5Fields = {
  ListingField.category,
  ListingField.photos,
  ListingField.title,
  ListingField.description,
};

const maxListingPhotos = 5;
const maxTitleLength = 100;
const maxDescriptionLength = 500;
const minPrice = 1000;
const maxPrice = 50000000;
const maxSpecLines = 10;

List<String> specLines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// Donations are always Rp0 (D-28).
int listingPrice(ListingDraft d) => d.isDonation ? 0 : d.price!;

/// Rule 1 (PRD-katalog 6.1); the listings constraints enforce the same.
Set<ListingField> validateListing(ListingDraft d) {
  final title = d.title.trim();
  final description = d.description.trim();
  final price = d.price;
  final stock = d.stock;
  return {
    if (d.category == null) ListingField.category,
    if (d.photoCount < 1 || d.photoCount > maxListingPhotos)
      ListingField.photos,
    if (title.isEmpty || title.length > maxTitleLength) ListingField.title,
    if (description.isEmpty || description.length > maxDescriptionLength)
      ListingField.description,
    if (d.condition == null) ListingField.condition,
    if (!d.isDonation &&
        (price == null || price < minPrice || price > maxPrice))
      ListingField.price,
    if (stock == null || stock < 1) ListingField.stock,
    if (specLines(d.specs).length > maxSpecLines) ListingField.specs,
  };
}

/// A random UUID v4 for a new listing. The app picks it once per draft, so a
/// retried create_listing (lost answer) finds the listing instead of
/// charging quota twice.
String newListingId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// K7 Barang Saya (#83): a listing as its owner sees it, live or not.
typedef MyListing = ({
  String id,
  String title,
  ListingCategory category,
  bool isDonation,
  String description,
  ListingCondition condition,
  int price,
  int? previousPrice,
  int stock,
  int stockLeft,
  Campus campus,
  String? warranty,
  List<String> specs,
  List<String> photos,
  DateTime createdAt,
  DateTime expiresAt,
  DateTime? removedAt,
  String? removalReason,
  DateTime? withdrawnAt,
});

/// Rule 3 (PRD-katalog 6.3), in the order K7 lists them.
enum ListingStatus {
  live,
  soldOut,
  expired,
  removed,
  withdrawn,
  // The seller is frozen or no longer approved (K-26); the server hides the
  // listing and refuses edit and relist.
  hidden;

  String get copyKey => 'listingStatus_$name';
}

/// Removed by an admin outranks withdrawn, which outranks a hidden seller
/// ([sellerListed] false: frozen or not approved), then expired, then sold
/// out: expired stays relistable even with no stock left.
ListingStatus listingStatus(
  MyListing l,
  DateTime now, {
  bool sellerListed = true,
}) {
  if (l.removedAt != null) return ListingStatus.removed;
  if (l.withdrawnAt != null) return ListingStatus.withdrawn;
  if (!sellerListed) return ListingStatus.hidden;
  if (!l.expiresAt.isAfter(now)) return ListingStatus.expired;
  if (l.stockLeft <= 0) return ListingStatus.soldOut;
  return ListingStatus.live;
}

/// Days of the 60 left, rounded up; 0 once expired.
int daysLeft(MyListing l, DateTime now) {
  final left = l.expiresAt.difference(now);
  if (left <= Duration.zero) return 0;
  return (left.inMicroseconds / Duration.microsecondsPerDay).ceil();
}

bool canEditListing(ListingStatus s) =>
    s == ListingStatus.live ||
    s == ListingStatus.soldOut ||
    s == ListingStatus.expired;

/// A hidden seller may still withdraw.
bool canWithdrawListing(ListingStatus s) =>
    canEditListing(s) || s == ListingStatus.hidden;

/// K7 order: by status, newest first within one; computed once per load.
List<(MyListing, ListingStatus)> sortMyListings(
  List<MyListing> listings,
  DateTime now, {
  bool sellerListed = true,
}) =>
    [
      for (final l in listings)
        (l, listingStatus(l, now, sellerListed: sellerListed)),
    ]..sort((a, b) {
      final byStatus = a.$2.index.compareTo(b.$2.index);
      return byStatus != 0
          ? byStatus
          : b.$1.createdAt.compareTo(a.$1.createdAt);
    });

/// K-07: free, another 60 days.
bool canRelistListing(ListingStatus s) => s == ListingStatus.expired;

/// Rule 2 (K-06, D-28): fixed once live, along with sale or donation.
const lockedAfterListing = {
  ListingField.title,
  ListingField.category,
  ListingField.photos,
};

/// What Edit may change; [specs] is the raw text, one spec per line.
typedef ListingEdit = ({
  String description,
  ListingCondition condition,
  int? price,
  int? stock,
  Campus campus,
  String warranty,
  String specs,
});

/// Rule 1 on the edited fields, and stock no lower than the units already
/// taken (update_listing enforces the same). An unchanged description is
/// never an error: it was valid when listed.
Set<ListingField> validateEdit(MyListing l, ListingEdit e) {
  final errors = validateListing((
    isDonation: l.isDonation,
    category: l.category,
    photoCount: 1,
    title: l.title,
    description: e.description,
    condition: e.condition,
    price: e.price,
    stock: e.stock,
    specs: e.specs,
  )).difference(lockedAfterListing);
  if (e.description == l.description) errors.remove(ListingField.description);
  final stock = e.stock;
  if (stock != null && stock < l.stock - l.stockLeft) {
    errors.add(ListingField.stock);
  }
  return errors;
}
