import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/password.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';

/// L6 Buat kata sandi (no frame yet). The account stays `incomplete`. Also
/// the new password of Lupa password (#34), with [reset].
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({
    super.key,
    required this.save,
    required this.onDone,
    this.keptPhone,
    this.reset = false,
  });

  /// Stores the password: setPassword for L6, resetPassword for #34.
  final Future<void> Function(String password) save;
  final VoidCallback onDone;
  final bool reset;

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
      await widget.save(_password.text);
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
      step: widget.reset ? null : 0,
      title: t(widget.reset ? 'resetPasswordTitle' : 'passwordTitle'),
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
          BeeFormError(
            t(switch (_error!.error) {
              null => 'errorNetwork',
              SignupError.unknown when widget.reset => 'errorResetFailed',
              final e => e.copyKey,
            }),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading || !check.ok ? null : _save,
          child: BeeButtonLabel(
            t(widget.reset ? 'savePassword' : 'next'),
            loading: _loading,
          ),
        ),
      ],
    );
  }
}
