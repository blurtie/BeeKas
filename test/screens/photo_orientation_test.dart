import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phones save pixels unrotated with an EXIF Orientation tag (#29: Samsung
/// selfies carry 8). The fixtures hold a 30×60 upright picture with a red
/// top-left corner, stored raw for tags 1, 3, 6 and 8. Image.memory, as the
/// L15 detail uses it, must show each one upright.
void main() {
  for (final orientation in [1, 3, 6, 8]) {
    testWidgets('Image.memory applies EXIF Orientation $orientation', (
      tester,
    ) async {
      final bytes = File('test/fixtures/orientation_$orientation.jpg')
          .readAsBytesSync();
      await tester.pumpWidget(Image.memory(bytes));
      // Decoding runs outside the fake clock.
      await tester.runAsync(() async {
        await precacheImage(
          MemoryImage(bytes),
          tester.element(find.byType(Image)),
        );
      });
      await tester.pump();

      final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect((image.width, image.height), (30, 60));
      final pixels = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      int green(int x, int y) => pixels.getUint8((y * 30 + x) * 4 + 1);
      expect(green(2, 2), lessThan(60), reason: 'top-left is red');
      expect(green(27, 57), greaterThan(200), reason: 'bottom-right is white');
    });
  }
}
