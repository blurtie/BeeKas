import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/review_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/rejection.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/review_detail_screen.dart';
import 'package:beekas/screens/review_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beekas/ui/theme.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

PendingAccount _account(
  String id,
  String name,
  Duration waited, {
  List<Rejection> rejections = const [],
  bool photosDeleted = false,
  String? phone = '+6281234567890',
}) => (
  id: id,
  fullName: name,
  email: '$id@binus.ac.id',
  phone: phone,
  accountType: AccountType.student,
  campus: Campus.values.first,
  submittedAt: _now.subtract(waited),
  cardPath: photosDeleted ? null : '$id/1/card.jpg',
  selfiePath: photosDeleted ? null : '$id/1/selfie.jpg',
  rejections: rejections,
  photosDeleted: photosDeleted,
);

class _FakeReview implements ReviewRepository {
  List<PendingAccount> accounts = [];
  final errors = <String, SignupException>{};
  final photos = <String, Uint8List>{};
  final approved = <String>[];
  final rejected = <(String, Set<RejectionReason>, String)>[];
  final released = <(String, String)>[];
  int loads = 0;

  /// Completes [pending] when set; for the loading state.
  Completer<void>? gate;

  @override
  Future<List<PendingAccount>> pending() async {
    loads++;
    await gate?.future;
    final error = errors.remove('pending');
    if (error != null) throw error;
    return accounts;
  }

  @override
  Future<Uint8List> photo(String path) async =>
      photos[path] ?? (throw const SignupException(SignupError.unknown));

  @override
  Future<void> approve(String id) async {
    final error = errors.remove('approve');
    if (error != null) throw error;
    approved.add(id);
    accounts = accounts.where((a) => a.id != id).toList();
  }

  @override
  Future<void> reject(
    String id,
    Set<RejectionReason> reasons,
    String note,
  ) async {
    final error = errors.remove('reject');
    if (error != null) throw error;
    rejected.add((id, {...reasons}, note));
    accounts = accounts.where((a) => a.id != id).toList();
  }

  @override
  Future<void> releasePhone(String id, String note) async {
    final error = errors.remove('releasePhone');
    if (error != null) throw error;
    released.add((id, note));
  }
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

Future<void> _pumpList(WidgetTester tester, _FakeReview repo) => _pump(
  tester,
  ReviewListScreen(repository: repo, onSignOut: () {}, now: () => _now),
);

Uint8List _fixture(int orientation) =>
    File('test/fixtures/orientation_$orientation.jpg').readAsBytesSync();

void main() {
  testWidgets('L14 shows loading, then the empty state', (tester) async {
    final repo = _FakeReview()..gate = Completer();
    await _pumpList(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(t('reviewEmpty')), findsOneWidget);
  });

  testWidgets('L14 load error offers Coba lagi', (tester) async {
    final repo = _FakeReview()..errors['pending'] = const SignupException(null);
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining(t('reviewLoadFailed')), findsOneWidget);
    await tester.tap(find.text(t('retry')));
    await tester.pumpAndSettle();
    expect(find.text(t('reviewEmpty')), findsOneWidget);
  });

