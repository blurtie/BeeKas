import 'package:beekas/config/copy.dart';
import 'package:beekas/screens/consent_screen.dart';
import 'package:beekas/screens/legal_screen.dart';
import 'package:beekas/screens/sign_in_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_signup_repository.dart';

void _open(BuildContext context, String titleKey) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => LegalScreen(titleKey: titleKey, bodyKey: '${titleKey}Body'),
  ),
);

Widget _signIn(BuildContext context) => SignInScreen(
  repository: FakeAuthRepository(),
  onSignedIn: (_) {},
  onRegister: () {},
  onBrowse: () {},
  onTerms: () => _open(context, 'terms'),
  onPrivacy: () => _open(context, 'privacy'),
  onForgotPassword: (_) {},
);

Widget _consent(BuildContext context) => ConsentScreen(
  repository: FakeSignupRepository(),
  onAgreed: () {},
  onTerms: () => _open(context, 'terms'),
  onPrivacy: () => _open(context, 'privacy'),
);

void main() {
  tearDown(() => currentLang = Lang.en);

  for (final lang in Lang.values) {
    for (final (name, screen) in [('L3', _signIn), ('L7', _consent)]) {
      for (final key in ['privacy', 'terms']) {
        testWidgets('$lang $name opens $key, scrolls, and goes back', (
          tester,
        ) async {
          currentLang = lang;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MaterialApp(
              theme: beeTheme(),
              home: Builder(builder: screen),
            ),
          );
          final link = find.widgetWithText(TextButton, t(key));
          await tester.scrollUntilVisible(
            link,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(link);
          await tester.pumpAndSettle();
          await tester.tap(link);
          await tester.pumpAndSettle();

          expect(find.byType(LegalScreen), findsOneWidget);
          expect(find.text(t('legalDraftMarker')), findsOneWidget);
          await tester.dragUntilVisible(
            find.textContaining(t('${key}Body').split('\n\n').last),
            find.byType(ListView),
            const Offset(0, -300),
          );
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip(t('back')));
          await tester.pumpAndSettle();
          expect(find.byType(LegalScreen), findsNothing);
        });
      }
    }
  }

  test('legal copy exists in EN and ID with the draft marker', () {
    expect(copy[Lang.id]!['legalDraftMarker'], '[DRAF — menunggu tim]');
    for (final lang in Lang.values) {
      for (final key in ['privacyBody', 'termsBody', 'legalReadMore']) {
        expect(copy[lang]![key], isNotEmpty, reason: '$lang $key');
      }
    }
  });

  // D-26: the Kebijakan Privasi states the same purpose as the phone helper.
  test('phone purpose in the privacy policy matches D-26', () {
    const d26 =
        'Hanya dipakai tim BeeKas bila perlu menghubungimu, tidak ditampilkan '
        'ke pengguna lain.';
    expect(copy[Lang.id]!['phoneHelper'], 'Opsional. $d26');
    expect(copy[Lang.id]!['privacyBody'], contains('opsional. $d26'));
    final en = copy[Lang.en]!['phoneHelper']!.replaceFirst('Optional. ', '');
    expect(copy[Lang.en]!['privacyBody'], contains('optional. $en'));
  });
}
