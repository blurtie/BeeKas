import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/registration.dart';
import 'signup_repository.dart';

/// Read-only catalog (#74); everyone may read it, guests included (D-06).
/// Failures are [SignupException]s.
abstract interface class CatalogRepository {
  /// Active listings, newest first.
  Future<List<Listing>> listings();
}

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);
  final SupabaseClient _client;

  @override
  // ponytail: the whole catalog in one call; paginate when it outgrows a demo.
  Future<List<Listing>> listings() => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>('catalog_listings');
    final bucket = _client.storage.from('listing-photos');
    Campus campus(Object? code) =>
        Campus.values.firstWhere((c) => c.code == code);
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          id: row['id'] as String,
          title: row['title'] as String,
          description: row['description'] as String,
          category: ListingCategory.fromCode(row['category'] as String),
          condition: ListingCondition.fromCode(row['condition'] as String),
          price: row['price'] as int,
          previousPrice: row['previous_price'] as int?,
          stock: row['stock'] as int,
          campus: campus(row['campus']),
          warranty: row['warranty'] as String?,
          specs: [...?(row['specs'] as List<dynamic>?)?.cast<String>()],
          isDonation: row['is_donation'] as bool,
          photos: [
            for (final path in (row['photos'] as List<dynamic>).cast<String>())
              bucket.getPublicUrl(path),
          ],
          sellerName: row['seller_name'] as String,
          sellerCampus: campus(row['seller_campus']),
          sellerVerified: row['seller_verified'] as bool,
        ),
    ];
  });
}
