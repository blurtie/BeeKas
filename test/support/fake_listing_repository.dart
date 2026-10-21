import 'dart:async';
import 'dart:typed_data';

import 'package:beekas/data/listing_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/data/signup_repository.dart';

/// Plays the bucket and create_listing. [stored] is what sits in the bucket;
/// [failUploadAt] fails that upload (0-based), [failCreate] makes
/// create_listing throw, [gate] holds create_listing for the loading state,
/// [loseAnswer] commits but throws as if the answer were lost. Like the
/// server, a repeated listing id is not created or charged twice. [mine] is
/// Barang Saya: [failMine] fails loading it, [mineGate] holds it, [failAction]
/// fails edit, withdraw and relist; [actions] records them.
class FakeListingRepository implements ListingRepository {
  FakeListingRepository({
    this.quota = 1,
    this.campus = Campus.bandung,
    List<MyListing>? mine,
  }) : mine = mine ?? [];
  int quota;
  Campus campus;
  int? failUploadAt;
  Object? failCreate;
  Object? failSeller;
  Completer<void>? gate;
  var loseAnswer = false;
  final stored = <String>{};
  final created = <NewListing>[];
  final calls = <NewListing>[];
  var _uploads = 0;

  @override
  Future<SellerInfo> seller() async {
    final error = failSeller;
    if (error != null) throw error;
    return (quota: quota, campus: campus);
  }

  @override
  Future<String> uploadPhoto(Uint8List jpeg) async {
    if (_uploads++ == failUploadAt) {
      throw const SignupException(null);
    }
    final path = 'me/$_uploads.jpg';
    stored.add(path);
    return path;
  }

  @override
  Future<void> deletePhotos(List<String> paths) async =>
      stored.removeAll(paths);

  @override
  Future<void> createListing(NewListing listing, List<String> photos) async {
    calls.add(listing);
    await gate?.future;
    final error = failCreate;
    if (error != null) throw error;
    if (!created.any((l) => l.id == listing.id)) {
      created.add(listing);
      quota--;
    }
    if (loseAnswer) throw const SignupException(null);
  }

  List<MyListing> mine;
  Object? failMine;
  Object? failAction;
  Completer<void>? mineGate;
  final actions = <String>[];
  final edits = <ListingEdit>[];

  @override
  Future<List<MyListing>> myListings() async {
    await mineGate?.future;
    final error = failMine;
    if (error != null) throw error;
    return List.of(mine);
  }

  Future<void> _act(
    String action,
    String id,
    MyListing Function(MyListing) change,
  ) async {
    final error = failAction;
    if (error != null) throw error;
    actions.add('$action $id');
    mine = [for (final l in mine) l.id == id ? change(l) : l];
  }

  @override
  Future<void> updateListing(String id, ListingEdit edit) {
    edits.add(edit);
    return _act(
      'update',
      id,
      (l) => (
        id: l.id,
        title: l.title,
        category: l.category,
        isDonation: l.isDonation,
        description: edit.description,
        condition: edit.condition,
        price: edit.price!,
        previousPrice: edit.price! < l.price ? l.price : null,
        stock: edit.stock!,
        stockLeft: l.stockLeft + edit.stock! - l.stock,
        campus: edit.campus,
        warranty: edit.warranty.isEmpty ? null : edit.warranty,
        specs: specLines(edit.specs),
        photos: l.photos,
        expiresAt: l.expiresAt,
        removedAt: l.removedAt,
        removalReason: l.removalReason,
        withdrawnAt: l.withdrawnAt,
      ),
    );
  }

  @override
  Future<void> withdrawListing(String id) => _act(
    'withdraw',
    id,
    (l) => (
      id: l.id,
      title: l.title,
      category: l.category,
      isDonation: l.isDonation,
      description: l.description,
      condition: l.condition,
      price: l.price,
      previousPrice: l.previousPrice,
      stock: l.stock,
      stockLeft: l.stockLeft,
      campus: l.campus,
      warranty: l.warranty,
      specs: l.specs,
      photos: l.photos,
      expiresAt: l.expiresAt,
      removedAt: l.removedAt,
      removalReason: l.removalReason,
      withdrawnAt: DateTime.now(),
    ),
  );

  @override
  Future<void> relistListing(String id) => _act(
    'relist',
    id,
    (l) => (
      id: l.id,
      title: l.title,
      category: l.category,
      isDonation: l.isDonation,
      description: l.description,
      condition: l.condition,
      price: l.price,
      previousPrice: l.previousPrice,
      stock: l.stock,
      stockLeft: l.stockLeft,
      campus: l.campus,
      warranty: l.warranty,
      specs: l.specs,
      photos: l.photos,
      expiresAt: DateTime.now().add(const Duration(days: 60)),
      removedAt: l.removedAt,
      removalReason: l.removalReason,
      withdrawnAt: l.withdrawnAt,
    ),
  );
}
