import 'package:beekas/data/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('first open is not onboarded; marking it sticks', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await isOnboarded(), isFalse);
    await markOnboarded();
    expect(await isOnboarded(), isTrue);
  });
}
