import 'package:beekas/config/copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every language has the same keys', () {
    final en = copy[Lang.en]!.keys.toSet();
    for (final lang in Lang.values) {
      expect(copy[lang]!.keys.toSet(), en, reason: '$lang');
    }
  });

  test('every language keeps the same placeholders', () {
    final placeholder = RegExp(r'\{\w+\}');
    Set<String> names(String text) =>
        placeholder.allMatches(text).map((m) => m[0]!).toSet();
    for (final MapEntry(:key, value: en) in copy[Lang.en]!.entries) {
      for (final lang in Lang.values) {
        expect(names(copy[lang]![key]!), names(en), reason: '$lang $key');
      }
    }
  });

  test('t reads the current language', () {
    addTearDown(() => language.value = Lang.en);
    expect(t('signIn'), 'Sign in');
    language.value = Lang.id;
    expect(t('signIn'), 'Masuk');
  });
}
