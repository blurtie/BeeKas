import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/review_repository.dart';
import '../data/signup_repository.dart';
import '../domain/rejection.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L15 Admin: detail berkas (no design). Personal details, account and card
/// type, phone (unverified, D-04), card and selfie side by side, Setujui and
/// Tolak with reasons (rule 9). Pops the copy key of the outcome, 'approved'
/// or 'rejected'.
class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  final ReviewRepository repository;
  final PendingAccount account;

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  // Photos stay in memory only (D-07).
  late final _card = _load(widget.account.cardPath);
  late final _selfie = _load(widget.account.selfiePath);
  bool _busy = false;
  String? _error;

  Future<Uint8List?> _load(String? path) async =>
      path == null ? null : widget.repository.photo(path);

  Future<void> _approve() async {
    final account = widget.account;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          t('approveConfirm').replaceFirst('{name}', account.fullName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('approve')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _decide(() => widget.repository.approve(account.id), 'approved');
  }

  Future<void> _reject() async {
    final rejection =
        await showDialog<({Set<RejectionReason> reasons, String note})>(
          context: context,
          builder: (context) => _RejectDialog(name: widget.account.fullName),
        );
    if (rejection == null || !mounted) return;
    await _decide(
      () => widget.repository.reject(
        widget.account.id,
        rejection.reasons,
        rejection.note,
      ),
      'rejected',
    );
  }

  Future<void> _decide(Future<void> Function() call, String outcome) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      if (mounted) Navigator.pop(context, outcome);
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e.error?.copyKey ?? 'errorNetwork');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final textTheme = Theme.of(context).textTheme;
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );

    return Scaffold(
      appBar: BeeHeader(title: Text(t('reviewDetailTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Photo(t('reviewCardPhoto'), _card)),
                const SizedBox(width: 12),
                Expanded(child: _Photo(t('reviewSelfie'), _selfie)),
              ],
            ),
            const SizedBox(height: 24),
            Text(t('reviewIdentity'), style: textTheme.titleMedium),
            field(t('fullName'), account.fullName),
            field(t('emailBinus'), account.email),
            field(t('campus'), t(account.campus.copyKey)),
            field(
              t('reviewAccountType'),
              t('accountType_${account.accountType.name}'),
            ),
            field(t('reviewCard'), t('card_${account.accountType.name}')),
            field(t('phone'), account.phone ?? t('reviewPhoneMissing')),
            const SizedBox(height: 32),
            if (_error != null) ...[
              BeeFormError(t(_error!)),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _busy ? null : _approve,
              child: BeeButtonLabel(t('approve'), loading: _busy),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _reject,
              child: Text(t('reject')),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo at 3:4; tap to view it full screen and zoom.
class _Photo extends StatelessWidget {
  const _Photo(this.label, this.bytes);

  final String label;
  final Future<Uint8List?> bytes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: BeeColors.border),
              borderRadius: BorderRadius.circular(BeeRadius.field),
            ),
            child: FutureBuilder(
              future: bytes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data;
                if (data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        t(
                          snapshot.hasError
                              ? 'reviewPhotoFailed'
                              : 'reviewPhotoMissing',
                        ),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  );
                }
                // Image.memory applies the EXIF orientation
                // (photo_orientation_test.dart).
                return Semantics(
                  button: true,
                  label: label,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: BeeHeader(title: Text(label)),
                          body: InteractiveViewer(
                            maxScale: 5,
                            child: Center(child: Image.memory(data)),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(BeeRadius.field),
                      child: Image.memory(data, fit: BoxFit.contain),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Tolak: at least one reason, and a note when Other is chosen (rule 9). Pops
/// the reasons and note, or null on Batal.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});

  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasons = <RejectionReason>{};
  final _note = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (isValidRejection(_reasons, _note.text)) {
      Navigator.pop(context, (reasons: _reasons, note: _note.text));
    } else {
      setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteMissing =
        _tried &&
        _reasons.contains(RejectionReason.other) &&
        _note.text.trim().isEmpty;
    return AlertDialog(
      title: Text(t('rejectTitle').replaceFirst('{name}', widget.name)),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('rejectReasons'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final reason in RejectionReason.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _reasons.contains(reason),
              title: Text(t('rejectReason_${reason.name}')),
              onChanged: (on) => setState(
                () => on! ? _reasons.add(reason) : _reasons.remove(reason),
              ),
            ),
          if (_tried && _reasons.isEmpty)
            BeeFormError(t('rejectReasonRequired')),
          const SizedBox(height: 8),
          BeeTextField(
            label: t('rejectNote'),
            controller: _note,
            errorText: noteMissing ? t('rejectNoteRequired') : null,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        TextButton(onPressed: _submit, child: Text(t('reject'))),
      ],
    );
  }
}
