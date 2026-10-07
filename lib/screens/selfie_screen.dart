import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/signup_repository.dart';
import '../domain/photo.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L10 Verifikasi wajah, frame 416:507, with the PRD's four tips. The frame's
/// illustration is a face icon until the selfie replaces it; then Ulangi and
/// Kirim. Kirim uploads both photos and submits (D-19); on failure the selfie
/// stays and Kirim tries again.
class SelfieScreen extends StatefulWidget {
  const SelfieScreen({
    super.key,
    required this.accountType,
    required this.card,
    required this.submission,
    required this.takePhoto,
    required this.openSettings,
    required this.onSent,
  });

  final AccountType accountType;
  final Uint8List card;
  final PhotoSubmission submission;

  /// Front camera; see CardPhotoScreen.takePhoto.
  final Future<Uint8List?> Function() takePhoto;
  final Future<void> Function() openSettings;
  final VoidCallback onSent;

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  Uint8List? _selfie;
  String? _error;
  bool _cameraDenied = false;
  bool _busy = false;
  bool _sending = false;

  Future<void> _take() async {
    setState(() {
      _error = null;
      _cameraDenied = false;
      _busy = true;
    });
    try {
      final photo = await widget.takePhoto();
      if (photo != null && mounted) setState(() => _selfie = photo);
    } on PhotoException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.error.copyKey;
          _cameraDenied = e.error == PhotoError.cameraDenied;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await widget.submission.send(widget.card, _selfie!);
      // The photos leave memory with this route.
      if (mounted) widget.onSent();
      return;
    } on SignupException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.error) {
          null => 'errorNetwork',
          SignupError.unknown => 'errorSendFailed',
          final error => error.copyKey,
        },
      );
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selfie = _selfie;
    final idle = !_busy && !_sending;

    Widget tip(IconData icon, String key) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: BeeColors.stepperInactive,
            child: Icon(icon, color: BeeColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(t(key), style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return BeeSignupPage(
      step: 2,
      title: t('selfieTitle'),
      subtitle: t('selfieSubtitle')
          .replaceFirst('{card}', t('card_${widget.accountType.name}')),
      children: [
        Center(
          child: Container(
            width: 240,
            height: 240,
            padding: const EdgeInsets.all(12),
            decoration: const ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(color: BeeColors.brandPrimary, width: 3),
              ),
            ),
            child: ClipOval(
              child: ColoredBox(
                color: BeeColors.border,
                child: selfie == null
                    ? const Icon(
                        Icons.face,
                        size: 120,
                        color: BeeColors.textMuted,
                      )
                    : Image.memory(
                        selfie,
                        fit: BoxFit.cover,
                        semanticLabel: t('selfiePreview'),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        tip(Icons.lightbulb_outline, 'tipFaceLight'),
        tip(Icons.sentiment_satisfied_alt, 'tipFaceClear'),
        tip(Icons.visibility_off, 'tipFaceCover'),
        tip(Icons.checkroom, 'tipFaceClothes'),
        const SizedBox(height: 20),
        if (_error != null) ...[
          BeeFormError(t(_error!)),
          if (_cameraDenied)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.openSettings,
                child: Text(t('openSettings')),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (selfie == null)
          FilledButton(
            onPressed: idle ? _take : null,
            child: BeeButtonLabel(t('startVerification'), loading: _busy),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: idle ? _take : null,
            icon: const Icon(Icons.edit),
            label: Text(t('retake')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: idle ? _send : null,
            child: BeeButtonLabel(t('send'), loading: _sending),
          ),
        ],
      ],
    );
  }
}
