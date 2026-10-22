import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/my_listings_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_listing_repository.dart';

final _now = DateTime.now();

MyListing _listing(
  String id,
  String title, {
  int stockLeft = 1,
  Duration expiresIn = const Duration(days: 10, hours: -1),
  bool removed = false,
  bool withdrawn = false,
}) => (
  id: id,
  title: title,
  category: ListingCategory.laptopComputer,
  isDonation: false,
  description: 'desc',
  condition: ListingCondition.likeNew,
  price: 50000,
  previousPrice: null,
  stock: 2,
  stockLeft: stockLeft,
  campus: Campus.bandung,
  warranty: null,
  specs: const [],
  photos: const [],
  createdAt: _now.subtract(const Duration(days: 1)),
  expiresAt: _now.add(expiresIn),
  removedAt: removed ? _now : null,
  removalReason: removed ? 'Barang terlarang' : null,
  withdrawnAt: withdrawn ? _now : null,
);

Future<void> _pump(WidgetTester tester, FakeListingRepository repo) async {
  tester.view.physicalSize = const Size(1080, 4000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: MyListingsScreen(repository: repo),
    ),
  );
}

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

Finder _inCard(String title, Finder f) =>
    find.descendant(of: _card(title), matching: f);

void main() {
  testWidgets('lists every own listing with its status, days and stock', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeListingRepository(
        mine: [
          _listing('1', 'Macbook'),
          _listing('2', 'Jaket', stockLeft: 0),
          _listing('3', 'Buku', expiresIn: const Duration(days: -1)),
          _listing('4', 'Jam', removed: true),
          _listing('5', 'Hoodie', withdrawn: true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    for (final (title, status) in [
      ('Macbook', ListingStatus.live),
      ('Jaket', ListingStatus.soldOut),
      ('Buku', ListingStatus.expired),
      ('Jam', ListingStatus.removed),
      ('Hoodie', ListingStatus.withdrawn),
    ]) {
      expect(_inCard(title, find.text(t(status.copyKey))), findsOneWidget);
    }
    expect(
      _inCard(
        'Macbook',
        find.text(t('myListingsDaysLeft').replaceAll('{n}', '10')),
      ),
      findsOneWidget,
    );
    expect(
      _inCard(
        'Macbook',
        find.text(
          t('myListingsStockLeft')
              .replaceAll('{left}', '1')
              .replaceAll('{stock}', '2'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      _inCard(
        'Jam',
        find.text(
          t('myListingsRemovedReason')
              .replaceAll('{reason}', 'Barang terlarang'),
        ),
      ),
      findsOneWidget,
    );
    expect(_inCard('Buku', find.text(t('myListingsRelist'))), findsOneWidget);
    expect(_inCard('Macbook', find.text(t('myListingsRelist'))), findsNothing);
    expect(_inCard('Jam', find.text(t('edit'))), findsNothing);
    expect(_inCard('Hoodie', find.text(t('myListingsWithdraw'))), findsNothing);
    expect(_inCard('Hoodie', find.text(t('myListingsRelist'))), findsOneWidget);
    expect(_inCard('Jam', find.text(t('myListingsRelist'))), findsNothing);
  });

  testWidgets(
    'a frozen or unapproved seller sees hidden items, withdraw only',
    (tester) async {
      final repo = FakeListingRepository(
        mine: [_listing('3', 'Buku', expiresIn: const Duration(days: -1))],
      )..sellerListed = false;
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(
        _inCard('Buku', find.text(t(ListingStatus.hidden.copyKey))),
        findsOneWidget,
      );
      expect(_inCard('Buku', find.text(t('edit'))), findsNothing);
      expect(_inCard('Buku', find.text(t('myListingsRelist'))), findsNothing);
      expect(
        _inCard('Buku', find.text(t('myListingsWithdraw'))),
        findsOneWidget,
      );
    },
  );

  testWidgets('refused by the server: says the item changed and reloads', (
    tester,
  ) async {
    final repo = FakeListingRepository(
      mine: [_listing('3', 'Buku', expiresIn: const Duration(days: -1))],
    )..failAction = const SignupException(SignupError.notAllowed);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    repo.sellerListed = false;
    await tester.tap(find.text(t('myListingsRelist')));
    await tester.pumpAndSettle();
    expect(find.text(t('myListingsStale')), findsOneWidget);
    expect(
      _inCard('Buku', find.text(t(ListingStatus.hidden.copyKey))),
      findsOneWidget,
    );
  });

  testWidgets('a failed reload after an action shows the error state', (
    tester,
  ) async {
    final repo = FakeListingRepository(
      mine: [_listing('3', 'Buku', expiresIn: const Duration(days: -1))],
    );
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    repo.failMine = const SignupException(null);
    await tester.tap(find.text(t('myListingsRelist')));
    await tester.pumpAndSettle();
    expect(find.text(t('myListingsLoadFailed')), findsOneWidget);
    expect(find.text('Buku'), findsNothing);
  });

  testWidgets('empty', (tester) async {
    await _pump(tester, FakeListingRepository());
    await tester.pumpAndSettle();
    expect(find.text(t('myListingsEmpty')), findsOneWidget);
  });

  testWidgets('loading, then an error with retry', (tester) async {
    final repo = FakeListingRepository(mine: [_listing('1', 'Macbook')])
      ..mineGate = Completer()
      ..failMine = const SignupException(null);
    await _pump(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.mineGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(t('myListingsLoadFailed')), findsOneWidget);

    repo.failMine = null;
    await tester.tap(find.text(t('retry')));
    await tester.pumpAndSettle();
    expect(find.text('Macbook'), findsOneWidget);
  });

  testWidgets('withdraw asks first, then the listing is down', (tester) async {
    final repo = FakeListingRepository(mine: [_listing('1', 'Macbook')]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(_inCard('Macbook', find.text(t('myListingsWithdraw'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel')));
    await tester.pumpAndSettle();
    expect(repo.actions, isEmpty);

    await tester.tap(_inCard('Macbook', find.text(t('myListingsWithdraw'))));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(t('myListingsWithdrawConfirm')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.actions, ['withdraw 1']);
    expect(
      _inCard('Macbook', find.text(t(ListingStatus.withdrawn.copyKey))),
      findsOneWidget,
    );
  });

  testWidgets('withdraw with a running order says why', (tester) async {
    final repo = FakeListingRepository(mine: [_listing('1', 'Macbook')])
      ..failAction = const SignupException(SignupError.listingHasOrders);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(_inCard('Macbook', find.text(t('myListingsWithdraw'))));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(t('myListingsWithdrawConfirm')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t('errorListingHasOrders')), findsOneWidget);
  });

  testWidgets('relist puts an expired listing back for 60 days', (
    tester,
  ) async {
    final repo = FakeListingRepository(
      mine: [_listing('3', 'Buku', expiresIn: const Duration(days: -1))],
    );
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('myListingsRelist')));
    await tester.pumpAndSettle();
    expect(repo.actions, ['relist 3']);
    expect(
      _inCard('Buku', find.text(t(ListingStatus.live.copyKey))),
      findsOneWidget,
    );
    expect(find.text(t('myListingsRelisted')), findsOneWidget);
  });

  testWidgets('a failed action says so and keeps the listing', (tester) async {
    final repo = FakeListingRepository(
      mine: [_listing('3', 'Buku', expiresIn: const Duration(days: -1))],
    )..failAction = const SignupException(null);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('myListingsRelist')));
    await tester.pumpAndSettle();
    expect(find.text(t('myListingsActionFailed')), findsOneWidget);
    expect(
      _inCard('Buku', find.text(t(ListingStatus.expired.copyKey))),
      findsOneWidget,
    );
  });

  testWidgets('edit changes the open fields; the name stays locked', (
    tester,
  ) async {
    final repo = FakeListingRepository(mine: [_listing('1', 'Macbook')]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(_inCard('Macbook', find.text(t('edit'))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(BeeTextField, t('sellName')), findsNothing);
    expect(find.text(t('myListingsLocked')), findsOneWidget);

    final price = find.descendant(
      of: find.widgetWithText(BeeTextField, t('sellPrice')),
      matching: find.byType(TextField),
    );
    await tester.enterText(price, '999');
    await tester.tap(find.text(t('save')));
    await tester.pumpAndSettle();
    expect(find.text(t('listingError_price')), findsOneWidget);
    expect(repo.edits, isEmpty);

    await tester.enterText(price, '40000');
    await tester.tap(find.text(t('save')));
    await tester.pumpAndSettle();
    expect(repo.edits.single.price, 40000);
    expect(find.text(formatRupiah(40000)), findsOneWidget);
    expect(find.text(t('myListingsSaved')), findsOneWidget);
  });
}
