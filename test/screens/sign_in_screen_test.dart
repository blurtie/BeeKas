import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/sign_in.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/sign_in_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

final forgot = <String>[];

Future<List<Account>> _pump(
  WidgetTester tester,
  FakeAuthRepository auth, {
  String? email,
}) async {
  final signedIn = <Account>[];
  forgot.clear();
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
        onForgotPassword: forgot.add,
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
    final auth = FakeAuthRepository();
    final signedIn = await _pump(tester, auth);
    await _submit(tester);
    expect(auth.calls, ['signIn a@binus.ac.id', 'account']);
    expect(signedIn, [fakeAdmin]);
  });

  testWidgets('empty fields ask for input without calling the server', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
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
      final auth = FakeAuthRepository()..fail('signIn', error);
      final signedIn = await _pump(tester, auth);
      await _submit(tester);
      expect(find.text(t(key)), findsOneWidget);
      expect(signedIn, isEmpty);
    });
  }

  testWidgets('the error clears when the input changes', (tester) async {
    final auth = FakeAuthRepository()
      ..fail('signIn', const SignupException(SignupError.invalidCredentials));
    await _pump(tester, auth);
    await _submit(tester);
    await tester.enterText(find.byType(TextField).last, 'other');
    await tester.pump();
    expect(find.text(t('errorInvalidCredentials')), findsNothing);
  });

  testWidgets('loading disables Masuk', (tester) async {
    final auth = FakeAuthRepository()..gate = Completer();
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
    await _pump(tester, FakeAuthRepository(), email: 'a@binus.ac.id');
    expect(find.text('a@binus.ac.id'), findsOneWidget);
  });

  testWidgets('a failed profile read signs out again', (tester) async {
    final auth = FakeAuthRepository()
      ..fail('account', const SignupException(null));
    final signedIn = await _pump(tester, auth);
    await _submit(tester);
    expect(auth.calls, ['signIn a@binus.ac.id', 'account', 'signOut']);
    expect(find.text(t('errorNetwork')), findsOneWidget);
    expect(signedIn, isEmpty);
  });

  testWidgets('screen readers read the title as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, FakeAuthRepository());
    expect(find.bySemanticsLabel('${t('signInTitle')}BeeKas!'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Lupa password? opens the reset with the typed email', (
    tester,
  ) async {
    await _pump(tester, FakeAuthRepository());
    await tester.enterText(find.byType(TextField).first, ' a@binus.ac.id ');
    await tester.tap(find.text(t('forgotPassword')));
    expect(forgot, ['a@binus.ac.id']);
  });
}
