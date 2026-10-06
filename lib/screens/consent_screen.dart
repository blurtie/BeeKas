import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../ui/components.dart';

/// L7 Persetujuan data (no frame yet), before any photo is taken (D-07). The
/// Kebijakan Privasi link follows in T13.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.repository,
    required this.onAgreed,
  });

  final SignupRepository repository;
  final VoidCallback onAgreed;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _loading = false;
  SignupException? _error;

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.recordConsent(consentVersion);
      if (mounted) widget.onAgreed();
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget section(String label, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(label), style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(t(body), style: textTheme.bodyMedium),
        ],
      ),
    );

    return BeeSignupPage(
      step: 1,
      title: t('consentTitle'),
      subtitle: t('consentSubtitle'),
      children: [
        section('consentDataLabel', 'consentData'),
        section('consentPurposeLabel', 'consentPurpose'),
        section('consentViewerLabel', 'consentViewer'),
        section('consentRetentionLabel', 'consentRetention'),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _agreed,
          onChanged: _loading
              ? null
              : (v) => setState(() => _agreed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(t('consentAgree'), style: textTheme.bodyMedium),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          BeeFormError(t(_error!.error?.copyKey ?? 'errorNetwork')),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _loading || !_agreed ? null : _save,
          child: BeeButtonLabel(t('next'), loading: _loading),
        ),
      ],
    );
  }
}
