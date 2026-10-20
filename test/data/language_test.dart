import 'package:beekas/config/copy.dart';
import 'package:beekas/data/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('first open is English; the choice survives a reopen', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await savedLang(), Lang.en);
    await saveLang(Lang.id);
    expect(await savedLang(), Lang.id);
  });

  test('an unknown stored value falls back to English', () {
    expect(langFrom('fr'), Lang.en);
    expect(langFrom(null), Lang.en);
    expect(langFrom('id'), Lang.id);
  });
}
