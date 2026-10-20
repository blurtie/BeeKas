import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/password_screen.dart';
import 'package:beekas/screens/reset_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

Future<void> _pump(WidgetTester tester, Widget screen) =>
    tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));

const _network = SignupException(null);

void main() {
  group('email', () {
    Future<List<String>> send(
      WidgetTester tester,
      FakeAuthRepository auth,
      String email,
    ) async {
      final sent = <String>[];
      await _pump(tester, ResetEmailScreen(repository: auth, onSent: sent.add));
      await tester.enterText(find.byType(TextField), email);
      await tester.tap(find.text(t('sendCode')));
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('sends to the normalized email', (tester) async {
      final auth = FakeAuthRepository();
      final sent = await send(tester, auth, ' A@Binus.ac.id ');
      expect(auth.calls, ['sendResetCode a@binus.ac.id']);
      expect(sent, ['a@binus.ac.id']);
    });

    testWidgets('a non-BINUS email is refused without calling the server', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      final sent = await send(tester, auth, 'a@gmail.com');
      expect(find.text(t('errorInvalidEmailDomain')), findsOneWidget);
      expect(auth.calls, isEmpty);
      expect(sent, isEmpty);
    });

    for (final error in [SignupError.tooSoon, SignupError.unknown]) {
      testWidgets('$error looks the same as sent', (tester) async {
        final auth = FakeAuthRepository()
          ..fail('sendResetCode', SignupException(error));
        final sent = await send(tester, auth, 'a@binus.ac.id');
        expect(sent, ['a@binus.ac.id']);
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    for (final (error, key) in [
      (_network, 'errorNetwork'),
      (const SignupException(SignupError.rateLimited), 'errorRateLimited'),
    ]) {
      testWidgets('${error.error} shows $key and stays', (tester) async {
        final auth = FakeAuthRepository()..fail('sendResetCode', error);
        final sent = await send(tester, auth, 'a@binus.ac.id');
        expect(find.text(t(key)), findsOneWidget);
        expect(sent, isEmpty);
      });
    }
  });

  group('code', () {
    Future<List<String>> pumpCode(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      final verified = <String>[];
      await _pump(
        tester,
        ResetCodeScreen(
          repository: auth,
          email: 'a@binus.ac.id',
          onVerified: () => verified.add('ok'),
        ),
      );
      return verified;
    }

    TextButton resend(WidgetTester tester) =>
        tester.widget<TextButton>(find.byType(TextButton));

    testWidgets('says the same whether or not the email is registered', (
      tester,
    ) async {
      await pumpCode(tester, FakeAuthRepository());
      expect(find.text(t('resetCodeSent')), findsOneWidget);
    });

    testWidgets('Kirim ulang counts down 60 seconds, then restarts', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpCode(tester, auth);
      expect(find.text(t('resendIn').replaceFirst('{s}', '60')), findsOne);
      expect(resend(tester).onPressed, isNull);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text(t('resendIn').replaceFirst('{s}', '1')), findsOne);
      await tester.pump(const Duration(seconds: 1));
      expect(resend(tester).onPressed, isNotNull);

      await tester.tap(find.text(t('resendCode')));
      await tester.pump();
      expect(auth.calls, ['sendResetCode a@binus.ac.id']);
      expect(find.text(t('resendIn').replaceFirst('{s}', '60')), findsOne);
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('a resend refused per email still looks sent', (tester) async {
      final auth = FakeAuthRepository()
        ..fail('sendResetCode', const SignupException(SignupError.tooSoon));
      await pumpCode(tester, auth);
      await tester.pump(const Duration(seconds: 60));
      await tester.tap(find.text(t('resendCode')));
      await tester.pump();
      expect(find.text(t('errorTooSoon')), findsNothing);
      expect(find.text(t('resendIn').replaceFirst('{s}', '60')), findsOne);
      await tester.pump(const Duration(seconds: 60));
    });

    Future<void> enter(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text(t('verify')));
      await tester.pump();
    }

    testWidgets('a right code continues', (tester) async {
      final auth = FakeAuthRepository();
      final verified = await pumpCode(tester, auth);
      await enter(tester, '123456');
      expect(auth.calls, ['verifyResetCode a@binus.ac.id']);
      expect(verified, ['ok']);
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('a short code is asked again without calling', (tester) async {
      final auth = FakeAuthRepository();
      await pumpCode(tester, auth);
      await enter(tester, '123');
      expect(find.text(t('errorCodeRequired')), findsOneWidget);
      expect(auth.calls, isEmpty);
      await tester.pump(const Duration(seconds: 60));
    });

    for (final (error, key) in [
      (const SignupException(SignupError.invalidCode), 'errorInvalidCode'),
      (_network, 'errorNetwork'),
      (const SignupException(SignupError.rateLimited), 'errorRateLimited'),
      (const SignupException(SignupError.unknown), 'errorResetFailed'),
    ]) {
      testWidgets('${error.error} shows $key', (tester) async {
        final auth = FakeAuthRepository()..fail('verifyResetCode', error);
        final verified = await pumpCode(tester, auth);
        await enter(tester, '123456');
        expect(find.text(t(key)), findsOneWidget);
        expect(verified, isEmpty);
        await tester.pump(const Duration(seconds: 60));
      });
    }
  });

  group('new password', () {
    Future<List<String>> save(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      final done = <String>[];
      await _pump(
        tester,
        PasswordScreen(
          reset: true,
          save: auth.resetPassword,
          onDone: () => done.add('done'),
        ),
      );
      expect(find.text(t('resetPasswordTitle')), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'abc12345');
      await tester.enterText(find.byType(TextField).last, 'abc12345');
      await tester.pump();
      await tester.tap(find.text(t('savePassword')));
      await tester.pumpAndSettle();
      return done;
    }

    testWidgets('saves with resetPassword', (tester) async {
      final auth = FakeAuthRepository();
      expect(await save(tester, auth), ['done']);
      expect(auth.calls, ['resetPassword']);
    });

    for (final (error, key) in [
      (const SignupException(SignupError.weakPassword), 'errorWeakPassword'),
      (const SignupException(SignupError.unknown), 'errorResetFailed'),
      (_network, 'errorNetwork'),
    ]) {
      testWidgets('${error.error} shows $key', (tester) async {
        final auth = FakeAuthRepository()..fail('resetPassword', error);
        expect(await save(tester, auth), isEmpty);
        expect(find.text(t(key)), findsOneWidget);
      });
    }
  });
}
