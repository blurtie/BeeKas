import 'dart:async';
import 'dart:typed_data';

import 'package:beekas/data/listing_repository.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/data/signup_repository.dart';

/// Plays the bucket and create_listing. [stored] is what sits in the bucket;
/// [failUploadAt] fails that upload (0-based), [failCreate] makes
/// create_listing throw, [gate] holds create_listing for the loading state,
/// [loseAnswer] commits but throws as if the answer were lost. Like the
/// server, a repeated listing id is not created or charged twice.
class FakeListingRepository implements ListingRepository {
  FakeListingRepository({this.quota = 1, this.campus = Campus.bandung});
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
}
