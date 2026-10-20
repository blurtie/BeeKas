import 'dart:async';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/auth_repository.dart';
import '../data/signup_repository.dart';
import '../domain/registration.dart';
import '../domain/sign_in.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';

/// Seconds before Kirim ulang, the same as GoTrue's max_frequency (L5).
const resendSeconds = 60;

/// Lupa password, step 1: the email (no frame yet). Whatever the server
/// answers about the account, the next screen says the same (#34).
class ResetEmailScreen extends StatefulWidget {
  const ResetEmailScreen({
    super.key,
    required this.repository,
    required this.onSent,
    this.initialEmail,
  });

  final AuthRepository repository;
  final ValueChanged<String> onSent;
  final String? initialEmail;

  @override
  State<ResetEmailScreen> createState() => _ResetEmailScreenState();
}

class _ResetEmailScreenState extends State<ResetEmailScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _submitted = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (!isBinusEmail(_email.text)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = normalizeEmail(_email.text);
    String? error;
    try {
      await widget.repository.sendResetCode(email);
    } on SignupException catch (e) {
      error = resetSendErrorKey(e.error);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) widget.onSent(email);
  }

  @override
  Widget build(BuildContext context) {
    return BeeSignupPage(
      step: null,
      title: t('resetTitle'),
      subtitle: t('resetSubtitle'),
      children: [
        BeeTextField(
          label: t('emailBinus'),
          hint: t('emailHint'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() => _error = null),
          errorText: _submitted && !isBinusEmail(_email.text)
              ? t('errorInvalidEmailDomain')
              : null,
        ),
        const SizedBox(height: 32),
        if (_error != null) ...[
          BeeFormError(t(_error!)),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading ? null : _send,
          child: BeeButtonLabel(t('sendCode'), loading: _loading),
        ),
      ],
    );
  }
}

/// Lupa password, step 2: the recovery code. The banner never says whether
/// the email has an account; Kirim ulang waits [resendSeconds].
class ResetCodeScreen extends StatefulWidget {
  const ResetCodeScreen({
    super.key,
    required this.repository,
    required this.email,
    required this.onVerified,
  });

  final AuthRepository repository;
  final String email;
  final VoidCallback onVerified;

  @override
  State<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends State<ResetCodeScreen> {
  final _code = TextEditingController();
  bool _submitted = false;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countDown();
  }

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _codeValid => isOtpCode(_code.text);

  void _countDown() {
    _timer?.cancel();
    _wait = resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    setState(() => _submitted = true);
    if (!_codeValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.verifyResetCode(widget.email, _code.text.trim());
      if (mounted) widget.onVerified();
    } on SignupException catch (e) {
      if (mounted) {
        setState(() => _error = resetVerifyErrorKey(e.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    String? error;
    try {
      await widget.repository.sendResetCode(widget.email);
    } on SignupException catch (e) {
      error = resetSendErrorKey(e.error);
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _error = error;
      if (error == null) {
        _code.clear();
        _submitted = false;
        _countDown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeError = _error == SignupError.invalidCode.copyKey;
    final fieldError = _submitted && !_codeValid
        ? 'errorCodeRequired'
        : (codeError ? _error : null);
    final busy = _loading || _resending;

    return BeeSignupPage(
      step: null,
      title: t('resetCodeTitle'),
      subtitle: t('resetCodeSubtitle').replaceFirst('{email}', widget.email),
      children: [
        BeeWarningBanner(t('resetCodeSent')),
        const SizedBox(height: 24),
        BeeTextField(
          label: t('otpCode'),
          hint: t('otpHint'),
          controller: _code,
          keyboardType: TextInputType.number,
          errorText: fieldError == null ? null : t(fieldError),
          onChanged: (_) => setState(() {
            if (codeError) _error = null;
          }),
          autofillHints: const [AutofillHints.oneTimeCode],
        ),
        const SizedBox(height: 32),
        if (_error != null && !codeError) ...[
          BeeFormError(t(_error!)),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: busy ? null : _verify,
          child: BeeButtonLabel(t('verify'), loading: _loading),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy || _wait > 0 ? null : _resend,
          child: Text(
            _wait > 0
                ? t('resendIn').replaceFirst('{s}', '$_wait')
                : t('resendCode'),
          ),
        ),
      ],
    );
  }
}
