import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access.dart';
import 'signup_repository.dart';

/// Signing in with email and password, shared by the debug admin entry and
/// Masuk (#31). Failures are [SignupException]s.
abstract interface class AuthRepository {
  Future<void> signIn(String email, String password);

  /// The signed-in account's role and status, read from its profile.
  Future<({Role role, AccountStatus status})> account();

  Future<void> signOut();
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
  Future<({Role role, AccountStatus status})> account() =>
      guardBackend(() async {
        final profile = await _client
            .from('profiles')
            .select('role, status')
            .eq('id', _client.auth.currentUser!.id)
            .single();
        return (
          role: Role.values.byName(profile['role'] as String),
          status: AccountStatus.values.byName(profile['status'] as String),
        );
      });

  @override
  Future<void> signOut() => guardBackend(_client.auth.signOut);
}
