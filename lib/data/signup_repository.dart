import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/registration.dart';
import '../domain/signup_error.dart';

/// Thrown by [SignupRepository]; [error] is null when the server could not be
/// reached. [retryAfter] is the wait in seconds for [SignupError.tooSoon].
class SignupException implements Exception {
  const SignupException(this.error, {this.retryAfter});
  final SignupError? error;
  final int? retryAfter;
}

abstract interface class SignupRepository {
  /// Creates the account if the email is new (handle_new_user builds the
  /// profile from [registration]'s metadata) and emails a 6-digit code. Also
  /// used to resend.
  Future<void> sendCode(Registration registration);

  /// Signs in with the emailed code.
  Future<void> verifyCode(String email, String code);

  /// The signed-in account: has_password() and the profile's phone.
  Future<({bool hasPassword, String? phone})> account();

  /// update_identity: applies the form's name and campus.
  Future<void> updateIdentity(Registration registration);

  /// set_phone; only works while the profile's phone is null.
  Future<void> setPhone(String phone);

  Future<void> setPassword(String password);

  /// record_consent: stores when the member agreed to L7 and to which text.
  Future<void> recordConsent(String version);

  Future<void> signOut();
}

class SupabaseSignupRepository implements SignupRepository {
  SupabaseSignupRepository(this._client);
  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Future<void> sendCode(Registration registration) => _guard(
    () => _auth.signInWithOtp(
      email: registration.email,
      data: registration.metadata,
    ),
  );

  @override
  Future<void> verifyCode(String email, String code) => _guard(
    () => _auth.verifyOTP(email: email, token: code, type: OtpType.email),
  );

  @override
  Future<({bool hasPassword, String? phone})> account() => _guard(() async {
    final hasPassword = await _client.rpc<bool>('has_password');
    final profile = await _client
        .from('profiles')
        .select('phone')
        .eq('id', _auth.currentUser!.id)
        .single();
    return (hasPassword: hasPassword, phone: profile['phone'] as String?);
  });

  @override
  Future<void> updateIdentity(Registration registration) => _guard(
    () => _client.rpc<void>(
      'update_identity',
      params: {
        'p_full_name': registration.fullName,
        'p_campus': registration.campus.code,
      },
    ),
  );

  @override
  Future<void> setPhone(String phone) =>
      _guard(() => _client.rpc<void>('set_phone', params: {'p_phone': phone}));

  @override
  Future<void> setPassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  @override
  Future<void> recordConsent(String version) => _guard(
    () => _client.rpc<void>('record_consent', params: {'p_version': version}),
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthRetryableFetchException catch (e) {
      // No status means no response. With the SDK's API version header GoTrue
      // turns every trigger error into 500 "Database error saving new user".
      throw SignupException(e.statusCode == null ? null : SignupError.unknown);
    } on AuthException catch (e) {
      throw SignupException(
        signupErrorFrom(e.code, e.message),
        retryAfter: retryAfterSeconds(e.message),
      );
    } on PostgrestException catch (e) {
      throw SignupException(signupErrorFrom(e.code, e.message));
    } on Exception {
      // PostgREST calls throw the http client's exceptions when offline.
      throw const SignupException(null);
    }
  }
}

/// What the OTP screen does next. [phoneError] means set_phone refused the
/// form's number, so another one is needed before the password step.
/// [keptPhone] is the abandoned sign-up's number that stays (phoneChanged).
typedef OtpResult = ({
  AfterOtp next,
  SignupError? phoneError,
  String? keptPhone,
});

/// Runs after [SignupRepository.verifyCode] succeeds (brief #27).
Future<OtpResult> finishOtp(
  SignupRepository repository,
  Registration submitted,
) async {
  final account = await repository.account();
  final result = afterOtp(
    hasPassword: account.hasPassword,
    storedPhone: account.phone,
    submitted: submitted,
  );
  if (result.next == AfterOtp.alreadyRegistered) {
    // They sign in with their password on Masuk instead.
    await repository.signOut();
    return (next: result.next, phoneError: null, keptPhone: null);
  }
  await repository.updateIdentity(submitted);
  SignupError? phoneError;
  if (account.phone == null) {
    try {
      await repository.setPhone(submitted.phone);
    } on SignupException catch (e) {
      if (e.error != SignupError.phoneTaken &&
          e.error != SignupError.invalidPhone) {
        rethrow;
      }
      phoneError = e.error;
    }
  }
  return (
    next: result.next,
    phoneError: phoneError,
    keptPhone: result.phoneChanged ? account.phone : null,
  );
}
