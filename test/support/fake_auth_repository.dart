import 'dart:async';

import 'package:beekas/data/auth_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/sign_in.dart';

const Account fakeAdmin = (
  fullName: 'Admin',
  email: 'admin@binus.edu',
  role: Role.admin,
  status: AccountStatus.approved,
  accountType: AccountType.staff,
  hasPassword: true,
  hasConsent: false,
  rejection: null,
);

/// Records calls; [errors] holds per-method failures, thrown once each in
/// order. [gate] holds signIn until completed, for the loading state.
class FakeAuthRepository implements AuthRepository {
  final errors = <String, List<SignupException>>{};
  Completer<void>? gate;
  final calls = <String>[];

  void fail(String method, SignupException error) =>
      (errors[method] ??= []).add(error);

  Future<void> _call(String call) async {
    calls.add(call);
    final queue = errors[call.split(' ').first];
    if (queue != null && queue.isNotEmpty) throw queue.removeAt(0);
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn $email');
    await gate?.future;
    final queue = errors['signIn'];
    if (queue != null && queue.isNotEmpty) throw queue.removeAt(0);
  }

  @override
  Future<Account> account() async {
    await _call('account');
    return fakeAdmin;
  }

  @override
  bool get signedIn => false;

  @override
  Future<void> signOut() => _call('signOut');

  @override
  Future<void> sendResetCode(String email) => _call('sendResetCode $email');

  @override
  Future<void> verifyResetCode(String email, String code) =>
      _call('verifyResetCode $email');

  @override
  Future<void> resetPassword(String password) => _call('resetPassword');
}
