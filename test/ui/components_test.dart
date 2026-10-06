import 'package:beekas/config/copy.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:beekas/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PreferredSizeWidget? appBar,
}) => tester.pumpWidget(
  MaterialApp(
    theme: beeTheme(),
    home: Scaffold(
      appBar: appBar,
      body: Center(child: child),
    ),
  ),
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test('text colour pairs reach 4.5:1', () {
    const pairs = [
      (BeeColors.onPrimary, BeeColors.brandPrimary),
      (BeeColors.link, BeeColors.surface),
      (BeeColors.textMuted, BeeColors.surface),
      (BeeColors.textMuted, BeeColors.warningSurface),
      (BeeColors.placeholder, BeeColors.surface),
      (BeeColors.textHeading, BeeColors.surface),
      (BeeColors.textBody, BeeColors.surface),
      (BeeColors.error, BeeColors.surface),
    ];
    for (final (fg, bg) in pairs) {
      expect(
        _contrast(fg, bg),
        greaterThanOrEqualTo(4.5),
        reason: '$fg on $bg',
      );
    }
  });

  test('focus border reaches 3:1 (WCAG 1.4.11)', () {
    final border = beeTheme().inputDecorationTheme.focusedBorder!;
    expect(border.borderSide.color, BeeColors.focusBorder);
    expect(border.borderSide.width, 2);
    expect(
      _contrast(BeeColors.focusBorder, BeeColors.surface),
      greaterThanOrEqualTo(3),
    );
  });

  for (final (name, button) in [
    ('primary', FilledButton(onPressed: () {}, child: const Text('Go'))),
    ('secondary', OutlinedButton(onPressed: () {}, child: const Text('Go'))),
    ('text', TextButton(onPressed: () {}, child: const Text('Go'))),
  ]) {
    testWidgets('$name button meets the 48 dp touch target', (tester) async {
      await _pump(tester, button);
      final size = tester.getSize(find.byWidget(button));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('primary button uses the brand colours', (tester) async {
    await _pump(
      tester,
      FilledButton(onPressed: () {}, child: const Text('Go')),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, BeeColors.brandPrimary);
    expect(material.textStyle?.color, BeeColors.onPrimary);
  });

  testWidgets('text field shows its label and hint', (tester) async {
    await _pump(
      tester,
      const BeeTextField(label: 'Full name', hint: 'John Doe'),
    );
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('text field shows errorText in the error colour', (tester) async {
    await _pump(
      tester,
      const BeeTextField(
        label: 'Full name',
        errorText: 'Enter your full name.',
      ),
    );
    final error = tester.widget<Text>(find.text('Enter your full name.'));
    expect(error.style?.color, BeeColors.error);
  });

  testWidgets('text field forwards onChanged and input options', (
    tester,
  ) async {
    String? typed;
    await _pump(
      tester,
      BeeTextField(
        label: 'Email',
        onChanged: (v) => typed = v,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
      ),
    );
    await tester.enterText(find.byType(TextField), 'a@binus.ac.id');
    expect(typed, 'a@binus.ac.id');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.next);
    expect(field.autofillHints, [AutofillHints.email]);
  });

  testWidgets('password field toggles visibility', (tester) async {
    await _pump(tester, const BeeTextField(label: 'Password', password: true));
    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip(t('showPassword')));
    await tester.pump();
    expect(obscured(), isFalse);
    await tester.tap(find.byTooltip(t('hidePassword')));
    await tester.pump();
    expect(obscured(), isTrue);
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('warning banner shows message and icon', (tester) async {
    await _pump(tester, const BeeWarningBanner('Check your data'));
    expect(find.text('Check your data'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('header back button calls onBack', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      const SizedBox(),
      appBar: BeeHeader(onBack: () => tapped = true),
    );
    await tester.tap(find.byTooltip(t('back')));
    expect(tapped, isTrue);
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('header back button pops the route by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(body: Text('home')),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(appBar: BeeHeader()),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t('back')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