  testWidgets('L14 keeps the backend order and flags over 24 hours', (
    tester,
  ) async {
    final repo = _FakeReview()
      ..accounts = [
        _account('f', 'Fajar', const Duration(hours: 30)),
        _account('e', 'Eka', const Duration(minutes: 40)),
      ];
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Fajar')).dy,
      lessThan(tester.getTopLeft(find.text('Eka')).dy),
    );
    expect(find.text(t('reviewOverdue')), findsOneWidget);
    expect(find.textContaining('30 h'), findsOneWidget);
    expect(find.textContaining('40 min'), findsOneWidget);
  });

  testWidgets('L15 shows details and both photos upright, then Setujui', (
    tester,
  ) async {
    final account = _account('e', 'Eka', const Duration(hours: 2));
    final repo = _FakeReview()
      ..accounts = [account]
      ..photos['e/1/card.jpg'] = _fixture(1)
      ..photos['e/1/selfie.jpg'] = _fixture(8);
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
      for (final element in find.byType(Image).evaluate()) {
        final image = (element.widget as Image).image;
        await precacheImage(image, element);
      }
    });
    await tester.pumpAndSettle();

    for (final text in [
      'e@binus.ac.id',
      '+6281234567890',
      t('accountType_student'),
      t('card_student'),
      t(Campus.values.first.copyKey),
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final images = tester.widgetList<RawImage>(find.byType(RawImage));
    // The Orientation 8 selfie is stored 60×30 and must show 30×60.
    expect(
      [for (final i in images) (i.image!.width, i.image!.height)],
      [(30, 60), (30, 60)],
    );

    await tester.tap(find.text(t('approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t('approve')));
    await tester.pumpAndSettle();
    expect(repo.approved, ['e']);
    expect(find.text(t('approved').replaceFirst('{name}', 'Eka')), findsOne);
    expect(find.text(t('reviewEmpty')), findsOneWidget);
  });

  testWidgets('L15 says the photos were deleted under the 30-day policy', (
    tester,
  ) async {
    final repo = _FakeReview()
      ..accounts = [
        _account('e', 'Eka', const Duration(hours: 2), photosDeleted: true),
      ];
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    expect(find.text(t('reviewPhotoDeleted')), findsNWidgets(2));
    expect(find.text(t('reviewPhotoFailed')), findsNothing);
    expect(find.text(t('approve')), findsOneWidget);
  });

  testWidgets('L15 shows why approval failed and stays open', (tester) async {
    final repo = _FakeReview()
      ..accounts = [_account('e', 'Eka', const Duration(hours: 2))]
      ..errors['approve'] = const SignupException(SignupError.notPending);
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    expect(find.text(t('reviewPhotoFailed')), findsNWidgets(2));
    await tester.tap(find.text(t('approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t('approve')));
    await tester.pumpAndSettle();
    expect(find.text(t('errorNotPending')), findsOneWidget);
    expect(repo.approved, isEmpty);
  });

  testWidgets('L15 Tolak needs a reason, and a note for Other', (tester) async {
    final repo = _FakeReview()
      ..accounts = [_account('e', 'Eka', const Duration(hours: 2))];
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, t('reject')));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(TextButton, t('reject'));

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(t('rejectReasonRequired')), findsOneWidget);

    await tester.tap(find.text(t('rejectReason_card')));
    await tester.tap(find.text(t('rejectReason_other')));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(t('rejectReasonRequired')), findsNothing);
    expect(find.text(t('rejectNoteRequired')), findsOneWidget);
    expect(repo.rejected, isEmpty);

    await tester.enterText(find.byType(TextField), 'Kartu terpotong');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final (id, reasons, note) = repo.rejected.single;
    expect((id, note), ('e', 'Kartu terpotong'));
    expect(reasons, {RejectionReason.card, RejectionReason.other});
    expect(find.text(t('rejected').replaceFirst('{name}', 'Eka')), findsOne);
    expect(find.text(t('reviewEmpty')), findsOneWidget);
  });

  testWidgets('L15 Tolak: Batal changes nothing; a failure stays open', (
    tester,
  ) async {
    final repo = _FakeReview()
      ..accounts = [_account('e', 'Eka', const Duration(hours: 2))]
      ..errors['reject'] = const SignupException(SignupError.notPending);
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, t('reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, t('reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('rejectReason_data')));
    await tester.tap(find.widgetWithText(TextButton, t('reject')));
    await tester.pumpAndSettle();
    expect(find.text(t('errorNotPending')), findsOneWidget);
    expect(repo.rejected, isEmpty);
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    _FakeReview repo, {
    String? phone = '+6281234567890',
  }) => _pump(
    tester,
    ReviewDetailScreen(
      repository: repo,
      account: _account('e', 'Eka', Duration.zero, phone: phone),
    ),
  );
  final confirmRelease = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, t('releasePhone')),
  );

  testWidgets('L15 Lepas nomor HP confirms, needs a note, then hides', (
    tester,
  ) async {
    final repo = _FakeReview();
    await pumpDetail(tester, repo);
    await tester.tap(find.widgetWithText(TextButton, t('releasePhone')));
    await tester.pumpAndSettle();
    expect(
      find.text(t('releasePhoneTitle').replaceFirst('{name}', 'Eka')),
      findsOneWidget,
    );
    await tester.tap(confirmRelease);
    await tester.pumpAndSettle();
    expect(find.text(t('releasePhoneNoteRequired')), findsOneWidget);
    expect(find.text(t('releasePhoneNoteHelper')), findsNothing);

    await tester.enterText(find.byType(TextField), 'nomor 0812-3456-7890');
    await tester.tap(confirmRelease);
    await tester.pumpAndSettle();
    expect(find.text(t('errorNoteHasPhone')), findsOneWidget);
    expect(repo.released, isEmpty);

    await tester.enterText(find.byType(TextField), ' Pemilik asli ');
    await tester.tap(confirmRelease);
    await tester.pumpAndSettle();
    expect(repo.released.single, ('e', 'Pemilik asli'));
    expect(find.text(t('reviewPhoneMissing')), findsOneWidget);
    expect(find.text(t('releasePhone')), findsNothing);
    expect(find.text(t('releasePhoneDone')), findsOneWidget);
  });

  testWidgets('L15 without a phone has no Lepas nomor HP', (tester) async {
    await pumpDetail(tester, _FakeReview(), phone: null);
    expect(find.text(t('releasePhone')), findsNothing);
  });

  testWidgets('L15 Lepas nomor HP: Batal changes nothing; failure shows', (
    tester,
  ) async {
    final repo = _FakeReview()
      ..errors['releasePhone'] = const SignupException(SignupError.noPhone);
    await pumpDetail(tester, repo);
    await tester.tap(find.widgetWithText(TextButton, t('releasePhone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel')));
    await tester.pumpAndSettle();
    expect(find.text('+6281234567890'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, t('releasePhone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(confirmRelease);
    await tester.pumpAndSettle();
    expect(find.text(t('errorNoPhone')), findsOneWidget);
    expect(find.text(t('reviewPhoneMissing')), findsOneWidget);
  });

  testWidgets('L15 lists earlier rejections, newest first', (tester) async {
    final repo = _FakeReview()
      ..accounts = [
        _account(
          'e',
          'Eka',
          const Duration(hours: 2),
          rejections: [
            (
              reasons: [RejectionReason.selfie],
              note: null,
              rejectedAt: DateTime.utc(2026, 10, 19),
            ),
            (
              reasons: [RejectionReason.card, RejectionReason.other],
              note: 'Kartu terpotong',
              rejectedAt: DateTime.utc(2026, 10, 18),
            ),
          ],
        ),
      ];
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    expect(find.text(t('reviewRejections').replaceFirst('{n}', '2')), findsOne);
    final first = tester.getTopLeft(find.text(t('rejectReason_selfie')));
    final second = tester.getTopLeft(
      find.text(
        '${t('rejectReason_card')} · ${t('rejectReason_other')} · Kartu terpotong',
      ),
    );
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets('L15 without earlier rejections shows no history', (
    tester,
  ) async {
    final repo = _FakeReview()
      ..accounts = [_account('e', 'Eka', const Duration(hours: 2))];
    await _pumpList(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eka'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(t('reviewRejections').split(' (').first),
      findsNothing,
    );
  });
}
