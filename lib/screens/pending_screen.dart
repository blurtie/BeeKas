import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../ui/tokens.dart';

/// L11 Verifikasi Sedang Diproses, frame 459:184. The frame's back arrow and
/// Kembali become Lihat katalog and Keluar (PRD); Bantuan comes with T12. The
/// bee illustration has no asset yet.
class PendingScreen extends StatelessWidget {
  const PendingScreen({
    super.key,
    required this.onBrowse,
    required this.onSignOut,
  });

  final VoidCallback onBrowse;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget bullet(String key) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('•  ${t(key)}', style: textTheme.bodySmall),
    );

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
                backgroundColor: BeeColors.infoSurface,
                child: Icon(
                  Icons.schedule,
                  size: 64,
                  color: BeeColors.textHeading,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('pendingTitle'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              t('pendingBody'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BeeColors.infoSurface,
                borderRadius: BorderRadius.circular(BeeRadius.banner),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: BeeColors.textHeading),
                      const SizedBox(width: 8),
                      Text(t('pendingTipsTitle'), style: textTheme.titleSmall),
                    ],
                  ),
                  bullet('pendingTipData'),
                  bullet('pendingTipPhoto'),
                  bullet('pendingTipHelp'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onBrowse, child: Text(t('browseCatalog'))),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onSignOut, child: Text(t('signOut'))),
          ],
        ),
      ),
    );
  }
}
