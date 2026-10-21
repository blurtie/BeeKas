import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payment.dart';
import '../domain/signup_error.dart';
import 'signup_repository.dart';

/// One of the member's payments in K8.
typedef Payment = ({
  String id,
  PaymentKind kind,
  int amount,
  PaymentStatus status,
  // Why the admin rejected it.
  String? reason,
  DateTime createdAt,
});

/// K8: the quota balance and the payments, newest first.
typedef QuotaOverview = ({int quota, List<Payment> payments});

/// A payment waiting in K18.
typedef PendingPayment = ({
  String id,
  String memberName,
  String memberEmail,
  PaymentKind kind,
  int amount,
  DateTime createdAt,
  String proofPath,
});

/// QRIS payments (#84): the member side (K8) and the admin side (K18); the
/// backend refuses non-admins. Failures are [SignupException]s.
abstract interface class PaymentRepository {
  Future<QuotaOverview> overview();

  /// The QRIS image from public storage (K-09).
  ImageProvider get qris;

  /// Whether the member already has a payment waiting (D-43).
  Future<bool> hasPending();

  /// Stores the proof (a JPEG without metadata); returns its path.
  Future<String> uploadProof(Uint8List proof);

  /// submit_payment: records the payment for an uploaded proof.
  Future<void> recordPayment(PaymentKind kind, String path);

  /// Removes a proof no payment records.
  Future<void> deleteProof(String path);

  /// admin_pending_payments: longest waiting first.
  Future<List<PendingPayment>> pending();

  /// The proof's bytes, kept in memory only.
  Future<Uint8List> proof(String path);

  /// Records the amount received; a package adds 3 to the quota.
  Future<void> confirm(String id, int received);

  Future<void> reject(String id, String reason);
}

/// K8: checks D-43 before uploading, then records the payment. A proof whose
/// payment was refused is deleted again; when the answer was lost it stays,
/// since the payment may have been recorded.
Future<void> submitPayment(
  PaymentRepository repository,
  PaymentKind kind,
  Uint8List proof,
) async {
  if (await repository.hasPending()) {
    throw const SignupException(SignupError.paymentPending);
  }
  final path = await repository.uploadProof(proof);
  try {
    await repository.recordPayment(kind, path);
  } on SignupException catch (e) {
    // unknown covers timeouts and 5xx: submit_payment may still commit.
    if (e.error != null && e.error != SignupError.unknown) {
      try {
        await repository.deleteProof(path);
      } on SignupException {
        // Left for the 30-day cleanup (K-10).
      }
    }
    rethrow;
  }
}

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);
  final SupabaseClient _client;
  final _random = Random.secure();

  String get _uid => _client.auth.currentUser!.id;
  StorageFileApi get _proofs => _client.storage.from('payment-proofs');

  @override
  Future<QuotaOverview> overview() => guardBackend(() async {
    final balance = await _client
        .from('quota_balances')
        .select('balance')
        .eq('member_id', _uid)
        .maybeSingle();
    final rows = await _client
        .from('payments')
        .select('id, kind, amount, status, reason, created_at')
        .eq('member_id', _uid)
        .order('created_at', ascending: false);
    return (
      quota: (balance?['balance'] as int?) ?? 0,
      payments: [
        for (final row in rows)
          (
            id: row['id'] as String,
            kind: PaymentKind.fromCode(row['kind'] as String),
            amount: row['amount'] as int,
            status: PaymentStatus.fromCode(row['status'] as String),
            reason: row['reason'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
      ],
    );
  });

  @override
  ImageProvider get qris => NetworkImage(
    _client.storage.from('payment-qris').getPublicUrl('qris.png'),
  );

  @override
  Future<bool> hasPending() => guardBackend(() async {
    final row = await _client
        .from('payments')
        .select('id')
        .eq('member_id', _uid)
        .eq('status', 'pending')
        .maybeSingle();
    return row != null;
  });

  @override
  Future<String> uploadProof(Uint8List proof) => guardBackend(() async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final path = '$_uid/$name.jpg';
    await _proofs.uploadBinary(
      path,
      proof,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return path;
  });

  @override
  Future<void> recordPayment(PaymentKind kind, String path) => guardBackend(
    () => _client.rpc<void>(
      'submit_payment',
      params: {'p_kind': kind.name, 'p_proof': path},
    ),
  );

  @override
  Future<void> deleteProof(String path) =>
      guardBackend(() => _proofs.remove([path]));

  @override
  Future<List<PendingPayment>> pending() => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>('admin_pending_payments');
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          id: row['id'] as String,
          memberName: row['member_name'] as String,
          memberEmail: row['member_email'] as String,
          kind: PaymentKind.fromCode(row['kind'] as String),
          amount: row['amount'] as int,
          createdAt: DateTime.parse(row['created_at'] as String),
          proofPath: row['proof_path'] as String,
        ),
    ];
  });

  @override
  Future<Uint8List> proof(String path) =>
      guardBackend(() => _proofs.download(path));

  @override
  Future<void> confirm(String id, int received) => guardBackend(
    () => _client.rpc<void>(
      'confirm_payment',
      params: {'p_id': id, 'p_received': received},
    ),
  );

  @override
  Future<void> reject(String id, String reason) => guardBackend(
    () => _client.rpc<void>(
      'reject_payment',
      params: {'p_id': id, 'p_reason': reason.trim()},
    ),
  );
}
