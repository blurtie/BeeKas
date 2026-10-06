import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/password.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

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
    final textTheme = Theme.of(context).textTheme;
    Widget rule(String key, bool met) => MergeSemantics(
      child: Semantics(
        checked: met,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                met ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: met ? BeeColors.success : BeeColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t(key), style: textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
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
        rule('ruleMinLength', check.minLength),
        rule('ruleLetter', check.hasLetter),
        rule('ruleDigit', check.hasDigit),
        rule('ruleMatch', check.matches),
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
