import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/registration.dart';
import 'signup_repository.dart';

typedef SellerInfo = ({int quota, Campus campus});

/// What Pasang sends: the K5-K6 fields, the location (K6) and the warranty.
typedef NewListing = ({ListingDraft draft, Campus campus, String? warranty});

/// Pasang barang (#82). Failures are [SignupException]s.
abstract interface class ListingRepository {
  /// The signed-in seller's quota balance and profile campus (K6 default).
  Future<SellerInfo> seller();

  /// Stores a prepared JPEG in the seller's folder; returns its path.
  Future<String> uploadPhoto(Uint8List jpeg);

  Future<void> deletePhotos(List<String> paths);

  /// create_listing: takes 1 quota and the listing is live at once.
  Future<void> createListing(NewListing listing, List<String> photos);
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
}
