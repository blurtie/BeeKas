import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L4 Daftar: isi data diri (frame 405:9246, plus Dosen/Staf for binus.edu).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.repository,
    required this.onCodeSent,
  });

  final SignupRepository repository;
  final ValueChanged<Registration> onCodeSent;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  AccountType? _type;
  Campus? _campus;

  /// Errors show only after the first Lanjut, then follow the input.
  bool _submitted = false;
  bool _loading = false;
  SignupException? _backendError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  RegistrationResult _validate() => validateRegistration(
    fullName: _name.text,
    email: _email.text,
    phone: _phone.text,
    chosenType: _type,
    campus: _campus,
  );

  void _changed() => setState(() => _backendError = null);

  Future<void> _next() async {
    setState(() => _submitted = true);
    final registration = _validate().registration;
    if (registration == null) return;
    setState(() => _loading = true);
    try {
      await widget.repository.sendCode(registration);
      if (mounted) widget.onCodeSent(registration);
    } on SignupException catch (e) {
      if (mounted) setState(() => _backendError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = _submitted ? _validate().errors : const {};
    final backend = _backendError?.error;
    final backendField = _errorField[backend];
    String? errorFor(RegistrationField f) {
      final key = errors[f] ?? (f == backendField ? backend!.copyKey : null);
      return key == null ? null : t(key);
    }

    final general = _backendError == null || backendField != null
        ? null
        : (backend?.copyKey ?? 'errorNetwork');
    final types = accountTypesFor(_email.text);
    final textTheme = Theme.of(context).textTheme;
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: const BeeHeader(title: BeeStepper(current: 0)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            24,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text(t('registerTitle'), style: textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(t('registerSubtitle'), style: textTheme.bodyMedium),
            const SizedBox(height: 24),
            BeeTextField(
              // Keys keep field state when the Dosen/Staf field appears.
              key: const ValueKey(RegistrationField.fullName),
              label: t('fullName'),
              hint: t('fullNameHint'),
              controller: _name,
              errorText: errorFor(RegistrationField.fullName),
              onChanged: (_) => _changed(),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            gap,
            BeeTextField(
              key: const ValueKey(RegistrationField.email),
              label: t('emailBinus'),
              hint: t('emailHint'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              errorText: errorFor(RegistrationField.email),
              onChanged: (_) => _changed(),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            if (types.length > 1) ...[
              gap,
              BeeDropdownField<AccountType>(
                key: const ValueKey(RegistrationField.accountType),
                label: t('accountType'),
                hint: t('accountTypeHint'),
                items: types,
                value: types.contains(_type) ? _type : null,
                itemLabel: (type) => t('accountType_${type.name}'),
                errorText: errorFor(RegistrationField.accountType),
                onChanged: (type) => setState(() {
                  _type = type;
                  _backendError = null;
                }),
              ),
            ],
            gap,
            BeeTextField(
              key: const ValueKey(RegistrationField.phone),
              label: t('phone'),
              hint: t('phoneHint'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              errorText: errorFor(RegistrationField.phone),
              onChanged: (_) => _changed(),
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            gap,
            BeeDropdownField<Campus>(
              key: const ValueKey(RegistrationField.campus),
              label: t('campus'),
              hint: t('campusHint'),
              items: Campus.values,
              value: _campus,
              itemLabel: (campus) => t(campus.copyKey),
              errorText: errorFor(RegistrationField.campus),
              onChanged: (campus) => setState(() {
                _campus = campus;
                _backendError = null;
              }),
            ),
            const SizedBox(height: 32),
            BeeWarningBanner(t('registerDataWarning')),
            const SizedBox(height: 32),
            if (general != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  t(general),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              gap,
            ],
            FilledButton(
              onPressed: _loading ? null : _next,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(t('next')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backend errors shown on a field; the rest show above Lanjut.
const _errorField = {
  SignupError.invalidEmailDomain: RegistrationField.email,
  SignupError.accountTypeRequired: RegistrationField.accountType,
  SignupError.fullNameRequired: RegistrationField.fullName,
  SignupError.invalidCampus: RegistrationField.campus,
  SignupError.phoneRequired: RegistrationField.phone,
  SignupError.invalidPhone: RegistrationField.phone,
  SignupError.phoneTaken: RegistrationField.phone,
};
