import 'dart:async';

import 'package:beekas/data/catalog_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/registration.dart';

Listing fakeListing(
  String title, {
  ListingCategory category = ListingCategory.other,
  int price = 50000,
  int? previousPrice,
  bool isDonation = false,
  int stock = 1,
  String sellerName = 'Nadia Contoh',
  String? warranty,
  List<String> specs = const [],
  List<String> photos = const [],
}) => (
  createdAt: '2026-01-01T00:00:00+00:00',
  id: title,
  title: title,
  description: 'Deskripsi $title',
  category: category,
  condition: ListingCondition.usedGood,
  price: price,
  previousPrice: previousPrice,
  stock: stock,
  campus: Campus.alamSutera,
  warranty: warranty,
  specs: specs,
  isDonation: isDonation,
  photos: photos,
  sellerName: sellerName,
  sellerCampus: Campus.alamSutera,
  sellerVerified: true,
);

/// Plays the server: filters [result] by text (title or seller) or matched
/// categories, then by categories, in pages. [gate] holds the answer for the loading state, and
/// [fail] makes the next call throw it.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository([this.result = const []]);
  List<Listing> result;
  Completer<void>? gate;
  Object? fail;
  var calls = 0;
  List<ListingCategory>? lastCategories;
  List<ListingCategory>? lastMatched;

  @override
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? matched,
    List<ListingCategory>? categories,
    Listing? after,
  }) async {
    calls++;
    lastCategories = categories;
    lastMatched = matched;
    await gate?.future;
    final error = fail;
    fail = null;
    if (error != null) throw error;
    final q = query?.toLowerCase();
    final matches = [
      for (final l in result)
        if ((q == null ||
                '${l.title}|${l.sellerName}'.toLowerCase().contains(q) ||
                (matched?.contains(l.category) ?? false)) &&
            (categories == null || categories.contains(l.category)))
          l,
    ];
    final start = after == null ? 0 : matches.indexOf(after) + 1;
    return matches.skip(start).take(catalogPageSize).toList();
  }
}
