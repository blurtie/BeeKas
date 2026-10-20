import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/auth_repository.dart';
import '../data/signup_repository.dart';
import '../domain/sign_in.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L3 Masuk (docs/design/masuk.png), with D-22 point 5: email only, no SSO,
/// and the consent text is only a reminder. Ingat saya and Lupa password wait
/// for a decision. The session is kept after the app closes (Supabase).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
    required this.onRegister,
    required this.onBrowse,
    required this.onTerms,
    required this.onPrivacy,
    this.initialEmail,
  });

  final AuthRepository repository;
  final ValueChanged<Account> onSignedIn;
  final VoidCallback onRegister;
  final VoidCallback onBrowse;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
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
      final account = await widget.repository.account();
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
    // One message for unknown email and wrong password (D-04).
    final formError = error == null
        ? null
        : switch (error.error) {
            null => 'errorNetwork',
            final e &&
                (SignupError.invalidCredentials || SignupError.rateLimited) =>
              e.copyKey,
            _ => 'errorSignInFailed',
          };
    const gap = SizedBox(height: 16);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            64,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text.rich(
              TextSpan(
                text: t('signInTitle'),
                children: const [
                  TextSpan(
                    text: 'Bee',
                    style: TextStyle(color: BeeColors.brandOrange),
                  ),
                  TextSpan(
                    text: 'Kas',
                    style: TextStyle(color: BeeColors.logoKas),
                  ),
                  TextSpan(text: '!'),
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
            const SizedBox(height: 32),
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
