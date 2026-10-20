import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/auth_repository.dart';
import 'package:beekas/data/review_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/debug_sign_in_screen.dart';
import 'package:beekas/screens/review_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beekas/ui/theme.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

PendingAccount _account(String id, String name, Duration waited) => (
  id: id,
  fullName: name,
  email: '$id@binus.ac.id',
  phone: '+6281234567890',
  accountType: AccountType.student,
  campus: Campus.values.first,
  submittedAt: _now.subtract(waited),
  cardPath: '$id/1/card.jpg',
  selfiePath: '$id/1/selfie.jpg',
);

class _FakeReview implements ReviewRepository {
  List<PendingAccount> accounts = [];
  final errors = <String, SignupException>{};
  final photos = <String, Uint8List>{};
  final approved = <String>[];
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

  group('debug admin entry', () {
    Future<(_FakeAuth, List<String>)> signIn(
      WidgetTester tester,
      Role role,
    ) async {
      final auth = _FakeAuth(role);
      final opened = <String>[];
      await _pump(
        tester,
        DebugSignInScreen(repository: auth, onAdmin: () => opened.add('L14')),
      );
      await tester.enterText(find.byType(TextField).first, 'x@beekas.test');
      await tester.enterText(find.byType(TextField).last, 'secret123');
      await tester.tap(find.text(t('signIn')));
      await tester.pumpAndSettle();
      return (auth, opened);
    }

    testWidgets('admin opens L14', (tester) async {
      final (auth, opened) = await signIn(tester, Role.admin);
      expect(opened, ['L14']);
      expect(auth.calls, ['signIn', 'account']);
    });

    testWidgets('a member opens nothing and is signed out', (tester) async {
      final (auth, opened) = await signIn(tester, Role.member);
      expect(opened, isEmpty);
      expect(auth.calls, ['signIn', 'account', 'signOut']);
      expect(find.textContaining('Not available yet'), findsOneWidget);
    });
  });
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.role);
  final Role role;
  final calls = <String>[];

  @override
  Future<void> signIn(String email, String password) async =>
      calls.add('signIn');

  @override
  Future<({Role role, AccountStatus status})> account() async {
    calls.add('account');
    return (role: role, status: AccountStatus.approved);
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
}
