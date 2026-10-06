import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';

/// L5, after OTP: set_phone refused the Daftar number (taken or invalid), so
/// another one is needed before the password step. No frame yet.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({
    super.key,
    required this.repository,
    required this.initialError,
    required this.onSaved,
  });

  final SignupRepository repository;
  final SignupError initialError;
  final VoidCallback onSaved;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController();
  late SignupException? _error = SignupException(widget.initialError);
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final phone = normalizePhone(_phone.text);
    if (phone == null) return;
    setState(() => _loading = true);
    try {
      await widget.repository.setPhone(phone);
      if (mounted) widget.onSaved();
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error?.error;
    final onField =
        error == SignupError.phoneTaken || error == SignupError.invalidPhone;
    final fieldError = onField
        ? error!.copyKey
        : !_submitted
        ? null
        : _phone.text.trim().isEmpty
        ? 'errorPhoneRequired'
        : normalizePhone(_phone.text) == null
        ? 'errorInvalidPhone'
        : null;
    final formError = _error == null || onField
        ? null
        : (error?.copyKey ?? 'errorNetwork');

    return BeeSignupPage(
      title: t('phoneTitle'),
      subtitle: t('phoneSubtitle'),
      children: [
        BeeTextField(
          label: t('phone'),
          hint: t('phoneHint'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          errorText: fieldError == null ? null : t(fieldError),
          onChanged: (_) => setState(() => _error = null),
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 32),
        if (formError != null) ...[
          BeeFormError(t(formError)),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading ? null : _save,
          child: BeeButtonLabel(t('next'), loading: _loading),
        ),
      ],
    );
  }
}
