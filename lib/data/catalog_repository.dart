import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/registration.dart';
import 'signup_repository.dart';

/// Read-only catalog (#74); everyone may read it, guests included (D-06).
/// Failures are [SignupException]s.
abstract interface class CatalogRepository {
  /// One page of active listings, newest first: [catalogPageSize] of them
  /// after [after]. [query] matches titles and seller names on the server,
  /// or-ed with the [matched] categories (D-41); [categories] (a shortcut
  /// group) restricts the result, null meaning all. [campuses] is the
  /// location filter (D-47), null meaning every location.
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? matched,
    List<ListingCategory>? categories,
    List<Campus>? campuses,
    Listing? after,
  });
}

/// [inner] with the location filter [campuses] applied to every call
/// that does not set its own.
class LocatedCatalog implements CatalogRepository {
  const LocatedCatalog(this.inner, this.campuses);
  final CatalogRepository inner;
  final List<Campus>? campuses;

  @override
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? matched,
    List<ListingCategory>? categories,
    List<Campus>? campuses,
    Listing? after,
  }) => inner.listings(
    query: query,
    matched: matched,
    categories: categories,
    campuses: campuses ?? this.campuses,
    after: after,
  );
}

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Listing>> listings({
    String? query,
    List<ListingCategory>? matched,
    List<ListingCategory>? categories,
    List<Campus>? campuses,
    Listing? after,
  }) => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'catalog_listings',
      params: {
        'p_query': query,
        'p_categories': categories?.map((c) => c.code).toList(),
        'p_query_categories': matched?.map((c) => c.code).toList(),
        'p_limit': catalogPageSize,
        'p_after_created_at': after?.createdAt,
        'p_after_id': after?.id,
        'p_campuses': campuses?.map((c) => c.code).toList(),
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
          isMine: row['is_mine'] as bool,
          createdAt: row['created_at'] as String,
        ),
    ];
  });
}
