import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/payment_repository.dart';
import 'package:beekas/data/review_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/payment.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/screens/payment_screens.dart';
import 'package:beekas/screens/review_list_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';
import '../support/fake_payment_repository.dart';

/// The admin home with nobody waiting.
class _NoReviews implements ReviewRepository {
  @override
  Future<List<PendingAccount>> pending() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _now = DateTime.utc(2026, 10, 21, 12);
final _proof = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

Future<void> _pumpQuota(
  WidgetTester tester,
  FakePaymentRepository repo, {
  Uint8List? picked,
}) => _pump(
  tester,
  QuotaScreen(repository: repo, pickProof: () async => picked ?? _proof),
);

PendingPayment _pending(String id, String name, Duration waited) => (
  id: id,
  memberName: name,
  memberEmail: '$id@binus.ac.id',
  kind: PaymentKind.package,
  amount: 15000,
  createdAt: _now.subtract(waited),
  proofPath: '$id/proof.jpg',
);

Future<void> _pumpAdmin(WidgetTester tester, FakePaymentRepository repo) =>
    _pump(tester, PaymentListScreen(repository: repo, now: () => _now));

String _pendingText() => t('paymentStatus_pending');

void main() {
  group('K8 Kuota Listing', () {
    testWidgets('loading, then the balance and an empty history', (
      tester,
    ) async {
      final repo = FakePaymentRepository(quota: 1)..gate = Completer();
      await _pumpQuota(tester, repo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(t('quotaLeft').replaceAll('{n}', '1')), findsOneWidget);
      expect(find.text(t('quotaHistoryEmpty')), findsOneWidget);
    });

    testWidgets('a load error offers Coba lagi', (tester) async {
      final repo = FakePaymentRepository()
        ..errors['overview'] = const SignupException(null);
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(t('sellLoadFailed')), findsOneWidget);
      await tester.tap(find.text(t('retry')));
      await tester.pumpAndSettle();
      expect(find.text(t('quotaHistoryEmpty')), findsOneWidget);
    });

    testWidgets('history shows waiting, confirmed, and rejected with reason', (
      tester,
    ) async {
      final repo = FakePaymentRepository(quota: 3)
        ..add(PaymentStatus.confirmed)
        ..add(PaymentStatus.rejected, reason: 'Bukti buram')
        ..add(PaymentStatus.pending);
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(_pendingText()), findsOneWidget);
      expect(find.text(t('paymentStatus_confirmed')), findsOneWidget);
      expect(find.text(t('paymentStatus_rejected')), findsOneWidget);
      expect(
        find.text(t('paymentReason').replaceAll('{reason}', 'Bukti buram')),
        findsOneWidget,
      );
      expect(find.text(t('paymentReupload')), findsOneWidget);
    });

    testWidgets('Beli paket shows the QRIS and the price, then sends a proof', (
      tester,
    ) async {
      final repo = FakePaymentRepository();
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_buyLabel()));
      await tester.pumpAndSettle();

      // Zero-sized until decoded, so the finder must look offstage too.
      expect(find.image(repo.qris, skipOffstage: false), findsOneWidget);
      expect(find.text(formatRupiah(15000)), findsOneWidget);
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();

      expect(repo.submitted, [_proof]);
      expect(find.text(t('qrisSent')), findsOneWidget);
      expect(find.text(_pendingText()), findsOneWidget);
    });

    testWidgets('backing out of the picker sends nothing', (tester) async {
      final repo = FakePaymentRepository();
      await _pump(
        tester,
        QuotaScreen(repository: repo, pickProof: () async => null),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_buyLabel()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();
      expect(repo.submitted, isEmpty);
      expect(find.text(t('qrisUpload')), findsOneWidget);
    });

    testWidgets('a failed send stays on the QRIS with an error', (
      tester,
    ) async {
      final repo = FakePaymentRepository()
        ..errors['recordPayment'] = const SignupException(null);
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_buyLabel()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();
      expect(find.text(t('qrisFailed')), findsOneWidget);
      expect(repo.payments, isEmpty);
    });

    testWidgets('a payment still waiting blocks another one (D-43)', (
      tester,
    ) async {
      final repo = FakePaymentRepository()
        ..errors['recordPayment'] = const SignupException(
          SignupError.paymentPending,
        );
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_buyLabel()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();
      expect(find.text(t('errorPaymentPending')), findsOneWidget);
      expect(repo.uploads, isEmpty, reason: 'the refused proof is deleted');
    });

    testWidgets('a payment found waiting before upload sends nothing (D-43)', (
      tester,
    ) async {
      final repo = FakePaymentRepository();
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_buyLabel()));
      await tester.pumpAndSettle();
      // Paid from another device meanwhile.
      repo.add(PaymentStatus.pending);
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();
      expect(find.text(t('errorPaymentPending')), findsOneWidget);
      expect(repo.uploads, isEmpty);
    });

    testWidgets('Unggah ulang after a rejection sends a new proof', (
      tester,
    ) async {
      final repo = FakePaymentRepository()
        ..add(PaymentStatus.rejected, reason: 'Nominal kurang');
      await _pumpQuota(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('paymentReupload')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('qrisUpload')));
      await tester.pumpAndSettle();
      expect(repo.submitted, hasLength(1));
      expect(find.text(_pendingText()), findsOneWidget);
    });
  });

  group('K18 Pembayaran (admin)', () {
    testWidgets('loading, then the empty state', (tester) async {
      final repo = FakePaymentRepository()..gate = Completer();
      await _pumpAdmin(tester, repo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(t('paymentsEmpty')), findsOneWidget);
    });

    testWidgets('a load error offers Coba lagi', (tester) async {
      final repo = FakePaymentRepository()
        ..errors['pending'] = const SignupException(null);
      await _pumpAdmin(tester, repo);
      await tester.pumpAndSettle();
      expect(find.textContaining(t('paymentsLoadFailed')), findsOneWidget);
      await tester.tap(find.text(t('retry')));
      await tester.pumpAndSettle();
      expect(find.text(t('paymentsEmpty')), findsOneWidget);
    });

    testWidgets('keeps the oldest first and flags over 24 hours', (
      tester,
    ) async {
      final repo = FakePaymentRepository();
      repo.pendingList.addAll([
        _pending('f', 'Fajar', const Duration(hours: 30)),
        _pending('e', 'Eka', const Duration(minutes: 40)),
      ]);
      await _pumpAdmin(tester, repo);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Fajar')).dy,
        lessThan(tester.getTopLeft(find.text('Eka')).dy),
      );
      expect(find.text(t('reviewOverdue')), findsOneWidget);
    });

    testWidgets('Konfirmasi needs the amount received, then confirms', (
      tester,
    ) async {
      final repo = FakePaymentRepository()
        ..proofs['e/proof.jpg'] = File('test/fixtures/orientation_1.jpg')
            .readAsBytesSync();
      repo.pendingList.add(_pending('e', 'Eka', const Duration(hours: 2)));
      await _pumpAdmin(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eka'));
      await tester.pumpAndSettle();

      expect(find.text('e@binus.ac.id'), findsOneWidget);
      expect(find.text(formatRupiah(15000)), findsOneWidget);
      await tester.tap(find.text(t('paymentConfirm')));
      await tester.pumpAndSettle();
      expect(find.text(t('paymentReceivedInvalid')), findsOneWidget);
      expect(repo.confirmed, isEmpty);

      await tester.enterText(find.byType(TextField), '15000');
      await tester.tap(find.text(t('paymentConfirm')));
      await tester.pumpAndSettle();
      expect(repo.confirmed, [('e', 15000)]);
      expect(
        find.text(t('paymentConfirmed').replaceAll('{name}', 'Eka')),
        findsOneWidget,
      );
      expect(find.text(t('paymentsEmpty')), findsOneWidget);
    });

    testWidgets('Tolak needs a reason, then rejects', (tester) async {
      final repo = FakePaymentRepository();
      repo.pendingList.add(_pending('e', 'Eka', const Duration(hours: 2)));
      await _pumpAdmin(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eka'));
      await tester.pumpAndSettle();
      // The proof failed to load; the admin can still reject.
      expect(find.text(t('paymentProofFailed')), findsOneWidget);

      await tester.tap(find.text(t('reject')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t('reject')));
      await tester.pumpAndSettle();
      expect(find.text(t('paymentReasonRequired')), findsOneWidget);
      expect(repo.rejected, isEmpty);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Bukti buram',
      );
      await tester.tap(find.widgetWithText(TextButton, t('reject')));
      await tester.pumpAndSettle();
      expect(repo.rejected, [('e', 'Bukti buram')]);
      expect(
        find.text(t('paymentRejected').replaceAll('{name}', 'Eka')),
        findsOneWidget,
      );
    });

    testWidgets('decided by another admin meanwhile: says so', (tester) async {
      final repo = FakePaymentRepository()
        ..errors['confirm'] = const SignupException(SignupError.notPending);
      repo.pendingList.add(_pending('e', 'Eka', const Duration(hours: 2)));
      await _pumpAdmin(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eka'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15000');
      await tester.tap(find.text(t('paymentConfirm')));
      await tester.pumpAndSettle();
      expect(find.text(t('paymentNotPending')), findsOneWidget);
    });
  });

  group('admin menu', () {
    testWidgets('the admin home opens Pembayaran', (tester) async {
      final payments = FakePaymentRepository();
      await _pump(
        tester,
        Builder(
          builder: (context) => ReviewListScreen(
            repository: _NoReviews(),
            onSignOut: () {},
            onPayments: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentListScreen(repository: payments),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('paymentsAdminTitle')));
      await tester.pumpAndSettle();
      expect(find.text(t('paymentsEmpty')), findsOneWidget);
    });

    testWidgets('members do not get it', (tester) async {
      await _pump(
        tester,
        CatalogShell(repository: FakeCatalogRepository(), onSignOut: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text(t('paymentsAdminTitle')), findsNothing);
    });
  });
}

String _buyLabel() =>
    t('quotaBuy')
        .replaceAll('{price}', formatRupiah(PaymentKind.package.amount));
