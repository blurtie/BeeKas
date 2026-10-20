import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/auth_repository.dart';
import '../data/signup_repository.dart';
import '../domain/sign_in.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L3 Masuk (docs/design/masuk.png), with D-22 point 5: email only, no SSO,
/// and the consent text is only a reminder. No Ingat saya: the session is
/// always kept (D-23).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
    required this.onRegister,
    required this.onBrowse,
    required this.onTerms,
    required this.onPrivacy,
    required this.onForgotPassword,
    this.initialEmail,
  });

  final AuthRepository repository;
  final ValueChanged<Account> onSignedIn;
  final VoidCallback onRegister;
  final VoidCallback onBrowse;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  /// Lupa password (#34), with what is typed in the email field.
  final ValueChanged<String> onForgotPassword;
  final String? initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _submitted = false;
  bool _loading = false;
  SignupException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _error = null);

  Future<void> _signIn() async {
    setState(() => _submitted = true);
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.repository.signIn(_email.text, _password.text);
      final Account account;
      try {
        account = await widget.repository.account();
      } on SignupException {
        // No status to route by: do not leave a session behind.
        await widget.repository.signOut().catchError((_) {});
        rethrow;
      }
      if (mounted) widget.onSignedIn(account);
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final error = _error;
    final formError = error == null ? null : signInErrorKey(error.error);
    const gap = SizedBox(height: 16);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: BeeLanguageToggle(),
            ),
            // The logo word stays untranslated and in its brand colours.
            Text.rich(
              TextSpan(
                text: t('signInTitle'),
                children: [
                  const TextSpan(
                    text: 'Bee',
                    style: TextStyle(color: BeeColors.brandOrange),
                  ),
                  const TextSpan(
                    text: 'Kas',
                    style: TextStyle(color: BeeColors.logoKas),
                  ),
                  TextSpan(text: t('signInTitleEnd')),
                ],
              ),
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(t('signInSubtitle'), style: textTheme.bodyMedium),
            const SizedBox(height: 24),
            BeeTextField(
              label: t('email'),
              hint: t('emailHint'),
              prefixIcon: Icons.person_outline,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => _changed(),
              errorText: _submitted && _email.text.trim().isEmpty
                  ? t('emailRequired')
                  : null,
            ),
            gap,
            BeeTextField(
              label: t('password'),
              prefixIcon: Icons.lock_outline,
              controller: _password,
              password: true,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => _changed(),
              errorText: _submitted && _password.text.isEmpty
                  ? t('passwordRequired')
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onForgotPassword(_email.text.trim()),
                child: Text(t('forgotPassword')),
              ),
            ),
            gap,
            if (formError != null) ...[BeeFormError(t(formError)), gap],
            FilledButton(
              onPressed: _loading ? null : _signIn,
              child: BeeButtonLabel(t('signIn'), loading: _loading),
            ),
            gap,
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(t('noAccount'), style: textTheme.bodyMedium),
                TextButton(
                  onPressed: widget.onRegister,
                  child: Text(t('register')),
                ),
              ],
            ),
            TextButton(
              onPressed: widget.onBrowse,
              child: Text(t('browseAsGuest')),
            ),
            const SizedBox(height: 32),
            Text(
              t('legalReminder'),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(onPressed: widget.onTerms, child: Text(t('terms'))),
                Text(t('and'), style: textTheme.bodySmall),
                TextButton(
                  onPressed: widget.onPrivacy,
                  child: Text(t('privacy')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
