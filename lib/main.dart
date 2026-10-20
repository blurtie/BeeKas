import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/copy.dart';
import 'data/auth_repository.dart';
import 'data/camera.dart';
import 'data/review_repository.dart';
import 'data/signup_repository.dart';
import 'domain/registration.dart';
import 'domain/sign_in.dart';
import 'screens/card_photo_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/password_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_screens.dart';
import 'screens/review_list_screen.dart';
import 'screens/selfie_screen.dart';
import 'screens/sign_in_screen.dart';
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
  // A session kept from an earlier run opens the screen for its status.
  Account? account;
  if (_auth.signedIn) {
    try {
      account = await _auth.account();
    } on SignupException {
      // Unreachable or gone: Masuk again.
    }
  }
  runApp(BeeKasApp(account: account));
}

class BeeKasApp extends StatelessWidget {
  const BeeKasApp({super.key, this.account});

  final Account? account;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeeKas',
      theme: beeTheme(),
      // Required next to onGenerateInitialRoutes (blank screen without it);
      // later routes are pushed directly.
      onGenerateRoute: (_) => MaterialPageRoute(builder: _signIn),
      onGenerateInitialRoutes: (_) => [
        if (account == null || destinationFor(account!).resumesDaftar)
          MaterialPageRoute(builder: _signIn),
        if (account != null)
          MaterialPageRoute(
            builder: (context) => _screenFor(context, account!),
          ),
      ],
    );
  }
}

final _repository = SupabaseSignupRepository(Supabase.instance.client);
final _auth = SupabaseAuthRepository(Supabase.instance.client);

Widget _signIn(BuildContext context, [String? email]) => SignInScreen(
  repository: _auth,
  initialEmail: email,
  onSignedIn: (account) {
    final route = MaterialPageRoute<void>(
      builder: (context) => _screenFor(context, account),
    );
    destinationFor(account).resumesDaftar
        ? Navigator.push(context, route)
        : Navigator.pushAndRemoveUntil(context, route, (_) => false);
  },
  onRegister: () =>
      Navigator.push(context, MaterialPageRoute(builder: _register)),
  onBrowse: () => _catalog(context),
  onTerms: () => _legal(context, 'terms'),
  onPrivacy: () => _legal(context, 'privacy'),
  onForgotPassword: (email) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => _resetEmail(context, email)),
  ),
);

/// Lupa password (#34): email, code, new password, then the screen for the
/// account's status, as after Masuk.
Widget _resetEmail(BuildContext context, String email) => ResetEmailScreen(
  repository: _auth,
  initialEmail: email,
  onSent: (email) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ResetCodeScreen(
        repository: _auth,
        email: email,
        // The code is used: the password step replaces it.
        onVerified: () => _replace(
          context,
          (context) => PasswordScreen(
            reset: true,
            save: _auth.resetPassword,
            onDone: () => _afterReset(context),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _afterReset(BuildContext context) async {
  try {
    final account = await _auth.account();
    if (!context.mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (context) => _screenFor(context, account),
    );
    // Daftar steps keep Masuk below them, as after Masuk.
    Navigator.pushAndRemoveUntil(
      context,
      route,
      (r) => destinationFor(account).resumesDaftar && r.isFirst,
    );
  } on SignupException {
    // The password is set; Masuk with it.
    if (context.mounted) await _signOut(context);
  }
}

Widget _screenFor(BuildContext context, Account account) =>
    switch (destinationFor(account)) {
      Destination.password => _password(context, null, account.accountType!),
      Destination.consent => _consent(context, account.accountType!),
      Destination.photos => _photos(context, account.accountType!),
      Destination.pending => _pendingScreen(context),
      Destination.rejected => _placeholder(
        context,
        t('rejectedTitle'),
        t('rejectedBody'),
      ),
      // ponytail: Beranda is another PRD; a placeholder until then.
      Destination.home => _placeholder(context, null, t('homeSoon')),
      Destination.review => ReviewListScreen(
        repository: SupabaseReviewRepository(Supabase.instance.client),
        onSignOut: () => _signOut(context),
      ),
    };

Widget _register(BuildContext context) => RegisterScreen(
  repository: _repository,
  onCodeSent: (registration) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => OtpScreen(
        repository: _repository,
        registration: registration,
        // finishOtp has signed out already; Masuk with the verified email.
        onSignIn: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => _signIn(context, registration.email),
          ),
          (_) => false,
        ),
        onVerified: (result) => _replace(
          context,
          (context) => result.phoneError == null
              ? _password(context, result.keptPhone, registration.accountType)
              : PhoneScreen(
                  repository: _repository,
                  initialError: result.phoneError!,
                  onSaved: () => _replace(
                    context,
                    (context) =>
                        _password(context, null, registration.accountType),
                  ),
                ),
        ),
      ),
    ),
  ),
);

Future<void> _signOut(BuildContext context) async {
  try {
    await _auth.signOut();
  } on SignupException {
    // The local session is cleared anyway.
  }
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: _signIn),
    (_) => false,
  );
}

/// Steps after OTP replace the previous one: the code is already used.
void _replace(BuildContext context, WidgetBuilder builder) =>
    Navigator.pushReplacement(context, MaterialPageRoute(builder: builder));

Widget _password(
  BuildContext context,
  String? keptPhone,
  AccountType accountType,
) => PasswordScreen(
  save: _repository.setPassword,
  keptPhone: keptPhone,
  onDone: () => _replace(context, (context) => _consent(context, accountType)),
);

Widget _consent(BuildContext context, AccountType accountType) => ConsentScreen(
  repository: _repository,
  onAgreed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => _photos(context, accountType)),
  ),
);

Widget _photos(
  BuildContext context,
  AccountType accountType,
) => CardPhotoScreen(
  accountType: accountType,
  takePhoto: () => takePhoto(CameraDevice.rear),
  openSettings: openAppSettings,
  onUse: (card) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SelfieScreen(
        accountType: accountType,
        card: card,
        repository: _repository,
        takePhoto: () => takePhoto(CameraDevice.front),
        openSettings: openAppSettings,
        // L11 replaces the whole sign-up stack, dropping the photos with it.
        onSent: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: _pendingScreen),
          (_) => false,
        ),
      ),
    ),
  ),
);

Widget _pendingScreen(BuildContext context) => PendingScreen(
  onBrowse: () => _catalog(context),
  onSignOut: () => _signOut(context),
);

// ponytail: catalog is another PRD; a placeholder until then.
void _catalog(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(t('catalogSoon'))),
    ),
  ),
);

// ponytail: S&K and Kebijakan Privasi are being drafted (D-21); a draft notice.
void _legal(BuildContext context, String titleKey) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text(t(titleKey))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(t('legalDraft')),
      ),
    ),
  ),
);

/// Temporary end screens: rejected (#32 adds the reason) and Beranda.
Widget _placeholder(BuildContext context, String? title, String body) =>
    Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
              ],
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _signOut(context),
                child: Text(t('signOut')),
              ),
            ],
          ),
        ),
      ),
    );
