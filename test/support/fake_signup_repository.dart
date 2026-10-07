import 'dart:typed_data';

import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/registration.dart';

/// Records calls; [errors] holds per-method failures, thrown once each in
/// order (e.g. `errors['setPhone'] = [taken]` fails the first set_phone only).
class FakeSignupRepository implements SignupRepository {
  FakeSignupRepository({
    this.hasPassword = false,
    this.phone,
    Map<String, List<SignupException>>? errors,
  }) : errors = errors ?? {};

  bool hasPassword;
  String? phone;
  final Map<String, List<SignupException>> errors;
  final calls = <String>[];
  Registration? sent;
  String? password;
  String? consentVersion;

  /// Upload paths that went in, in order.
  final uploads = <String>[];

  /// An upload path that fails once with a network error.
  String? failUpload;

  Future<void> _call(String name) async {
    calls.add(name);
    final queue = errors[name];
    if (queue != null && queue.isNotEmpty) throw queue.removeAt(0);
  }

  @override
  Future<void> sendCode(Registration r) async {
    sent = r;
    await _call('sendCode');
  }

  @override
  Future<void> verifyCode(String email, String code) => _call('verifyCode');

  @override
  Future<({bool hasPassword, String? phone})> account() async {
    await _call('account');
    return (hasPassword: hasPassword, phone: phone);
  }

  @override
  Future<void> updateIdentity(Registration r) => _call('updateIdentity');

  @override
  Future<void> setPhone(String p) async {
    await _call('setPhone');
    phone = p;
  }

  @override
  Future<void> setPassword(String p) async {
    await _call('setPassword');
    password = p;
  }

  @override
  Future<void> recordConsent(String version) async {
    await _call('recordConsent');
    consentVersion = version;
  }

  @override
  Future<void> uploadPhoto(String path, Uint8List bytes) async {
    await _call('uploadPhoto');
    if (path == failUpload) {
      failUpload = null;
      throw const SignupException(null);
    }
    uploads.add(path);
  }

  @override
  Future<void> submitForReview() => _call('submitForReview');

  @override
  Future<void> signOut() => _call('signOut');
}
