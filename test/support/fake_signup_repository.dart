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
  Future<void> signOut() => _call('signOut');
}
