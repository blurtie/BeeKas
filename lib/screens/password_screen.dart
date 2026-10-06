import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/password.dart';
import '../ui/components.dart';

/// L6 Buat kata sandi (no frame yet). The account stays `incomplete`.
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({
    super.key,
    required this.repository,
    required this.onDone,
    this.keptPhone,
  });

  final SignupRepository repository;
  final VoidCallback onDone;

  /// The abandoned sign-up's number that stays instead of the typed one.
  final String? keptPhone;

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  SignupException? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.setPassword(_password.text);
      if (mounted) widget.onDone();
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = checkPassword(_password.text, _confirm.text);
    void changed(String _) => setState(() => _error = null);

    return BeeSignupPage(
      title: t('passwordTitle'),
      subtitle: t('passwordSubtitle'),
      children: [
        if (widget.keptPhone != null) ...[
          BeeWarningBanner(
            t('phoneKept').replaceFirst('{phone}', widget.keptPhone!),
          ),
          const SizedBox(height: 24),
        ],
        BeeTextField(
          label: t('password'),
          controller: _password,
          password: true,
          helperText: t('passwordHelper'),
          onChanged: changed,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        BeeTextField(
          label: t('passwordConfirm'),
          controller: _confirm,
          password: true,
          onChanged: changed,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 8),
        BeeChecklistItem(t('ruleMinLength'), met: check.minLength),
        BeeChecklistItem(t('ruleLetter'), met: check.hasLetter),
        BeeChecklistItem(t('ruleDigit'), met: check.hasDigit),
        BeeChecklistItem(t('ruleMatch'), met: check.matches),
        const SizedBox(height: 32),
        if (_error != null) ...[
          BeeFormError(t(_error!.error?.copyKey ?? 'errorNetwork')),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading || !check.ok ? null : _save,
          child: BeeButtonLabel(t('next'), loading: _loading),
        ),
      ],
    );
  }
}
