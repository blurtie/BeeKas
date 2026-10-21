import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/order.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/screens/order_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';
import '../support/fake_order_repository.dart';

final _macbook = fakeListing('Macbook Air M1', price: 6500000);
// 11 minutes 48 seconds after the fake orders were placed.
final _start = DateTime.utc(2026, 11, 23, 9, 11, 48);
var _clock = _start;
DateTime _now() => _clock;

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

Future<void> _detail(
  WidgetTester tester,
  FakeOrderRepository repo, {
  AccountStatus? status,
}) => _pump(
  tester,
  ListingDetailScreen(
    listing: _macbook,
    status: status,
    orders: repo,
    now: _now,
  ),
);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => _clock = _start);

  group('who may order from Detail Barang', () {
    for (final status in [null, AccountStatus.pending]) {
      testWidgets('${status?.name ?? 'guest'} is told to get verified', (
        tester,
      ) async {
        final repo = FakeOrderRepository();
        await _detail(tester, repo, status: status);
        for (final key in ['booking24h', 'buyNow']) {
          await _tapText(tester, t(key));
          expect(
            find.text(t('orderNeedsApproval_${status?.name ?? 'guest'}')),
            findsOneWidget,
            reason: key,
          );
          expect(find.text(t('bookingTitle')), findsNothing);
          expect(find.text(t('checkoutTitle')), findsNothing);
        }
      });
    }
  });

  testWidgets('approved without an order backend: Segera hadir', (
    tester,
  ) async {
    await _pump(
      tester,
      ListingDetailScreen(listing: _macbook, status: AccountStatus.approved),
    );
    await _tapText(tester, t('booking24h'));
    expect(find.text(t('comingSoon')), findsOneWidget);
  });

  group('K9-K10 Booking 24 Jam', () {
    testWidgets('confirm, then the countdown', (tester) async {
      final repo = FakeOrderRepository();
      await _detail(tester, repo, status: AccountStatus.approved);
      await _tapText(tester, t('booking24h'));
      expect(find.text(t('bookingTitle')), findsOneWidget);
      expect(find.text(t('bookingNoPayment')), findsOneWidget);
      expect(
        find.text(t('campus_alam_sutera')),
        findsOneWidget,
        reason: 'Lokasi COD defaults to the listing campus',
      );

      await _tapText(tester, t('bookingConfirm'));
      expect(repo.calls, ['place Macbook Air M1 booking alam_sutera ']);
      expect(find.text(t('bookingDone')), findsOneWidget);
      expect(find.text('Macbook Air M1'), findsOneWidget);
      // Counts down to the server's hold, 23:48:12 from now.
      expect(find.text('23'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      _clock = _start.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('11'), findsOneWidget);
    });

    testWidgets('a refusal stays on K9 with the reason', (tester) async {
      final repo = FakeOrderRepository()
        ..errors['place'] = const SignupException(SignupError.soldOut);
      await _detail(tester, repo, status: AccountStatus.approved);
      await _tapText(tester, t('booking24h'));
      await _tapText(tester, t('bookingConfirm'));
      expect(find.text(t('errorSoldOut')), findsOneWidget);
      expect(find.text(t('bookingTitle')), findsOneWidget);
    });

    testWidgets('Batal goes back to the item', (tester) async {
      final repo = FakeOrderRepository();
      await _detail(tester, repo, status: AccountStatus.approved);
      await _tapText(tester, t('booking24h'));
      await _tapText(tester, t('cancel'));
      await tester.pumpAndSettle();
      expect(find.text(t('bookingTitle')), findsNothing);
      expect(repo.calls, isEmpty);
    });
  });

  group('K11 Checkout', () {
    testWidgets('Lokasi COD, COD only, qty 1, no shipping or extra fees', (
      tester,
    ) async {
      final repo = FakeOrderRepository();
      await _detail(tester, repo, status: AccountStatus.approved);
      await _tapText(tester, t('buyNow'));
      expect(find.text(t('checkoutTitle')), findsOneWidget);
      expect(find.text(t('codLocation')), findsOneWidget);
      expect(find.text(t('codMethod')), findsOneWidget);
      expect(find.text('qty: 1'), findsOneWidget);
      expect(find.textContaining('Pengiriman'), findsNothing);
      expect(find.textContaining('Shipping'), findsNothing);
      expect(find.textContaining('Delicery'), findsNothing);
      expect(find.text('Biaya Lainnya'), findsNothing);

      await _tapText(tester, t('change'));
      await tester.enterText(
        find.widgetWithText(TextField, t('codPlace')),
        'Lobi Anggrek',
      );
      await _tapText(tester, t('save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Lobi Anggrek'), findsOneWidget);

      await _tapText(tester, t('checkoutConfirm'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['place Macbook Air M1 buy alam_sutera Lobi Anggrek']);
      expect(find.text(t('ordersTitle')), findsOneWidget);
    });

    testWidgets('the third donation shows the limit', (tester) async {
      final repo = FakeOrderRepository()
        ..errors['place'] = const SignupException(SignupError.donationLimit);
      await _detail(tester, repo, status: AccountStatus.approved);
      await _tapText(tester, t('buyNow'));
      await _tapText(tester, t('checkoutConfirm'));
      expect(find.text(t('errorDonationLimit')), findsOneWidget);
    });
  });

  group('K12 Pesanan Saya', () {
    Future<void> list(WidgetTester tester, FakeOrderRepository repo) =>
        _pump(tester, OrdersScreen(repository: repo, now: _now));

    testWidgets('loading, then an empty tab', (tester) async {
      final repo = FakeOrderRepository()..gate = Completer();
      await list(tester, repo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(t('ordersEmpty')), findsOneWidget);
    });

    testWidgets('dates and statuses follow the app language', (tester) async {
      addTearDown(() => language.value = Lang.en);
      language.value = Lang.id;
      tester.view.physicalSize = const Size(900, 2400); // 360 dp
      final repo = FakeOrderRepository()
        ..add(createdAt: DateTime(2026, 10, 8, 14, 20));
      await tester.pumpWidget(
        MaterialApp(
          theme: beeTheme(),
          home: OrdersScreen(repository: repo, now: _now),
        ),
      );
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2.5;
      await tester.pumpAndSettle();
      expect(find.text('8 Oktober 2026, 14:20'), findsOneWidget);
      expect(find.text('Menunggu konfirmasi penjual'), findsOneWidget);
      // Every chip is on screen, none scrolled away.
      for (final key in [
        'all',
        'waiting',
        'processing',
        'completed',
        'cancelled',
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, t('orderFilter_$key')).hitTestable(),
          findsOneWidget,
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('an error offers Coba lagi', (tester) async {
      final repo = FakeOrderRepository()
        ..errors['mine'] = const SignupException(null)
        ..add();
      await list(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(t('ordersLoadFailed')), findsOneWidget);
      await tester.tap(find.text(t('retry')));
      await tester.pumpAndSettle();
      expect(find.text('Macbook Air M1'), findsOneWidget);
    });

    testWidgets('tabs split purchases and sales; chips filter by status', (
      tester,
    ) async {
      final repo = FakeOrderRepository()
        ..add(title: 'Booking saya')
        ..add(title: 'Beli selesai', status: OrderStatus.completed)
        ..add(title: 'Jualan masuk', isBuyer: false);
      await list(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Booking saya'), findsOneWidget);
      expect(find.text('Beli selesai'), findsOneWidget);
      expect(find.text('Jualan masuk'), findsNothing);
      for (final key in [
        'all',
        'waiting',
        'processing',
        'completed',
        'cancelled',
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, t('orderFilter_$key')),
          findsOneWidget,
          reason: key,
        );
      }
      expect(find.text('Dikirim'), findsNothing);
      // The waiting booking shows its status and the time left.
      expect(find.text(t('orderStatus_waiting')), findsOneWidget);
      expect(
        find.text(t('holdLeft').replaceAll('{time}', '23:48')),
        findsOneWidget,
      );

      final completed = find.widgetWithText(
        ChoiceChip,
        t('orderFilter_completed'),
      );
      await tester.ensureVisible(completed);
      await tester.pumpAndSettle();
      await tester.tap(completed);
      await tester.pumpAndSettle();
      expect(find.text('Booking saya'), findsNothing);
      expect(find.text('Beli selesai'), findsOneWidget);

      await tester.tap(find.text(t('ordersSales')));
      await tester.pumpAndSettle();
      final all = find.widgetWithText(ChoiceChip, t('orderFilter_all'));
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Jualan masuk'), findsOneWidget);
      expect(find.text('Booking saya'), findsNothing);
    });
  });

  group('K13 Detail Pesanan', () {
    Future<void> open(WidgetTester tester, FakeOrderRepository repo) async {
      await _pump(tester, OrdersScreen(repository: repo, now: _now));
      await tester.pumpAndSettle();
      if (!repo.orders.first.isBuyer) {
        await tester.tap(find.text(t('ordersSales')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(repo.orders.first.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('buyer of a waiting booking: Batalkan and Minta perpanjangan', (
      tester,
    ) async {
      final repo = FakeOrderRepository()..add();
      await open(tester, repo);
      expect(find.text(t('orderKind_booking')), findsOneWidget);
      expect(find.text(t('campus_alam_sutera')), findsOneWidget);
      expect(find.textContaining('Lobi Anggrek'), findsOneWidget);
      expect(find.text(t('orderAction_cancel')), findsOneWidget);
      expect(find.text(t('orderAction_accept')), findsNothing);
      expect(find.text(t('orderAction_complete')), findsNothing);

      await _tapText(tester, t('orderAction_requestExtension'));
      expect(repo.calls, ['requestExtension o0']);
      expect(find.text(t('orderAction_requestExtension')), findsNothing);
    });

    testWidgets('the seller chats with the buyer', (tester) async {
      final repo = FakeOrderRepository()..add(isBuyer: false);
      await open(tester, repo);
      expect(find.text(t('chatBuyer')), findsOneWidget);
      expect(find.text(t('chatSeller')), findsNothing);
    });

    testWidgets('seller accepts with a COD time', (tester) async {
      final repo = FakeOrderRepository()..add(isBuyer: false);
      await open(tester, repo);
      await _tapText(tester, t('orderAction_accept'));
      // Date picker, then time picker.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.calls, ['accept o0']);
      // The current minute is still allowed.
      final local = _start.toLocal();
      expect(
        repo.acceptedAt,
        DateTime(local.year, local.month, local.day, local.hour, local.minute),
      );
      expect(find.text(t('orderStatus_processing')), findsOneWidget);
    });

    testWidgets('cancel needs a reason, and a note for Lainnya', (
      tester,
    ) async {
      final repo = FakeOrderRepository()..add();
      await open(tester, repo);
      await _tapText(tester, t('orderAction_cancel'));
      await _tapText(tester, t('cancelOrder'));
      expect(find.text(t('cancelReasonRequired')), findsOneWidget);
      expect(repo.calls, isEmpty);

      await _tapText(tester, t('cancelReason_other'));
      await _tapText(tester, t('cancelOrder'));
      expect(find.text(t('cancelReasonRequired')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sudah beli');
      await _tapText(tester, t('cancelOrder'));
      expect(repo.calls, ['cancel o0 other Sudah beli']);
      expect(find.text(t('orderStatus_cancelled')), findsOneWidget);
    });

    testWidgets('buyer of a processing order confirms receipt', (tester) async {
      final repo = FakeOrderRepository()
        ..add(
          status: OrderStatus.processing,
          codAt: DateTime.utc(2026, 11, 24, 6),
        );
      await open(tester, repo);
      expect(find.text(t('orderAction_requestExtension')), findsNothing);
      await _tapText(tester, t('orderAction_complete'));
      expect(repo.calls, ['complete o0']);
      expect(find.text(t('orderStatus_completed')), findsOneWidget);
      expect(find.text(t('orderAction_cancel')), findsNothing);
    });

    testWidgets('a changed order explains and shows the new state', (
      tester,
    ) async {
      final repo = FakeOrderRepository()
        ..add(status: OrderStatus.processing, codAt: _now())
        ..errors['complete'] = const SignupException(
          SignupError.orderTransition,
        );
      await open(tester, repo);
      await _tapText(tester, t('orderAction_complete'));
      expect(find.text(t('errorOrderTransition')), findsOneWidget);
    });
  });
}
