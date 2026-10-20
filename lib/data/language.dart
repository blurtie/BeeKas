import 'package:shared_preferences/shared_preferences.dart';

import '../config/copy.dart';

const _key = 'language';

/// The language chosen with EN | ID (D-11), kept on the device.
Future<Lang> savedLang() async =>
    langFrom((await SharedPreferences.getInstance()).getString(_key));

Future<void> saveLang(Lang lang) async =>
    (await SharedPreferences.getInstance()).setString(_key, lang.name);
