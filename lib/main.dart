import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/copy.dart';
import 'data/camera.dart';
import 'data/signup_repository.dart';
import 'domain/registration.dart';
import 'screens/card_photo_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/password_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/register_screen.dart';
import 'ui/theme.dart';

// Public values only, passed with --dart-define-from-file (docs/local-setup.md).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are missing. '
      'Run with --dart-define-from-file=dart_defines.json (docs/local-setup.md).',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const BeeKasApp());
}

class BeeKasApp extends StatelessWidget {
  const BeeKasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeeKas',
      theme: beeTheme(),
      // ponytail: Daftar is the only entry so far; Masuk (#31) becomes home.
      home: Builder(
        builder: (context) => RegisterScreen(
          repository: _repository,
          onCodeSent: (registration) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                repository: _repository,
                registration: registration,
                // Masuk (#31) does not exist yet; back to Daftar.
                onSignIn: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                onVerified: (result) => result.phoneError == null
                    ? _toPassword(
                        context,
                        result.keptPhone,
                        registration.accountType,
                      )
                    : _replace(
                        context,
                        (context) => PhoneScreen(
                          repository: _repository,
                          initialError: result.phoneError!,
                          onSaved: () => _toPassword(
                            context,
                            null,
                            registration.accountType,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _repository = SupabaseSignupRepository(Supabase.instance.client);

/// Steps after OTP replace the previous one: the code is already used.
void _replace(BuildContext context, WidgetBuilder builder) =>
    Navigator.pushReplacement(context, MaterialPageRoute(builder: builder));

void _toPassword(
  BuildContext context,
  String? keptPhone,
  AccountType accountType,
) => _replace(
  context,
  (context) => PasswordScreen(
    repository: _repository,
    keptPhone: keptPhone,
    onDone: () => _replace(
      context,
      (context) => ConsentScreen(
        repository: _repository,
        onAgreed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardPhotoScreen(
              accountType: accountType,
              takePhoto: takeCardPhoto,
              openSettings: openAppSettings,
              // ponytail: Selfie (L10) is #29, which uploads this photo; until
              // then a snackbar.
              onUse: (_) => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t('cardPhotoReady')))),
            ),
          ),
        ),
      ),
    ),
  ),
);
