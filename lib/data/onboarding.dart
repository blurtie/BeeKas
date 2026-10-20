import 'package:shared_preferences/shared_preferences.dart';

const _key = 'onboarded';

/// Onboarding shows only on the first open (PRD L1–L2); kept on the device.
Future<bool> isOnboarded() async =>
    (await SharedPreferences.getInstance()).getBool(_key) ?? false;

Future<void> markOnboarded() async =>
    (await SharedPreferences.getInstance()).setBool(_key, true);
