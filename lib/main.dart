import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/copy.dart';
import 'data/auth_repository.dart';
import 'data/camera.dart';
import 'data/catalog_repository.dart';
import 'data/language.dart';
import 'data/listing_repository.dart';
import 'data/onboarding.dart';
import 'data/payment_repository.dart';
import 'data/review_repository.dart';
import 'data/signup_repository.dart';
import 'domain/access.dart';
import 'domain/registration.dart';
import 'domain/sign_in.dart';
import 'screens/card_photo_screen.dart';
import 'screens/catalog_screens.dart';
import 'screens/consent_screen.dart';
import 'screens/help.dart';
import 'screens/legal_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/password_screen.dart';
import 'screens/payment_screens.dart';
import 'screens/pending_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/register_screen.dart';
import 'screens/rejected_screen.dart';
import 'screens/reset_screens.dart';
import 'screens/review_list_screen.dart';
import 'screens/selfie_screen.dart';
import 'screens/sell_screen.dart';
import 'screens/sign_in_screen.dart';
import 'ui/components.dart';
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
  language.value = await savedLang();
  language.addListener(() => saveLang(language.value));
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
  runApp(BeeKasApp(account: account, onboarded: await isOnboarded()));
}

class BeeKasApp extends StatelessWidget {
  const BeeKasApp({super.key, this.account, this.onboarded = true});

  final Account? account;
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeeKas',
      theme: beeTheme(),
      builder: (context, child) => BeeLanguageScope(child: child!),
      // Required next to onGenerateInitialRoutes (blank screen without it);
      // later routes are pushed directly.
      onGenerateRoute: (_) => MaterialPageRoute(builder: _signIn),
      onGenerateInitialRoutes: (_) => [
        for (final screen in startScreens(account, onboarded: onboarded))
          MaterialPageRoute(
            builder: switch (screen) {
              StartScreen.onboarding => _onboarding,
              StartScreen.signIn => _signIn,
              StartScreen.account => (context) => _screenFor(context, account!),
            },
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

/// Every exit marks onboarding as seen, then leaves Masuk at the bottom.
Widget _onboarding(BuildContext context) {
  void leave({bool register = false}) {
    markOnboarded();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: _signIn));
    if (register) {
      Navigator.push(context, MaterialPageRoute(builder: _register));
    }
  }

  return OnboardingScreen(
    onSignIn: leave,
    onSkip: leave,
    onRegister: () => leave(register: true),
  );
}

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
      // Kirim ulang goes to L8; the profile and consent are kept (D-08).
      Destination.rejected => RejectedScreen(
        rejection: account.rejection,
        onResend: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _photos(context, account.accountType!),
          ),
        ),
        onBrowse: () => _catalog(context, AccountStatus.rejected),
        onHelp: () => _help(context),
        onSignOut: () => _signOut(context),
      ),
      Destination.home => CatalogShell(
        repository: _catalogRepository,
        status: account.status,
        onSell: () => _sell(context),
        onSignOut: () => _signOut(context),
        onQuota: () => _quota(context),
      ),
      Destination.review => ReviewListScreen(
        repository: SupabaseReviewRepository(Supabase.instance.client),
        onSignOut: () => _signOut(context),
        onPayments: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentListScreen(repository: _paymentRepository),
          ),
        ),
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
                  onDone: () => _replace(
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
  onTerms: () => _legal(context, 'terms'),
  onPrivacy: () => _legal(context, 'privacy'),
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

// Read at tap time: after Kirim, L11 has no Account in hand.
Future<void> _help(BuildContext context) async {
  try {
    final account = await _auth.account();
    if (context.mounted) await openHelp(context, account);
  } on SignupException {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => const HelpAddressDialog(),
      );
    }
  }
}

Widget _pendingScreen(BuildContext context) => PendingScreen(
  onBrowse: () => _catalog(context, AccountStatus.pending),
  onHelp: () => _help(context),
  onSignOut: () => _signOut(context),
);

final _catalogRepository = SupabaseCatalogRepository(Supabase.instance.client);

/// Lihat katalog for guests, pending and rejected accounts (D-06); [status]
/// lets + explain why they cannot sell yet.
void _catalog(BuildContext context, [AccountStatus? status]) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) =>
        CatalogShell(repository: _catalogRepository, status: status),
  ),
);

final _listingRepository = SupabaseListingRepository(Supabase.instance.client);

final _paymentRepository = SupabasePaymentRepository(Supabase.instance.client);

/// K8 Kuota Listing (#84), from Pasang and from Profil.
Future<void> _quota(BuildContext context) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => QuotaScreen(
      repository: _paymentRepository,
      // A screenshot from the gallery, converted like listing photos.
      pickProof: () => pickListingPhoto(ImageSource.gallery),
    ),
  ),
);

/// Pasang barang (#82), K5-K6.
Future<bool?> _sell(BuildContext context) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (context) => SellScreen(
      repository: _listingRepository,
      pickPhoto: ({required camera}) =>
          pickListingPhoto(camera ? ImageSource.camera : ImageSource.gallery),
      onBuyQuota: () => _quota(context),
    ),
  ),
);

void _legal(BuildContext context, String titleKey) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) =>
        LegalScreen(titleKey: titleKey, bodyKey: '${titleKey}Body'),
  ),
);
