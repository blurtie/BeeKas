import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L16 Kebijakan Privasi or Syarat & Ketentuan (no frame yet): the draft text
/// in [bodyKey] (D-07, D-21). Blocks are separated by a blank line; "# " starts
/// a heading and "- " a bullet.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.titleKey, required this.bodyKey});

  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget block(String text) {
      if (text.startsWith('# ')) {
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text.substring(2), style: textTheme.titleMedium),
        );
      }
      if (text.startsWith('- ')) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: textTheme.bodyMedium),
              Expanded(
                child: Text(text.substring(2), style: textTheme.bodyMedium),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: textTheme.bodyMedium),
      );
    }

    return Scaffold(
      appBar: BeeHeader(title: Text(t(titleKey))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            24,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text(t('legalDraftMarker'), style: textTheme.titleSmall),
            const SizedBox(height: 16),
            for (final text in t(bodyKey).split('\n\n')) block(text),
          ],
        ),
      ),
    );
  }
}
