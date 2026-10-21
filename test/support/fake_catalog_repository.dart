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

/// Answers [listings] with [result]; [gate] holds the answer for the loading
/// state, and [fail] makes the next call throw it.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository([this.result = const []]);
  List<Listing> result;
  Completer<void>? gate;
  Object? fail;
  var calls = 0;

  @override
  Future<List<Listing>> listings() async {
    calls++;
    await gate?.future;
    final error = fail;
    fail = null;
    if (error != null) throw error;
    return result;
  }
}
