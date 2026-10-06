import 'package:flutter/material.dart';

import '../config/copy.dart';
import 'components.dart';
import 'tokens.dart';

/// Debug-only screen showing every base component.
class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: BeeHeader(onBack: () {}),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: BeeSpacing.screenX,
          vertical: 16,
        ),
        children: [
          Text(t('register'), style: Theme.of(context).textTheme.headlineLarge),
          gap,
          BeeTextField(label: t('fullName'), hint: 'John Doe'),
          gap,
          BeeTextField(
            label: t('password'),
            hint: t('password'),
            password: true,
          ),
          gap,
          BeeWarningBanner(t('registerDataWarning')),
          gap,
          FilledButton(onPressed: () {}, child: Text(t('next'))),
          gap,
          OutlinedButton(onPressed: () {}, child: Text(t('signIn'))),
          gap,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(t('forgotPassword')),
            ),
          ),
        ],
      ),
    );
  }
}
