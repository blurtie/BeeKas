import 'package:beekas/config/copy.dart';
import 'package:beekas/screens/onboarding_screen.dart';
import 'package:beekas/screens/sign_in_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

Future<void> _pump(WidgetTester tester, Widget home) => tester.pumpWidget(
  MaterialApp(
    theme: beeTheme(),
    builder: (context, child) => BeeLanguageScope(child: child!),
    home: home,
  ),
);

Widget _onboarding() =>
    OnboardingScreen(onSignIn: () {}, onRegister: () {}, onSkip: () {});

Widget _signIn() => SignInScreen(
  repository: FakeAuthRepository(),
  onSignedIn: (_) {},
  onRegister: () {},
  onBrowse: () {},
  onTerms: () {},
  onPrivacy: () {},
  onForgotPassword: (_) {},
);

void main() {
  tearDown(() => language.value = Lang.en);

  for (final (name, screen) in [
    ('Onboarding', _onboarding),
    ('Masuk', _signIn),
  ]) {
    testWidgets('$name: EN | ID switches the text at once and back', (
      tester,
    ) async {
      await _pump(tester, screen());
      if (name == 'Onboarding') {
        await tester.pump(OnboardingScreen.introDuration);
      }
      final probe = name == 'Onboarding' ? 'skip' : 'signInSubtitle';
      expect(find.text(copy[Lang.en]![probe]!), findsOneWidget);

      await tester.tap(find.text('ID'));
      await tester.pump();
      expect(language.value, Lang.id);
      expect(find.text(copy[Lang.id]![probe]!), findsOneWidget);
      expect(find.text(copy[Lang.en]![probe]!), findsNothing);

      await tester.tap(find.text('EN'));
      await tester.pump();
      expect(find.text(copy[Lang.en]![probe]!), findsOneWidget);
    });
  }

  testWidgets('toggle is labelled, reports the selection, and is 48 dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _signIn());
    expect(
      tester.getSemantics(find.bySemanticsLabel('Language: English')),
      matchesSemantics(
        label: 'Language: English',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('ID'));
    await tester.pump();
    expect(find.bySemanticsLabel('Bahasa: Indonesia'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Bahasa: English')),
      isNot(matchesSemantics(isSelected: true)),
    );
    for (final text in ['EN', 'ID']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(text), matching: find.byType(TextButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
