import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/otp_screen.dart';
import 'package:beekas/screens/password_screen.dart';
import 'package:beekas/screens/phone_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_signup_repository.dart';

const _reg = Registration(
  fullName: 'Ana',
  email: 'a@binus.ac.id',
  phone: '+6281234567890',
  accountType: AccountType.student,
  campus: Campus.senayan,
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(BeeTextField, label),
  matching: find.byType(TextField),
);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
}

Future<OtpResult?> _verify(
  WidgetTester tester,
  FakeSignupRepository repo, {
  String code = '123456',
  VoidCallback? onSignIn,
}) async {
  OtpResult? result;
  await _pump(
    tester,
    OtpScreen(
      repository: repo,
      registration: _reg,
      onVerified: (r) => result = r,
      onSignIn: onSignIn ?? () {},
    ),
  );
  await tester.enterText(_field(t('otpCode')), code);
  await _tap(tester, t('verify'));
  return result;
}

void main() {
  group('OTP', () {
    testWidgets('a short code is refused without calling the server', (
      tester,
    ) async {
      final repo = FakeSignupRepository();
      await _verify(tester, repo, code: '123');
      expect(find.text(t('errorCodeRequired')), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('wrong or expired code: message, resend still offered', (
      tester,
    ) async {
      final repo = FakeSignupRepository(
        errors: {
          'verifyCode': [const SignupException(SignupError.invalidCode)],
        },
      );
      await _verify(tester, repo);
      expect(find.text(t('errorInvalidCode')), findsOneWidget);
      await _tap(tester, t('resendCode'));
      expect(repo.calls.last, 'sendCode');
      expect(find.text(t('codeSent')), findsOneWidget);
    });

    testWidgets('resend refused by GoTrue counts down its wait', (
      tester,
    ) async {
      final repo = FakeSignupRepository(
        errors: {
          'sendCode': [
            const SignupException(SignupError.tooSoon, retryAfter: 3),
          ],
        },
      );
      await _pump(
        tester,
        OtpScreen(
          repository: repo,
          registration: _reg,
          onVerified: (_) {},
          onSignIn: () {},
        ),
      );
      await _tap(tester, t('resendCode'));
      expect(find.text(t('errorTooSoon')), findsOneWidget);
      expect(find.text(t('resendIn').replaceFirst('{s}', '3')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(t('resendCode')), findsOneWidget);
    });

    testWidgets('already registered: message and Masuk, nothing applied', (
      tester,
    ) async {
      final repo = FakeSignupRepository(hasPassword: true, phone: '+628111');
      var signIn = false;
      final result = await _verify(tester, repo, onSignIn: () => signIn = true);
      await tester.pump();
      expect(result, isNull);
      expect(find.text(t('emailRegistered')), findsOneWidget);
      expect(repo.calls, isNot(contains('updateIdentity')));
      await _tap(tester, t('signIn'));
      expect(signIn, isTrue);
    });

    testWidgets('new sign-up: form applied, phone saved, go on', (
      tester,
    ) async {
      final repo = FakeSignupRepository();
      final result = await _verify(tester, repo);
      await tester.pump();
      expect(repo.calls, [
        'verifyCode',
        'account',
        'updateIdentity',
        'setPhone',
      ]);
      expect(result?.phoneError, isNull);
      expect(result?.keptPhone, isNull);
    });

    testWidgets('retry after a failed step does not reuse the code', (
      tester,
    ) async {
      final repo = FakeSignupRepository(
        errors: {
          'account': [const SignupException(null)],
        },
      );
      await _verify(tester, repo);
      await tester.pump();
      expect(find.text(t('errorNetwork')), findsOneWidget);
      await _tap(tester, t('verify'));
      await tester.pump();
      expect(repo.calls.where((c) => c == 'verifyCode'), hasLength(1));
    });
  });

  testWidgets('taken number: asks for another, then saves it', (tester) async {
    final repo = FakeSignupRepository(
      errors: {
        'setPhone': [const SignupException(SignupError.phoneTaken)],
      },
    );
    final otp = await _verify(tester, repo);
    await tester.pump();
    expect(otp?.phoneError, SignupError.phoneTaken);

    var saved = false;
    await _pump(
      tester,
      PhoneScreen(
        repository: repo,
        initialError: otp!.phoneError!,
        onSaved: () => saved = true,
      ),
    );
    expect(find.text(t('errorPhoneTaken')), findsOneWidget);
    await tester.enterText(_field(t('phone')), '0813-1111-2222');
    await _tap(tester, t('next'));
    await tester.pump();
    expect(repo.phone, '+6281311112222');
    expect(saved, isTrue);
  });

  testWidgets('abandoned sign-up: old number kept and shown', (tester) async {
    final repo = FakeSignupRepository(phone: '+6281111111111');
    final otp = await _verify(tester, repo);
    await tester.pump();
    expect(otp?.keptPhone, '+6281111111111');
    expect(repo.calls, isNot(contains('setPhone')));

    await _pump(
      tester,
      PasswordScreen(
        repository: repo,
        keptPhone: otp!.keptPhone,
        onDone: () {},
      ),
    );
    expect(find.textContaining('+6281111111111'), findsOneWidget);
  });

  group('password', () {
    testWidgets('checklist follows typing; Lanjut waits for every rule', (
      tester,
    ) async {
      final repo = FakeSignupRepository();
      var done = false;
      await _pump(
        tester,
        PasswordScreen(repository: repo, onDone: () => done = true),
      );
      expect(find.text(t('passwordHelper')), findsOneWidget);
      FilledButton button() =>
          tester.widget(find.widgetWithText(FilledButton, t('next')));

      await tester.enterText(_field(t('password')), 'abcdefgh');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(button().onPressed, isNull);

      await tester.enterText(_field(t('password')), 'abcdefg1');
      await tester.enterText(_field(t('passwordConfirm')), 'abcdefg1');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
      await _tap(tester, t('next'));
      await tester.pump();
      expect(repo.password, 'abcdefg1');
      expect(done, isTrue);
    });

    testWidgets('server refusal is shown', (tester) async {
      final repo = FakeSignupRepository(
        errors: {
          'setPassword': [const SignupException(SignupError.weakPassword)],
        },
      );
      await _pump(tester, PasswordScreen(repository: repo, onDone: () {}));
      await tester.enterText(_field(t('password')), 'abcdefg1');
      await tester.enterText(_field(t('passwordConfirm')), 'abcdefg1');
      await tester.pump();
      await _tap(tester, t('next'));
      await tester.pump();
      expect(find.text(t('errorWeakPassword')), findsOneWidget);
    });
  });
}
