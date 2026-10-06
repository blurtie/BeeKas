import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/copy.dart';
import 'data/signup_repository.dart';
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
      // ponytail: Daftar is the only screen so far; Masuk (#31) becomes home.
      home: Builder(
        builder: (context) => RegisterScreen(
          repository: SupabaseSignupRepository(Supabase.instance.client.auth),
          // The OTP screen (#27) replaces this snackbar.
          onCodeSent: (_) =>
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t('codeSent')))),
        ),
      ),
    );
  }
}
