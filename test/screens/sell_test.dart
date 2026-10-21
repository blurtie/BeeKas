import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/photo.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/screens/sell_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';
import '../support/fake_listing_repository.dart';

// 1×1 PNG, standing in for a prepared photo.
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Opens the form from a launcher route, so popping it shows [result].
Future<void> _open(
  WidgetTester tester,
  FakeListingRepository repo, {
  Future<Uint8List?> Function({required bool camera})? pickPhoto,
  Future<void> Function()? onBuyQuota,
  void Function(bool? posted)? onResult,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final posted = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SellScreen(
                  repository: repo,
                  pickPhoto: pickPhoto ?? ({required camera}) async => _photo,
                  onBuyQuota: onBuyQuota ?? () async {},
                ),
              ),
            );
            onResult?.call(posted);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Picks [item] in the dropdown still showing [hint].
Future<void> _choose(WidgetTester tester, String hint, String item) async {
  await tester.ensureVisible(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(hint), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  final input = find.descendant(
    of: find.widgetWithText(BeeTextField, field),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _addPhoto(WidgetTester tester) async {
  await tester.tap(find.byTooltip(t('sellAddPhoto')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(t('sellGallery')));
  await tester.pumpAndSettle();
}

/// Fills K5 and moves on to K6.
Future<void> _fillK5(WidgetTester tester, {bool donation = false}) async {
  if (donation) {
    await tester.tap(find.text(t('sellTypeDonation')));
    await tester.pump();
  }
  await _choose(tester, t('sellCategoryHint'), t('category_laptop_computer'));
  await _addPhoto(tester);
  await _type(tester, t('sellName'), 'Macbook Pro M2');
  await _type(tester, t('description'), 'Mulus, baterai 90%');
  await _tap(tester, t('sellNext'));
}

void main() {
  setUp(() => language.value = Lang.id);

  testWidgets('K5 → K6 → Pasang lists the item and closes the form', (
    tester,
  ) async {
    final repo = FakeListingRepository(quota: 2, campus: Campus.bandung);
    bool? posted;
    await _open(tester, repo, onResult: (p) => posted = p);

    expect(find.text(t('sellProhibited')), findsOneWidget);
    await _fillK5(tester);
    expect(find.text(t('sellDetails')), findsOneWidget);
    expect(find.text(t('campus_bandung')), findsOneWidget);
    expect(find.text(t('sellQuota').replaceAll('{n}', '2')), findsOneWidget);

    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '6500000');
    await _type(tester, t('sellSpecs'), 'Chip M1\n8GB RAM');
    await _tap(tester, t('sellPost'));

    final listing = repo.created.single;
    expect(listing.draft.title, 'Macbook Pro M2');
    expect(listing.draft.category, ListingCategory.laptopComputer);
    expect(listing.draft.price, 6500000);
    expect(listing.draft.stock, 1);
    expect(listing.campus, Campus.bandung);
    expect(repo.stored, hasLength(1));
    expect(posted, isTrue);
  });

  testWidgets('a donation hides the price and lists at Rp0', (tester) async {
    final repo = FakeListingRepository();
    await _open(tester, repo);
    await _fillK5(tester, donation: true);

    expect(find.text(t('sellPrice')), findsNothing);
    await _choose(tester, t('sellConditionHint'), t('condition_used_good'));
    await _tap(tester, t('sellPost'));

    final draft = repo.created.single.draft;
    expect(draft.isDonation, isTrue);
    expect(listingPrice(draft), 0);
  });

  testWidgets('K5 and K6 show what is missing or out of range', (tester) async {
    final repo = FakeListingRepository();
    await _open(tester, repo);

    await _tap(tester, t('sellNext'));
    for (final f in k5Fields) {
      expect(find.text(t(f.copyKey)), findsOneWidget, reason: f.name);
    }
    expect(find.text(t('sellDetails')), findsNothing);

    await _fillK5(tester);
    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '500');
    await _type(tester, t('stock'), '0');
    await _tap(tester, t('sellPost'));
    expect(find.text(t('listingError_price')), findsOneWidget);
    expect(find.text(t('listingError_stock')), findsOneWidget);
    expect(repo.created, isEmpty);
    expect(repo.stored, isEmpty);
  });

  testWidgets('quota 0: Pasang becomes Beli Paket Kuota and the entries stay', (
    tester,
  ) async {
    final repo = FakeListingRepository(quota: 0);
    var bought = 0;
    await _open(
      tester,
      repo,
      onBuyQuota: () async {
        bought++;
        repo.quota = 3;
      },
    );
    await _fillK5(tester);
    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '75000');

    expect(find.text(t('sellQuotaEmpty')), findsOneWidget);
    expect(find.text(t('sellPost')), findsNothing);
    await _tap(tester, t('sellBuyQuota'));
    expect(bought, 1);
    expect(repo.created, isEmpty);

    // Back from K8 with a fresh balance: the entries are still there.
    expect(find.text('75000'), findsOneWidget);
    expect(find.text(t('sellQuota').replaceAll('{n}', '3')), findsOneWidget);
    await tester.tap(find.byTooltip(t('back')));
    await tester.pumpAndSettle();
    expect(find.text('Macbook Pro M2'), findsOneWidget);
  });

  testWidgets('Pasang shows loading, then an error, and removes the photos', (
    tester,
  ) async {
    final repo = FakeListingRepository()
      ..gate = Completer<void>()
      ..failCreate = const SignupException(SignupError.notAllowed);
    await _open(tester, repo);
    await _fillK5(tester);
    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '75000');

    await tester.tap(find.text(t('sellPost')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(t('errorNotAllowedToList')), findsOneWidget);
    expect(repo.stored, isEmpty);
    expect(find.text(t('sellDetails')), findsOneWidget);
  });

  testWidgets('a quota that ran out meanwhile shows its message', (
    tester,
  ) async {
    final repo = FakeListingRepository()
      ..failCreate = const SignupException(SignupError.noQuota);
    await _open(tester, repo);
    await _fillK5(tester);
    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '75000');
    await _tap(tester, t('sellPost'));
    expect(find.text(t('errorNoQuota')), findsOneWidget);
  });

  testWidgets('a photo that is not a JPEG is refused with a message', (
    tester,
  ) async {
    final repo = FakeListingRepository();
    await _open(
      tester,
      repo,
      pickPhoto: ({required camera}) async =>
          throw const PhotoException(PhotoError.unsupported),
    );
    await _addPhoto(tester);
    expect(find.text(t('errorPhotoUnsupported')), findsOneWidget);
    expect(
      find.byTooltip(t('sellRemovePhoto').replaceAll('{i}', '1')),
      findsNothing,
    );
  });

  testWidgets('a denied camera explains why the listing needs it', (
    tester,
  ) async {
    await _open(
      tester,
      FakeListingRepository(),
      pickPhoto: ({required camera}) async =>
          throw const PhotoException(PhotoError.cameraDenied),
    );
    await _addPhoto(tester);
    expect(find.text(t('sellCameraDenied')), findsOneWidget);
    expect(find.text(t('errorCameraDenied')), findsNothing);
  });

  testWidgets('K6 opens at the top after scrolling down K5', (tester) async {
    await _open(tester, FakeListingRepository());
    tester.view.physicalSize = const Size(1080, 1600);
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    await _choose(tester, t('sellCategoryHint'), t('category_laptop_computer'));
    await _addPhoto(tester);
    await _type(tester, t('sellName'), 'Macbook Pro M2');
    await _type(tester, t('description'), 'Mulus, baterai 90%');
    await tester.ensureVisible(find.text(t('sellNext')));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));
    await _tap(tester, t('sellNext'));
    expect(find.text(t('sellDetails')), findsOneWidget);
    expect(offset(), 0);
  });

  testWidgets('Pasang again after a lost answer reuses the listing id', (
    tester,
  ) async {
    final repo = FakeListingRepository(quota: 2)..loseAnswer = true;
    await _open(tester, repo);
    await _fillK5(tester);
    await _choose(tester, t('sellConditionHint'), t('condition_like_new'));
    await _type(tester, t('sellPrice'), '75000');
    await _tap(tester, t('sellPost'));
    expect(find.text(t('sellFailed')), findsOneWidget);

    repo.loseAnswer = false;
    await _tap(tester, t('sellPost'));
    expect(repo.created, hasLength(1));
    expect(repo.calls.map((l) => l.id).toSet(), hasLength(1));
    expect(repo.quota, 1);
  });

  testWidgets('the quota failing to load offers a retry', (tester) async {
    final repo = FakeListingRepository()
      ..failSeller = const SignupException(null);
    await _open(tester, repo);
    await _fillK5(tester);
    expect(find.text(t('sellLoadFailed')), findsOneWidget);
    repo.failSeller = null;
    await _tap(tester, t('retry'));
    expect(find.text(t('sellQuota').replaceAll('{n}', '1')), findsOneWidget);
  });

  group('+ in the catalog', () {
    for (final status in [null, ...AccountStatus.values]) {
      testWidgets(
        '${status?.name ?? 'guest'}: '
        '${status == AccountStatus.approved ? 'opens the form' : 'explains why not'}',
        (tester) async {
          var opened = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: beeTheme(),
              home: CatalogShell(
                repository: FakeCatalogRepository(),
                status: status,
                onSell: () async {
                  opened++;
                  return null;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(t('navSell')));
          await tester.pumpAndSettle();
          if (status == AccountStatus.approved) {
            expect(opened, 1);
          } else {
            expect(opened, 0);
            expect(
              find.text(t('sellNeedsApproval_${status?.name ?? 'guest'}')),
              findsOneWidget,
            );
          }
        },
      );
    }

    testWidgets('a posted item says it is live', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: beeTheme(),
          home: CatalogShell(
            repository: FakeCatalogRepository(),
            status: AccountStatus.approved,
            onSell: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t('navSell')));
      await tester.pumpAndSettle();
      expect(find.text(t('sellPosted')), findsOneWidget);
    });
  });
}
