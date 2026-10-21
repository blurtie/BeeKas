import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/copy.dart';
import '../config/help.dart';
import '../domain/help.dart';
import '../domain/sign_in.dart';

/// Bantuan (D-14): the mail app with [helpMailto], or the address with a
/// copy button when no mail app opens.
Future<void> openHelp(BuildContext context, Account account) async {
  final uri = helpMailto(
    fullName: account.fullName,
    email: account.email,
    status: account.status,
  );
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } on PlatformException {
    // No mail app; fall through to the address.
  }
  if (opened || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => const HelpAddressDialog(),
  );
}

class HelpAddressDialog extends StatelessWidget {
  const HelpAddressDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('helpNoMailTitle')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('helpNoMailBody')),
        const SizedBox(height: 12),
        SelectableText(
          helpEmail,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('close')),
      ),
      FilledButton(
        onPressed: () async {
          await Clipboard.setData(const ClipboardData(text: helpEmail));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(t('helpCopied'))));
          Navigator.pop(context);
        },
        child: Text(t('helpCopy')),
      ),
    ],
  );
}
