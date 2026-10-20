import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/review_repository.dart';
import '../data/signup_repository.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L15 Admin: detail berkas (no design). Personal details, account and card
/// type, phone (unverified, D-04), card and selfie side by side, Setujui. Tolak
/// comes with #32. Pops true once approved.
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
  bool _approving = false;
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
    setState(() {
      _approving = true;
      _error = null;
    });
    try {
      await widget.repository.approve(account.id);
      if (mounted) Navigator.pop(context, true);
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e.error?.copyKey ?? 'errorNetwork');
    } finally {
      if (mounted) setState(() => _approving = false);
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
              onPressed: _approving ? null : _approve,
              child: BeeButtonLabel(t('approve'), loading: _approving),
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
