import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/register_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements SignupRepository {
  _FakeRepo([this.error]);
  final SignupException? error;
  Registration? sent;

  @override
  Future<void> sendCode(Registration r) async {
    sent = r;
    if (error != null) throw error!;
  }
}

Future<void> _pump(
  WidgetTester tester,
  SignupRepository repo, [
  ValueChanged<Registration>? onSent,
]) async {
  tester.view.physicalSize = const Size(1080, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: RegisterScreen(repository: repo, onCodeSent: onSent ?? (_) {}),
    ),
  );
}

Future<void> _fill(
  WidgetTester tester, {
  String email = 'a@binus.ac.id',
}) async {
  await tester.enterText(_field(t('fullName')), 'Ana');
  await tester.enterText(_field(t('emailBinus')), email);
  await tester.enterText(_field(t('phone')), '0812-3456-7890');
  await _pick(tester, t('campusHint'), t('campus_senayan'));
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(BeeTextField, label),
  matching: find.byType(TextField),
);

Future<void> _next(WidgetTester tester) async {
  await tester.ensureVisible(find.text(t('next')));
  await tester.tap(find.text(t('next')));
  await tester.pump();
}

Future<void> _pick(WidgetTester tester, String hint, String item) async {
  await tester.ensureVisible(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty Lanjut shows every required error, sends nothing', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _next(tester);
    for (final key in [
      'fullNameRequired',
      'errorEmailRequired',
      'errorPhoneRequired',
      'errorInvalidCampus',
    ]) {
      expect(find.text(t(key)), findsOneWidget, reason: key);
    }
    expect(repo.sent, isNull);
  });

  testWidgets('binus.edu asks for Lecturer or Staff', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    expect(find.text(t('accountType')), findsNothing);
    await _fill(tester, email: 'b@binus.edu');
    await _next(tester);
    expect(find.text(t('errorAccountTypeRequired')), findsOneWidget);
    await _pick(tester, t('accountTypeHint'), t('accountType_staff'));
    await _next(tester);
    expect(repo.sent!.metadata['account_type'], 'staff');
  });

  testWidgets('valid form sends normalised data', (tester) async {
    final repo = _FakeRepo();
    Registration? done;
    await _pump(tester, repo, (r) => done = r);
    await _fill(tester);
    await _next(tester);
    expect(done!.phone, '+6281234567890');
    expect(repo.sent!.metadata.containsKey('phone'), isFalse);
    expect(repo.sent!.campus, Campus.senayan);
  });

  testWidgets('a backend unknown error shows above Lanjut', (tester) async {
    await _pump(tester, _FakeRepo(const SignupException(SignupError.unknown)));
    await _fill(tester);
    await _next(tester);
    expect(find.text(t('errorSignupUnknown')), findsOneWidget);
  });

  testWidgets('no connection shows the network message', (tester) async {
    await _pump(tester, _FakeRepo(const SignupException(null)));
    await _fill(tester);
    await _next(tester);
    expect(find.text(t('errorNetwork')), findsOneWidget);
  });
}
