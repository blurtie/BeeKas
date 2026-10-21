import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';

final _macbook = fakeListing(
  'Macbook Air M1',
  category: ListingCategory.laptopComputer,
  price: 6500000,
  previousPrice: 7500000,
  specs: ['Chip Apple M1', '8GB RAM'],
  photos: ['a.jpg', 'b.jpg', 'c.jpg'],
);
final _jaket = fakeListing(
  'Jaket Uniqlo',
  category: ListingCategory.clothing,
  price: 250000,
  sellerName: 'Raka Contoh',
  stock: 2,
);
final _buku = fakeListing(
  'Buku Exploring English',
  category: ListingCategory.booksStationery,
  price: 0,
  isDonation: true,
);

/// Item 01..Item n, newest first, in Others.
List<Listing> _items(int n) => [
  for (var i = 1; i <= n; i++) fakeListing('Item ${'$i'.padLeft(2, '0')}'),
];

/// Past the search debounce, then the server's answer.
Future<void> _typed(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  FakeCatalogRepository repository, {
  VoidCallback? onSignOut,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: CatalogShell(repository: repository, onSignOut: onSignOut),
    ),
  );
}

void main() {
  testWidgets('Beranda: loading, then newest-first cards with prices', (
    tester,
  ) async {
    final repository = FakeCatalogRepository([_macbook, _jaket, _buku])
      ..gate = Completer();
    await _pump(tester, repository);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(t('recommended')), findsOneWidget);
    expect(find.text('Rp 6.500.000'), findsOneWidget);
    expect(find.text('Rp 250.000'), findsOneWidget);
    final titles = tester
        .widgetList<Text>(find.textContaining(RegExp('^(Macbook|Jaket|Buku)')))
        .map((w) => w.data)
        .toList();
    expect(titles, [
      'Macbook Air M1',
      'Jaket Uniqlo',
      'Buku Exploring English',
    ]);
    await tester.scrollUntilVisible(
      find.text(t('free')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(t('donation')), findsOneWidget);
  });

  testWidgets('Beranda search: text to the server, label word adds category', (
    tester,
  ) async {
    final repository = FakeCatalogRepository([_macbook, _jaket, _buku]);
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    final search = find.byType(TextField);

    await tester.enterText(search, 'raka');
    await _typed(tester);
    expect(find.text('Jaket Uniqlo'), findsOneWidget);
    expect(find.text('Macbook Air M1'), findsNothing);

    await tester.enterText(search, 'komputer');
    await _typed(tester);
    expect(repository.lastMatched, [ListingCategory.laptopComputer]);
    expect(repository.lastCategories, isNull);
    expect(find.text('Macbook Air M1'), findsOneWidget);
    expect(find.text('Jaket Uniqlo'), findsNothing);

    await tester.enterText(search, 'zzz');
    await _typed(tester);
    expect(find.text(t('searchEmpty')), findsOneWidget);

    await tester.enterText(search, 'shoes');
    await _typed(tester);
    expect(repository.lastMatched, [ListingCategory.shoes]);
    expect(find.text(t('searchEmpty')), findsOneWidget);
  });

  testWidgets('Beranda: error with retry, then an empty catalog', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..fail = const SignupException(null);
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text(t('catalogError')), findsOneWidget);

    await tester.tap(find.text(t('retry')));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text(t('catalogEmpty')), findsOneWidget);
  });

  testWidgets('Beranda loads the next page on scroll; error and retry at end', (
    tester,
  ) async {
    final repository = FakeCatalogRepository(_items(45));
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    await _scrollTo(tester, find.text('Item 25'));
    expect(repository.calls, 2);

    repository.fail = const SignupException(null);
    await _scrollTo(tester, find.text(t('catalogError')));
    await tester.tap(find.text(t('retry')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Item 45'));
    expect(repository.calls, 4);
    expect(find.text('Item 01'), findsNothing, reason: 'scrolled away');
  });

  testWidgets('Kategori results load on scroll, with loading and empty end', (
    tester,
  ) async {
    final repository = FakeCatalogRepository(_items(25));
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('navCategories')).last);
    await tester.pumpAndSettle();

    repository.gate = Completer();
    await tester.tap(find.text(t('category_other')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Item 25'));
    expect(repository.calls, 3, reason: 'Beranda, then two pages');

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('category_shoes')));
    await tester.pumpAndSettle();
    expect(find.text(t('catalogEmpty')), findsOneWidget);
  });

  testWidgets('Beranda shortcut Fashion lists clothing only', (tester) async {
    await _pump(tester, FakeCatalogRepository([_macbook, _jaket]));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('group_fashion')));
    await tester.pumpAndSettle();
    expect(find.text('Jaket Uniqlo'), findsOneWidget);
    expect(find.text('Macbook Air M1'), findsNothing);
  });

  testWidgets('+ says coming soon; Profil offers sign-out when signed in', (
    tester,
  ) async {
    var signedOut = false;
    await _pump(
      tester,
      FakeCatalogRepository([_jaket]),
      onSignOut: () => signedOut = true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t('navSell')));
    await tester.pump();
    expect(find.text(t('comingSoon')), findsOneWidget);

    await tester.tap(find.text(t('navProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('signOut')));
    expect(signedOut, isTrue);
  });

  testWidgets('Kategori: 9 tiles, chips and search filter, tile opens items', (
    tester,
  ) async {
    final repository = FakeCatalogRepository([_macbook, _jaket]);
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('navCategories')).last);
    await tester.pumpAndSettle();
    for (final c in ListingCategory.values) {
      expect(find.text(t(c.copyKey)), findsOneWidget, reason: c.name);
    }

    await tester.ensureVisible(find.text(t('group_books')));
    await tester.tap(find.text(t('group_books')));
    await tester.pumpAndSettle();
    expect(find.text(t('category_books_stationery')), findsOneWidget);
    expect(find.text(t('category_clothing')), findsNothing);

    await tester.ensureVisible(find.text(t('group_all')));
    await tester.tap(find.text(t('group_all')));
    await tester.enterText(find.byType(TextField), 'cloth');
    await tester.pumpAndSettle();
    expect(find.text(t('category_shoes')), findsNothing);
    await tester.tap(find.text(t('category_clothing')));
    await tester.pumpAndSettle();
    expect(repository.lastCategories, [ListingCategory.clothing]);
    expect(find.text('Jaket Uniqlo'), findsOneWidget);
    expect(find.text('Macbook Air M1'), findsNothing);
  });

  testWidgets('Detail: gallery, struck price, seller, info, specs, buttons', (
    tester,
  ) async {
    await _pump(tester, FakeCatalogRepository([_macbook]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Macbook Air M1'));
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Rp 7.500.000'), findsOneWidget);
    expect(find.text('-13%'), findsOneWidget);
    expect(find.text('Nadia Contoh'), findsOneWidget);
    expect(find.text(t('verified')), findsOneWidget);
    expect(find.text(t('condition_used_good')), findsOneWidget);
    expect(find.text('-'), findsOneWidget, reason: 'no warranty');
    await tester.scrollUntilVisible(
      find.text('Chip Apple M1  |  8GB RAM'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('@'), findsNothing, reason: 'no email (D-26)');

    await tester.tap(
      find
          .bySemanticsLabel(
            t('photoCount').replaceAll('{i}', '3').replaceAll('{n}', '3'),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    for (final key in ['chatSeller', 'booking24h', 'buyNow']) {
      await tester.tap(find.text(t(key)));
      await tester.pump();
      expect(find.text(t('comingSoon')), findsOneWidget, reason: key);
    }
  });

  testWidgets('Detail of a donation shows Free and no struck price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: beeTheme(),
        home: ListingDetailScreen(listing: _buku),
      ),
    );
    expect(find.text(t('free')), findsOneWidget);
    expect(find.text(t('donation')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('Indonesian labels follow the language', (tester) async {
    addTearDown(() => language.value = Lang.en);
    language.value = Lang.id;
    await _pump(tester, FakeCatalogRepository([_jaket]));
    await tester.pumpAndSettle();
    expect(find.text('Rekomendasi untuk Kamu'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
  });
}
