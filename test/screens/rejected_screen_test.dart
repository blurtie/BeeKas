import 'package:beekas/config/copy.dart';
import 'package:beekas/domain/rejection.dart';
import 'package:beekas/screens/rejected_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _pump(WidgetTester tester, Rejection? rejection) async {
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: beeTheme(),
      home: RejectedScreen(
        rejection: rejection,
        onResend: () => taps.add('resend'),
        onBrowse: () => taps.add('browse'),
        onSignOut: () => taps.add('signOut'),
      ),
    ),
  );
  return taps;
}

void main() {
  testWidgets('L12 shows the reasons and the note; Other is the note', (
    tester,
  ) async {
    await _pump(tester, (
      reasons: [RejectionReason.selfie, RejectionReason.other],
      note: 'Wajah tertutup masker',
    ));
    expect(find.text(t('rejectedTitle')), findsOneWidget);
    expect(find.text('•  ${t('rejectReason_selfie')}'), findsOneWidget);
    expect(find.textContaining(t('rejectReason_other')), findsNothing);
    expect(find.text(t('rejectedNote')), findsOneWidget);
    expect(find.text('Wajah tertutup masker'), findsOneWidget);
  });

  testWidgets('L12 without a note shows no note heading', (tester) async {
    await _pump(tester, (reasons: [RejectionReason.card], note: null));
    expect(find.text('•  ${t('rejectReason_card')}'), findsOneWidget);
    expect(find.text(t('rejectedNote')), findsNothing);
  });

  testWidgets('L12 buttons: Kirim ulang, Lihat katalog, Keluar', (
    tester,
  ) async {
    final taps = await _pump(tester, null);
    await tester.tap(find.text(t('resendVerification')));
    await tester.ensureVisible(find.text(t('browseCatalog')));
    await tester.tap(find.text(t('browseCatalog')));
    await tester.ensureVisible(find.text(t('signOut')));
    await tester.tap(find.text(t('signOut')));
    expect(taps, ['resend', 'browse', 'signOut']);
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.bySubtype<ButtonStyleButton>(),
    )) {
      expect(
        tester.getSize(find.byWidget(button)).height,
        greaterThanOrEqualTo(48),
      );
    }
  });
}
