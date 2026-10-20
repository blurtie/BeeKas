import 'package:beekas/ui/assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every asset path in code is bundled', () async {
    for (final path in BeeAssets.all) {
      expect(
        (await rootBundle.load(path)).lengthInBytes,
        greaterThan(0),
        reason: path,
      );
    }
  });
}
