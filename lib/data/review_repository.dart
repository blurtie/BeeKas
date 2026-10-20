import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/registration.dart';
import '../domain/rejection.dart';
import 'signup_repository.dart';

/// A pending account in L14-L15, with the paths of its latest complete
/// attempt (D-19). The paths are null if that attempt is gone.
typedef PendingAccount = ({
  String id,
  String fullName,
  String email,
  String? phone,
  AccountType accountType,
  Campus campus,
  DateTime submittedAt,
  String? cardPath,
  String? selfiePath,
});

/// Admin review (D-09); the backend refuses non-admins. Failures are
/// [SignupException]s.
abstract interface class ReviewRepository {
  /// Longest waiting first.
  Future<List<PendingAccount>> pending();

  /// The photo's bytes, kept in memory only (D-07): nothing goes to disk.
  Future<Uint8List> photo(String path);

  /// pending → approved; the backend records the admin and the time.
  Future<void> approve(String id);

  /// pending → rejected with the reasons (rule 9); the backend records the
  /// admin and the time. A blank [note] is stored as none.
  Future<void> reject(String id, Set<RejectionReason> reasons, String note);
}

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PendingAccount>> pending() => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>('pending_verifications');
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          id: row['id'] as String,
          fullName: row['full_name'] as String,
          email: row['email'] as String,
          phone: row['phone'] as String?,
          accountType: AccountType.values.byName(row['account_type'] as String),
          campus: Campus.values.firstWhere((c) => c.code == row['campus']),
          submittedAt: DateTime.parse(row['submitted_at'] as String),
          cardPath: row['card_path'] as String?,
          selfiePath: row['selfie_path'] as String?,
        ),
    ];
  });

  @override
  Future<Uint8List> photo(String path) =>
      guardBackend(() => _client.storage.from('verification').download(path));

  @override
  Future<void> approve(String id) => guardBackend(
    () => _client.rpc<void>('approve_verification', params: {'p_id': id}),
  );

  @override
  Future<void> reject(String id, Set<RejectionReason> reasons, String note) =>
      guardBackend(
        () => _client.rpc<void>(
          'reject_verification',
          params: {
            'p_id': id,
            'p_reasons': [for (final r in reasons) r.name],
            'p_note': note,
          },
        ),
      );
}
