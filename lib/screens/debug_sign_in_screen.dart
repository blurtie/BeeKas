import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/auth_repository.dart';
import '../data/signup_repository.dart';
import '../domain/access.dart';
import '../ui/components.dart';

/// Temporary debug-only way in for admins until Masuk (#31) replaces it. Only
/// reachable behind kDebugMode, so release builds drop it with its texts,
/// which therefore stay out of copy.dart. Credentials are typed by hand.
class DebugSignInScreen extends StatefulWidget {
  const DebugSignInScreen({
    super.key,
    required this.repository,
    required this.onAdmin,
  });

  final AuthRepository repository;
  final VoidCallback onAdmin;

  @override
  State<DebugSignInScreen> createState() => _DebugSignInScreenState();
}

class _DebugSignInScreenState extends State<DebugSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.signIn(_email.text, _password.text);
      final account = await widget.repository.account();
      if (!mounted) return;
      if (canReviewVerifications(account.role)) {
        widget.onAdmin();
        return;
      }
      // Members open nothing here; Masuk (#31) routes them by status.
      await widget.repository.signOut();
      if (mounted) {
        setState(() => _error = 'Not available yet (debug: admins only).');
      }
    } on SignupException catch (e) {
      if (mounted) {
        setState(() => _error = t(e.error?.copyKey ?? 'errorNetwork'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeeSignupPage(
      step: null,
      title: 'Admin (debug)',
      subtitle: 'Temporary entry until Masuk (#31).',
      children: [
        BeeTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        BeeTextField(
          label: t('password'),
          controller: _password,
          password: true,
        ),
        const SizedBox(height: 32),
        if (_error != null) ...[
          BeeFormError(_error!),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading ? null : _signIn,
          child: BeeButtonLabel(t('signIn'), loading: _loading),
        ),
      ],
    );
  }
}
