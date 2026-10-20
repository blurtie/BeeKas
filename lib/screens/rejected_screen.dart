import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../domain/rejection.dart';
import '../ui/tokens.dart';

/// L12 Verifikasi ditolak (no design; laid out like L11): the admin's reasons
/// and note, Kirim ulang (back to L8, D-08), Lihat katalog, Bantuan (D-14)
/// and Keluar.
class RejectedScreen extends StatelessWidget {
  const RejectedScreen({
    super.key,
    required this.rejection,
    required this.onResend,
    required this.onBrowse,
    required this.onHelp,
    required this.onSignOut,
  });

  /// Null only if the profile lost it; the screen then shows no reasons.
  final Rejection? rejection;
  final VoidCallback onResend;
  final VoidCallback onBrowse;
  final VoidCallback onHelp;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final note = rejection?.note;
    // Other is explained by the note.
    final reasons = [
      for (final r in rejection?.reasons ?? const <RejectionReason>[])
        if (r != RejectionReason.other) r,
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            48,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: BeeColors.warningSurface,
                child: Icon(Icons.error, size: 64, color: BeeColors.error),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('rejectedTitle'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BeeColors.warningSurface,
                borderRadius: BorderRadius.circular(BeeRadius.banner),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('rejectedBody'), style: textTheme.titleSmall),
                  for (final r in reasons)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '•  ${t('rejectReason_${r.name}')}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  if (note != null) ...[
                    const SizedBox(height: 12),
                    Text(t('rejectedNote'), style: textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(note, style: textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('rejectedResendHint'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onResend,
              child: Text(t('resendVerification')),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onBrowse,
              child: Text(t('browseCatalog')),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onHelp, child: Text(t('help'))),
            TextButton(onPressed: onSignOut, child: Text(t('signOut'))),
          ],
        ),
      ),
    );
  }
}
