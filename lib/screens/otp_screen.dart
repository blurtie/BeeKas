import 'dart:async';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';

/// L5 Verifikasi email (no frame yet; follows the Daftar layout).
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.repository,
    required this.registration,
    required this.onVerified,
    required this.onSignIn,
  });

  final SignupRepository repository;
  final Registration registration;

  /// Called for [AfterOtp.continueSignup]; the already-registered case stays
  /// here and offers [onSignIn].
  final ValueChanged<OtpResult> onVerified;
  final VoidCallback onSignIn;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _submitted = false;
  bool _loading = false;
  bool _resending = false;

  /// A used code cannot be verified twice, so a retry after a failed
  /// finishOtp skips verifyCode.
  bool _verified = false;
  bool _alreadyRegistered = false;
  SignupException? _error;

  /// Seconds left from GoTrue's resend limit; the app sets no limit itself.
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _codeValid => RegExp(r'^\d{6}$').hasMatch(_code.text.trim());

  Future<void> _verify() async {
    setState(() => _submitted = true);
    if (!_codeValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = widget.repository;
    try {
      if (!_verified) {
        await repo.verifyCode(widget.registration.email, _code.text.trim());
        _verified = true;
      }
      final result = await finishOtp(repo, widget.registration);
      if (!mounted) return;
      if (result.next == AfterOtp.alreadyRegistered) {
        setState(() => _alreadyRegistered = true);
      } else {
        widget.onVerified(result);
      }
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.repository.sendCode(widget.registration);
      if (!mounted) return;
      _code.clear();
      setState(() => _submitted = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('codeSent'))));
    } on SignupException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      if (e.retryAfter != null) _countDown(e.retryAfter!);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _countDown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = t('otpSubtitle')
        .replaceFirst('{email}', widget.registration.email);
    if (_alreadyRegistered) {
      return BeeSignupPage(
        title: t('otpTitle'),
        subtitle: subtitle,
        children: [
          BeeWarningBanner(t('emailRegistered')),
          const SizedBox(height: 32),
          FilledButton(onPressed: widget.onSignIn, child: Text(t('signIn'))),
        ],
      );
    }

    final error = _error?.error;
    final codeError = error == SignupError.invalidCode;
    final fieldError = _submitted && !_codeValid
        ? 'errorCodeRequired'
        : (codeError ? error!.copyKey : null);
    final formError = _error == null || codeError
        ? null
        : (error?.copyKey ?? 'errorNetwork');
    final busy = _loading || _resending;

    return BeeSignupPage(
      title: t('otpTitle'),
      subtitle: subtitle,
      children: [
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
        if (formError != null) ...[
          BeeFormError(t(formError)),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: busy ? null : _verify,
          child: BeeButtonLabel(t('verify'), loading: _loading),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy || _wait > 0 || _verified ? null : _resend,
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
