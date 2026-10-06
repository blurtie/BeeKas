import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../domain/photo.dart';
import '../domain/registration.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

String _card(AccountType type) => t('card_${type.name}');

/// L8 Verifikasi identitas, frame 405:9442: the card for the account type
/// (D-15) and photo tips. The frame's dashed upload box is an outlined button
/// that opens the rear camera (D-13); there is no gallery.
class CardPhotoScreen extends StatefulWidget {
  const CardPhotoScreen({
    super.key,
    required this.accountType,
    required this.takePhoto,
    required this.openSettings,
    required this.onUse,
  });

  final AccountType accountType;

  /// The photo without metadata, or null when the camera was closed. Throws
  /// [PhotoException].
  final Future<Uint8List?> Function() takePhoto;
  final Future<void> Function() openSettings;
  final ValueChanged<Uint8List> onUse;

  @override
  State<CardPhotoScreen> createState() => _CardPhotoScreenState();
}

class _CardPhotoScreenState extends State<CardPhotoScreen> {
  PhotoError? _error;
  bool _busy = false;

  Future<void> _take() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    Uint8List? photo;
    try {
      photo = await widget.takePhoto();
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (photo == null || !mounted) return;
    // L9 pops true for Ulangi. The photo is dropped with the route.
    final retake = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CardConfirmScreen(
          accountType: widget.accountType,
          photo: photo!,
          onUse: widget.onUse,
        ),
      ),
    );
    if (retake == true && mounted) await _take();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = _card(widget.accountType);
    final onTake = _busy ? null : _take;

    Widget tip(IconData icon, String key) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: BeeColors.textMuted),
          const SizedBox(height: 4),
          Text(
            t(key),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    return BeeSignupPage(
      step: 1,
      title: t('cardTitle'),
      subtitle: t('cardSubtitle').replaceFirst('{card}', card),
      children: [
        OutlinedButton(
          onPressed: onTake,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(
                  Icons.photo_camera,
                  size: 56,
                  color: BeeColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  t('cardTake').replaceFirst('{card}', card),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(t('cardFormat'), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tip(Icons.flash_off, 'tipLight'),
            const SizedBox(width: 8),
            tip(Icons.center_focus_strong, 'tipSharp'),
            const SizedBox(width: 8),
            tip(Icons.document_scanner, 'tipReadable'),
          ],
        ),
        const SizedBox(height: 32),
        if (_error != null) ...[
          BeeFormError(t(_error!.copyKey)),
          if (_error == PhotoError.cameraDenied)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.openSettings,
                child: Text(t('openSettings')),
              ),
            ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: onTake,
          child: BeeButtonLabel(t('takePhoto'), loading: _busy),
        ),
      ],
    );
  }
}

/// L9 Konfirmasi foto kartu, frame 416:411, with the PRD's Ulangi and
/// Gunakan foto. The photo comes from memory: members cannot read Storage
/// (D-19).
class CardConfirmScreen extends StatelessWidget {
  const CardConfirmScreen({
    super.key,
    required this.accountType,
    required this.photo,
    required this.onUse,
  });

  final AccountType accountType;
  final Uint8List photo;
  final ValueChanged<Uint8List> onUse;

  @override
  Widget build(BuildContext context) {
    final card = _card(accountType);
    return BeeSignupPage(
      step: 1,
      title: t('cardConfirmTitle'),
      subtitle: t('cardConfirmSubtitle').replaceFirst('{card}', card),
      children: [
        // Frame's card height; keeps Gunakan foto on screen for portrait shots.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Image.memory(
            photo,
            fit: BoxFit.contain,
            semanticLabel: t('cardPreview').replaceFirst('{card}', card),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.edit),
          label: Text(t('retake')),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: BeeColors.warningSurface,
            border: Border.all(color: BeeColors.brandPrimary),
            borderRadius: BorderRadius.circular(BeeRadius.banner),
          ),
          child: Column(
            children: [
              BeeChecklistItem(t('checkClear'), met: true),
              BeeChecklistItem(t('checkMatches'), met: true),
              BeeChecklistItem(t('checkNoGlare'), met: true),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: () => onUse(photo), child: Text(t('usePhoto'))),
      ],
    );
  }
}
