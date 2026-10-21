import 'package:beekas/config/copy.dart';
import 'package:beekas/screens/help.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('without a mail app: the address and a copy button', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(body: HelpAddressDialog()),
      ),
    );
    expect(find.text('beekas2026@gmail.com'), findsOneWidget);
    await tester.tap(find.text(t('helpCopy')));
    await tester.pump();
    expect(copied, 'beekas2026@gmail.com');
    expect(find.text(t('helpCopied')), findsOneWidget);
  });
}
