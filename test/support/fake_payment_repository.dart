import 'dart:async';
import 'dart:typed_data';

import 'package:beekas/data/payment_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/payment.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter/widgets.dart';

/// Plays payments, the proof bucket and the admin functions in memory.
/// [errors] holds one failure per method name; [gate] holds the loads.
class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({this.quota = 0});
  int quota;
  final payments = <Payment>[];
  final pendingList = <PendingPayment>[];
  final proofs = <String, Uint8List>{};
  final submitted = <Uint8List>[];

  /// Proofs in the member's folder, by path.
  final uploads = <String, Uint8List>{};
  final confirmed = <(String, int)>[];
  final rejected = <(String, String)>[];
  final errors = <String, Object>{};
  Completer<void>? gate;
  var _ids = 0;

  /// A 1×1 transparent GIF stands in for the QRIS image.
  @override
  ImageProvider qris = MemoryImage(
    Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 0, 1, 0, 0x80, 0, 0, 0, 0, 0, //
      0xff, 0xff, 0xff, 0x21, 0xf9, 4, 1, 0, 0, 0, 0, 0x2c, 0, 0, 0, 0, 1,
      0, 1, 0, 0, 2, 2, 0x44, 1, 0, 0x3b,
    ]),
  );

  void _fail(String method) {
    final error = errors.remove(method);
    if (error != null) throw error;
  }

  Payment add(PaymentStatus status, {String? reason, DateTime? at}) {
    final p = (
      id: 'p${_ids++}',
      kind: PaymentKind.package,
      amount: PaymentKind.package.amount,
      status: status,
      reason: reason,
      createdAt: at ?? DateTime.utc(2026, 10, 21, 9),
    );
    payments.insert(0, p);
    return p;
  }

  @override
  Future<QuotaOverview> overview() async {
    await gate?.future;
    _fail('overview');
    return (quota: quota, payments: List.of(payments));
  }

  @override
  Future<bool> hasPending() async {
    _fail('hasPending');
    return payments.any((p) => p.status == PaymentStatus.pending);
  }

  @override
  Future<String> uploadProof(Uint8List proof) async {
    _fail('uploadProof');
    final path = 'me/${uploads.length}.jpg';
    uploads[path] = proof;
    return path;
  }

  @override
  Future<void> recordPayment(PaymentKind kind, String path) async {
    _fail('recordPayment');
    submitted.add(uploads[path]!);
    add(PaymentStatus.pending);
  }

  @override
  Future<void> deleteProof(String path) async {
    _fail('deleteProof');
    uploads.remove(path);
  }

  @override
  Future<List<PendingPayment>> pending() async {
    await gate?.future;
    _fail('pending');
    return List.of(pendingList);
  }

  @override
  Future<Uint8List> proof(String path) async =>
      proofs[path] ?? (throw const SignupException(SignupError.unknown));

  @override
  Future<void> confirm(String id, int received) async {
    _fail('confirm');
    confirmed.add((id, received));
    pendingList.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> reject(String id, String reason) async {
    _fail('reject');
    rejected.add((id, reason));
    pendingList.removeWhere((p) => p.id == id);
  }
}
