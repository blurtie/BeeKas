import 'package:beekas/config/copy.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/screens/order_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';
import '../support/fake_order_repository.dart';

final _als = fakeListing('Kipas Angin', campus: Campus.alamSutera);
final _bdg = fakeListing('Rice Cooker', campus: Campus.bandung);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: home));
  await tester.pumpAndSettle();
}

CatalogShell _shell(
  FakeCatalogRepository repo, {
  Campus? campus,
  AccountStatus? status = AccountStatus.approved,
  FakeOrderRepository? orders,
}) => CatalogShell(
  repository: repo,
  status: status,
  campus: campus,
  fullName: 'Clarencia Augustine',
  orders: orders,
  onQuota: () {},
  onMyListings: () {},
  onSignOut: () {},
);

void main() {
  group('Lokasi (D-47)', () {
    testWidgets('cards carry the campus tag', (tester) async {
      await _pump(tester, _shell(FakeCatalogRepository([_als, _bdg])));
      expect(find.text('ALS'), findsOneWidget);
      expect(find.text('BDG'), findsOneWidget);
    });

    testWidgets('guests and BINUS Online start with every location', (
      tester,
    ) async {
      final repo = FakeCatalogRepository([_als, _bdg]);
      await _pump(tester, _shell(repo, campus: Campus.online));
      expect(repo.lastCampuses, isNull);
      expect(find.text(t('locationAll')), findsOneWidget);
    });

    testWidgets('members start in their area and can widen it', (
      tester,
    ) async {
      final repo = FakeCatalogRepository([_als, _bdg]);
      await _pump(tester, _shell(repo, campus: Campus.kemanggisan));
      expect(repo.lastCampuses, [
        Campus.kemanggisan,
        Campus.senayan,
        Campus.alamSutera,
        Campus.aso,
        Campus.bekasi,
      ]);
      final myArea = t(
        'locationMyArea',
      ).replaceAll('{area}', t('area_jabodetabek'));
      expect(find.text(myArea), findsOneWidget);
      expect(find.text('Kipas Angin'), findsOneWidget);
      expect(find.text('Rice Cooker'), findsNothing);

      await tester.tap(find.text(myArea));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('locationAll')).last);
      await tester.pumpAndSettle();
      expect(repo.lastCampuses, isNull);
      expect(find.text('Rice Cooker'), findsOneWidget);
    });

    testWidgets('one campus can be chosen', (tester) async {
      final repo = FakeCatalogRepository([_als, _bdg]);
      await _pump(tester, _shell(repo));
      await tester.tap(find.text(t('locationAll')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t(Campus.alamSutera.copyKey)).last);
      await tester.pumpAndSettle();
      expect(repo.lastCampuses, [Campus.alamSutera]);
      expect(find.text('Rice Cooker'), findsNothing);
    });

    testWidgets('items outside the area show why and cannot be ordered', (
      tester,
    ) async {
      final orders = FakeOrderRepository();
      await _pump(
        tester,
        ListingDetailScreen(
          listing: _als,
          status: AccountStatus.approved,
          memberCampus: Campus.bandung,
          orders: orders,
        ),
      );
      expect(
        find.text(
          t('outOfAreaNote').replaceAll('{area}', t('area_jabodetabek')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(t('buyNow')));
      await tester.pump();
      expect(find.text(t('errorOutOfArea')), findsOneWidget);
      expect(find.text(t('checkoutTitle')), findsNothing);
    });

    testWidgets('items in the area can be ordered', (tester) async {
      await _pump(
        tester,
        ListingDetailScreen(
          listing: _als,
          status: AccountStatus.approved,
          memberCampus: Campus.kemanggisan,
          orders: FakeOrderRepository(),
        ),
      );
      expect(find.textContaining(t('area_jabodetabek')), findsNothing);
      await tester.tap(find.text(t('buyNow')));
      await tester.pumpAndSettle();
      expect(find.text(t('checkoutTitle')), findsOneWidget);
    });
  });

  group('K17 Profil', () {
    testWidgets('shows the member and opens Pesanan Saya by status', (
      tester,
    ) async {
      await _pump(
        tester,
        _shell(
          FakeCatalogRepository(),
          campus: Campus.alamSutera,
          orders: FakeOrderRepository(),
        ),
      );
      await tester.tap(find.text(t('navProfile')));
      await tester.pumpAndSettle();
      expect(find.text('Clarencia Augustine'), findsOneWidget);
      expect(find.text(t('verified')), findsOneWidget);
      expect(find.textContaining('ALS'), findsOneWidget);
      expect(find.text(t('profileMyListings')), findsOneWidget);
      expect(find.text(t('profileLanguage')), findsOneWidget);

      await tester.tap(find.text(t('profileOrders_completed')));
      await tester.pumpAndSettle();
      expect(find.byType(OrdersScreen), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, t('orderFilter_completed')),
      );
      expect(chip.selected, isTrue);
    });
  });
}
