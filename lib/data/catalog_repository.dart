import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/registration.dart';
import 'signup_repository.dart';

/// Read-only catalog (#74); everyone may read it, guests included (D-06).
/// Failures are [SignupException]s.
abstract interface class CatalogRepository {
  /// One page of active listings, newest first: [catalogPageSize] of them
  /// after [after]. [query] matches titles and seller names on the server;
  /// [categories] null means all.
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? categories,
    Listing? after,
  });
}

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? categories,
    Listing? after,
  }) => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'catalog_listings',
      params: {
        'p_query': query,
        'p_categories': categories?.map((c) => c.code).toList(),
        'p_limit': catalogPageSize,
        'p_after_created_at': after?.createdAt,
        'p_after_id': after?.id,
      },
    );
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
          createdAt: row['created_at'] as String,
        ),
    ];
  });
}
