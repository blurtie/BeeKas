import 'package:beekas/main.dart';
import 'package:beekas/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('debug app opens the gallery with every component', (
    tester,
  ) async {
    await tester.pumpWidget(const BeeKasApp());
    expect(find.byType(BeeHeader), findsOneWidget);
    expect(find.byType(BeeTextField), findsNWidgets(2));
    expect(find.byType(BeeWarningBanner), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
