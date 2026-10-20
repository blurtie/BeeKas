import 'package:beekas/config/copy.dart';
import 'package:beekas/screens/onboarding_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _pump(WidgetTester tester) async {
  final exits = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: OnboardingScreen(
        onSignIn: () => exits.add('signIn'),
        onRegister: () => exits.add('register'),
        onSkip: () => exits.add('skip'),
      ),
    ),
  );
  return exits;
}

void main() {
  testWidgets('logo screen first, then the slides', (tester) async {
    await _pump(tester);
    expect(find.text(t('onboardingCommunity')), findsOneWidget);
    expect(find.text(t('skip')), findsNothing);
    expect(find.text(t('languagePlaceholder')), findsOneWidget);

    await tester.pump(OnboardingScreen.introDuration);
    expect(find.text(t('onboardingCommunity')), findsNothing);
    expect(find.text(t('onboarding1Body')), findsOneWidget);
  });

  testWidgets('Lewati on every slide; last slide has Masuk and Daftar', (
    tester,
  ) async {
    final exits = await _pump(tester);
    await tester.pump(OnboardingScreen.introDuration);
    for (var i = 0; i < 3; i++) {
      expect(find.text(t('skip')), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(find.text(t('onboarding4Body')), findsOneWidget);
    expect(
      t('onboarding4Body'),
      'Snap your item, list it in minutes, then chat with buyers in BeeKas '
      'and meet for COD on campus.',
    );

    await tester.tap(find.text(t('skip')));
    await tester.tap(find.text(t('signIn')));
    await tester.tap(find.text(t('onboardingRegister')));
    expect(exits, ['skip', 'signIn', 'register']);
  });

  test('no slide text mentions WhatsApp (D-22)', () {
    for (final lang in copy.values) {
      for (final e in lang.entries.where(
        (e) => e.key.startsWith('onboarding'),
      )) {
        expect(e.value, isNot(contains('WhatsApp')), reason: e.key);
      }
    }
  });
}
