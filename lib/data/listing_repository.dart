import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/registration.dart';
import 'signup_repository.dart';

typedef SellerInfo = ({int quota, Campus campus});

/// What Pasang sends: the draft's id (newListingId, same on every retry), the
/// K5-K6 fields, the location (K6) and the warranty.
typedef NewListing = ({
  String id,
  ListingDraft draft,
  Campus campus,
  String? warranty,
});

/// Pasang barang (#82). Failures are [SignupException]s.
abstract interface class ListingRepository {
  /// The signed-in seller's quota balance and profile campus (K6 default).
  Future<SellerInfo> seller();

  /// Stores a prepared JPEG in the seller's folder; returns its path.
  Future<String> uploadPhoto(Uint8List jpeg);

  Future<void> deletePhotos(List<String> paths);

  /// create_listing: takes 1 quota and the listing is live at once. Sending
  /// an id that already has the seller's listing changes nothing.
  Future<void> createListing(NewListing listing, List<String> photos);

  /// K7 Barang Saya (#83): every own listing, newest first.
  Future<List<MyListing>> myListings();

  /// update_listing; name, category, sale/donation and photos stay (K-06).
  Future<void> updateListing(String id, ListingEdit edit);

  /// withdraw_listing: off the catalog for good, no quota back (D-29).
  Future<void> withdrawListing(String id);

  /// relist_listing: an expired listing runs 60 more days, free (K-07).
  Future<void> relistListing(String id);
}

/// Uploads [photos], then creates the listing. When an upload fails or the
/// server refuses the listing, the photos already uploaded are deleted again.
/// When create_listing's outcome is unknown (no answer: it may have
/// committed), they stay; the server-side orphan cleanup removes leftovers.
Future<void> publishListing(
  ListingRepository repository,
  NewListing listing,
  List<Uint8List> photos,
) async {
  final paths = <String>[];
  var creating = false;
  try {
    for (final photo in photos) {
      paths.add(await repository.uploadPhoto(photo));
    }
    creating = true;
    await repository.createListing(listing, paths);
  } catch (e) {
    final unknown = creating && (e is! SignupException || e.error == null);
    if (paths.isNotEmpty && !unknown) {
      try {
        await repository.deletePhotos(paths);
      } on SignupException {
        // ponytail: left in the bucket; server-side orphan cleanup is a separate issue.
      }
    }
    rethrow;
  }
}

class SupabaseListingRepository implements ListingRepository {
  SupabaseListingRepository(this._client);
  final SupabaseClient _client;
  final _random = Random.secure();

  String get _uid => _client.auth.currentUser!.id;
  StorageFileApi get _bucket => _client.storage.from('listing-photos');

  @override
  Future<SellerInfo> seller() => guardBackend(() async {
    final balance = await _client
        .from('quota_balances')
        .select('balance')
        .eq('member_id', _uid)
        .maybeSingle();
    final profile = await _client
        .from('profiles')
        .select('campus')
        .eq('id', _uid)
        .single();
    return (
      quota: (balance?['balance'] as int?) ?? 0,
      campus: Campus.values.firstWhere((c) => c.code == profile['campus']),
    );
  });

  @override
  Future<String> uploadPhoto(Uint8List jpeg) => guardBackend(() async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final path = '$_uid/$name.jpg';
    await _bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return path;
  });

  @override
  Future<void> deletePhotos(List<String> paths) =>
      guardBackend(() => _bucket.remove(paths));

  @override
  Future<void> createListing(NewListing listing, List<String> photos) =>
      guardBackend(() {
        final d = listing.draft;
        final specs = specLines(d.specs);
        final warranty = listing.warranty?.trim();
        return _client.rpc<void>(
          'create_listing',
          params: {
            'p_id': listing.id,
            'p_title': d.title.trim(),
            'p_description': d.description.trim(),
            'p_category': d.category!.code,
            'p_condition': d.condition!.code,
            'p_price': listingPrice(d),
            'p_stock': d.stock,
            'p_campus': listing.campus.code,
            'p_warranty': warranty == null || warranty.isEmpty
                ? null
                : warranty,
            'p_specs': specs.isEmpty ? null : specs,
            'p_is_donation': d.isDonation,
            'p_photos': photos,
          },
        );
      });

  @override
  Future<List<MyListing>> myListings() => guardBackend(() async {
    final rows = await _client
        .from('listings')
        .select('*, listing_photos(path, position)')
        .eq('seller_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        (
          id: row['id'] as String,
          title: row['title'] as String,
          category: ListingCategory.fromCode(row['category'] as String),
          isDonation: row['is_donation'] as bool,
          description: row['description'] as String,
          condition: ListingCondition.fromCode(row['condition'] as String),
          price: row['price'] as int,
          previousPrice: row['previous_price'] as int?,
          stock: row['stock'] as int,
          stockLeft: row['stock_left'] as int,
          campus: Campus.values.firstWhere((c) => c.code == row['campus']),
          warranty: row['warranty'] as String?,
          specs: [...?(row['specs'] as List<dynamic>?)?.cast<String>()],
          photos: [
            for (final photo
                in (row['listing_photos'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                  ..sort(
                    (a, b) =>
                        (a['position'] as int).compareTo(b['position'] as int),
                  ))
              _bucket.getPublicUrl(photo['path'] as String),
          ],
          expiresAt: DateTime.parse(row['expires_at'] as String),
          removedAt: _time(row['removed_at']),
          removalReason: row['removal_reason'] as String?,
          withdrawnAt: _time(row['withdrawn_at']),
        ),
    ];
  });

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  @override
  Future<void> updateListing(String id, ListingEdit edit) => guardBackend(() {
    final specs = specLines(edit.specs);
    final warranty = edit.warranty.trim();
    return _client.rpc<void>(
      'update_listing',
      params: {
        'p_id': id,
        'p_description': edit.description.trim(),
        'p_condition': edit.condition.code,
        'p_price': edit.price,
        'p_stock': edit.stock,
        'p_campus': edit.campus.code,
        'p_warranty': warranty.isEmpty ? null : warranty,
        'p_specs': specs.isEmpty ? null : specs,
      },
    );
  });

  @override
  Future<void> withdrawListing(String id) => guardBackend(
    () => _client.rpc<void>('withdraw_listing', params: {'p_id': id}),
  );

  @override
  Future<void> relistListing(String id) => guardBackend(
    () => _client.rpc<void>('relist_listing', params: {'p_id': id}),
  );
}
