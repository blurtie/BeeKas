import 'package:beekas/config/copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every language has the same keys', () {
    final en = copy[Lang.en]!.keys.toSet();
    for (final lang in Lang.values) {
      expect(copy[lang]!.keys.toSet(), en, reason: '$lang');
    }
  });

  test('t reads the current language', () {
    addTearDown(() => currentLang = Lang.en);
    expect(t('signIn'), 'Sign in');
    currentLang = Lang.id;
    expect(t('signIn'), 'Masuk');
  });
}
