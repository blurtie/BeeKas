import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/auth_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/sign_in.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/sign_in_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Account _admin = (
  role: Role.admin,
  status: AccountStatus.approved,
  accountType: AccountType.staff,
  hasPassword: true,
  hasConsent: false,
);

class _FakeAuth implements AuthRepository {
  SignupException? error;
  SignupException? accountError;
  Completer<void>? gate;
  final calls = <String>[];

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn $email');
    await gate?.future;
    if (error case final e?) throw e;
  }

  @override
  Future<Account> account() async {
    calls.add('account');
    if (accountError case final e?) throw e;
    return _admin;
  }

  @override
  bool get signedIn => false;

  @override
  Future<void> signOut() async => calls.add('signOut');
}

Future<List<Account>> _pump(
  WidgetTester tester,
  _FakeAuth auth, {
  String? email,
}) async {
  final signedIn = <Account>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: SignInScreen(
        repository: auth,
        initialEmail: email,
        onSignedIn: signedIn.add,
        onRegister: () {},
        onBrowse: () {},
        onTerms: () {},
        onPrivacy: () {},
      ),
    ),
  );
  return signedIn;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'a@binus.ac.id');
  await tester.enterText(find.byType(TextField).last, 'secret123');
  await tester.tap(find.widgetWithText(FilledButton, t('signIn')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signs in and hands over the account', (tester) async {
    final auth = _FakeAuth();
    final signedIn = await _pump(tester, auth);
    await _submit(tester);
    expect(auth.calls, ['signIn a@binus.ac.id', 'account']);
    expect(signedIn, [_admin]);
  });

  testWidgets('empty fields ask for input without calling the server', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _pump(tester, auth);
    await tester.tap(find.widgetWithText(FilledButton, t('signIn')));
    await tester.pump();
    expect(find.text(t('emailRequired')), findsOneWidget);
    expect(find.text(t('passwordRequired')), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  for (final (error, key) in [
    (
      const SignupException(SignupError.invalidCredentials),
      'errorInvalidCredentials',
    ),
    (const SignupException(null), 'errorNetwork'),
    (const SignupException(SignupError.rateLimited), 'errorRateLimited'),
    (const SignupException(SignupError.unknown), 'errorSignInFailed'),
  ]) {
    testWidgets('${error.error} shows $key', (tester) async {
      final auth = _FakeAuth()..error = error;
      final signedIn = await _pump(tester, auth);
      await _submit(tester);
      expect(find.text(t(key)), findsOneWidget);
      expect(signedIn, isEmpty);
    });
  }

  testWidgets('the error clears when the input changes', (tester) async {
    final auth = _FakeAuth()
      ..error = const SignupException(SignupError.invalidCredentials);
    await _pump(tester, auth);
    await _submit(tester);
    await tester.enterText(find.byType(TextField).last, 'other');
    await tester.pump();
    expect(find.text(t('errorInvalidCredentials')), findsNothing);
  });

  testWidgets('loading disables Masuk', (tester) async {
    final auth = _FakeAuth()..gate = Completer();
    await _pump(tester, auth);
    await tester.enterText(find.byType(TextField).first, 'a@binus.ac.id');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    auth.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('starts with the email verified on Daftar', (tester) async {
    await _pump(tester, _FakeAuth(), email: 'a@binus.ac.id');
    expect(find.text('a@binus.ac.id'), findsOneWidget);
  });

  testWidgets('a failed profile read signs out again', (tester) async {
    final auth = _FakeAuth()..accountError = const SignupException(null);
    final signedIn = await _pump(tester, auth);
    await _submit(tester);
    expect(auth.calls, ['signIn a@binus.ac.id', 'account', 'signOut']);
    expect(find.text(t('errorNetwork')), findsOneWidget);
    expect(signedIn, isEmpty);
  });

  testWidgets('screen readers read the title as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _FakeAuth());
    expect(find.bySemanticsLabel('${t('signInTitle')}BeeKas!'), findsOneWidget);
    semantics.dispose();
  });
}
