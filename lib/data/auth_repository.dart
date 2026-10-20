import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access.dart';
import '../domain/registration.dart';
import '../domain/sign_in.dart';
import 'signup_repository.dart';

/// Masuk (#31) and Lupa password (#34). Failures are [SignupException]s.
abstract interface class AuthRepository {
  Future<void> signIn(String email, String password);

  /// The signed-in account, read from its profile and has_password().
  Future<Account> account();

  /// Whether a session was kept from an earlier run.
  bool get signedIn;

  Future<void> signOut();

  /// Emails a 6-digit recovery code; GoTrue answers the same for unknown
  /// emails.
  Future<void> sendResetCode(String email);

  /// Signs in with the recovery code.
  Future<void> verifyResetCode(String email, String code);

  /// Sets the new password, then signs out every other device. Safe to retry.
  Future<void> resetPassword(String password);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> signIn(String email, String password) => guardBackend(
    () => _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    ),
  );

  @override
  Future<Account> account() => guardBackend(() async {
    final hasPassword = await _client.rpc<bool>('has_password');
    final profile = await _client
        .from('profiles')
        .select('role, status, account_type, consent_at')
        .eq('id', _client.auth.currentUser!.id)
        .single();
    return (
      role: Role.values.byName(profile['role'] as String),
      status: AccountStatus.values.byName(profile['status'] as String),
      // Null for seeded admins (D-18).
      accountType: AccountType.values.asNameMap()[profile['account_type']],
      hasPassword: hasPassword,
      hasConsent: profile['consent_at'] != null,
    );
  });

  @override
  bool get signedIn => _client.auth.currentSession != null;

  @override
  Future<void> signOut() => guardBackend(_client.auth.signOut);

  @override
  Future<void> sendResetCode(String email) => guardBackend(
    () => _client.auth.resetPasswordForEmail(normalizeEmail(email)),
  );

  @override
  Future<void> verifyResetCode(String email, String code) => guardBackend(
    () => _client.auth.verifyOTP(
      email: normalizeEmail(email),
      token: code,
      type: OtpType.recovery,
    ),
  );

  @override
  Future<void> resetPassword(String password) => guardBackend(() async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (e) {
      // A retry after the sign-out below failed: the password is already set.
      if (e.code != 'same_password') rethrow;
    }
    await _client.auth.signOut(scope: SignOutScope.others);
  });
}
