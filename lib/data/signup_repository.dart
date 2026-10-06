import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/registration.dart';
import '../domain/signup_error.dart';

/// Thrown by [SignupRepository.sendCode]; [error] is null when the server
/// could not be reached.
class SignupException implements Exception {
  const SignupException(this.error);
  final SignupError? error;
}

abstract interface class SignupRepository {
  /// Creates the account if the email is new (handle_new_user builds the
  /// profile from [registration]'s metadata) and emails a 6-digit code.
  Future<void> sendCode(Registration registration);
}

class SupabaseSignupRepository implements SignupRepository {
  SupabaseSignupRepository(this._auth);
  final GoTrueClient _auth;

  @override
  Future<void> sendCode(Registration registration) async {
    try {
      await _auth.signInWithOtp(
        email: registration.email,
        data: registration.metadata,
      );
    } on AuthRetryableFetchException catch (e) {
      // No status means no response. With the SDK's API version header GoTrue
      // turns every trigger error into 500 "Database error saving new user",
      // so a taken phone lands here as unknown.
      throw SignupException(e.statusCode == null ? null : SignupError.unknown);
    } on AuthException catch (e) {
      throw SignupException(signupErrorFrom(e.code, e.message));
    }
  }
}
