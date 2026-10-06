import 'package:beekas/ui/component_gallery.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery shows every component', (tester) async {
    // Phone-sized surface so the lazy ListView builds every item.
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: beeTheme(), home: const ComponentGallery()),
    );
    expect(find.byType(BeeHeader), findsOneWidget);
    expect(find.byType(BeeTextField), findsNWidgets(3));
    expect(find.byType(BeeWarningBanner), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
