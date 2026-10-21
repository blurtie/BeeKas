import 'dart:typed_data';

import 'package:beekas/data/listing_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_listing_repository.dart';

void main() {
  final NewListing listing = (
    draft: (
      isDonation: false,
      category: ListingCategory.other,
      photoCount: 2,
      title: 'Macbook',
      description: 'Mulus',
      condition: ListingCondition.likeNew,
      price: 5000000,
      stock: 1,
      specs: '',
    ),
    campus: Campus.bandung,
    warranty: null,
  );
  final photos = [Uint8List(1), Uint8List(2)];

  test('uploads the photos, then creates the listing', () async {
    final repo = FakeListingRepository();
    await publishListing(repo, listing, photos);
    expect(repo.created, [listing]);
    expect(repo.stored, hasLength(2));
  });

  test('photos are deleted again when create_listing fails', () async {
    final repo = FakeListingRepository()
      ..failCreate = const SignupException(SignupError.noQuota);
    await expectLater(
      publishListing(repo, listing, photos),
      throwsA(isA<SignupException>()),
    );
    expect(repo.created, isEmpty);
    expect(repo.stored, isEmpty);
  });

  test(
    'photos already uploaded are deleted when a later upload fails',
    () async {
      final repo = FakeListingRepository()..failUploadAt = 1;
      await expectLater(
        publishListing(repo, listing, photos),
        throwsA(isA<SignupException>()),
      );
      expect(repo.stored, isEmpty);
      expect(repo.created, isEmpty);
    },
  );

  test(
    'photos stay when create_listing may have committed (no answer)',
    () async {
      final repo = FakeListingRepository()
        ..failCreate = const SignupException(null);
      await expectLater(
        publishListing(repo, listing, photos),
        throwsA(isA<SignupException>()),
      );
      expect(repo.stored, hasLength(2));
    },
  );
}
