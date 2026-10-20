import 'dart:async';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../ui/assets.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// L1–L2: the Onboarding screen (logo + Untuk Komunitas,
/// docs/design/onboarding.png), then the four slides (onboarding-1..4.png).
/// Each exit is reported once; the caller stores that onboarding was seen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onSignIn,
    required this.onRegister,
    required this.onSkip,
  });

  final VoidCallback onSignIn;
  final VoidCallback onRegister;
  final VoidCallback onSkip;

  /// How long the logo screen stays before the slides.
  static const introDuration = Duration(seconds: 2);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

typedef _Slide = (String image, String? key);

// null key: slide 1, whose title is the BeeKas welcome.
const _slides = <_Slide>[
  (BeeAssets.mascot, null),
  (BeeAssets.findItems, 'onboarding2'),
  (BeeAssets.trusted, 'onboarding3'),
  (BeeAssets.buySell, 'onboarding4'),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  late final Timer _intro;
  bool _showIntro = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _intro = Timer(
      OnboardingScreen.introDuration,
      () => setState(() => _showIntro = false),
    );
  }

  @override
  void dispose() {
    _intro.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                if (!_showIntro)
                  TextButton(onPressed: widget.onSkip, child: Text(t('skip'))),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: BeeLanguageToggle(),
                ),
              ],
            ),
            Expanded(
              child: _showIntro ? _introBody(textTheme) : _carousel(textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introBody(TextTheme textTheme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: BeeSpacing.screenX),
    child: Column(
      children: [
        const Spacer(),
        Semantics(
          label: 'BeeKas',
          child: Image.asset(
            BeeAssets.logo,
            width: 240,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(t('onboardingTagline'), style: textTheme.bodyMedium),
        const Spacer(),
        Text(
          t('onboardingCommunity'),
          style: textTheme.titleMedium?.copyWith(color: BeeColors.textBody),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: 'BINUS University',
          child: Image.asset(
            BeeAssets.binus,
            width: 88,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          flex: 4,
          child: Image.asset(BeeAssets.community, excludeFromSemantics: true),
        ),
      ],
    ),
  );

  Widget _carousel(TextTheme textTheme) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BeeSpacing.screenX,
      0,
      BeeSpacing.screenX,
      24,
    ),
    child: Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: [for (final s in _slides) _slide(textTheme, s)],
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: '${_page + 1} / ${_slides.length}',
          child: ExcludeSemantics(child: _dots()),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: widget.onSignIn, child: Text(t('signIn'))),
        const SizedBox(height: 12),
        BeeOutlinedPillButton(
          label: t('onboardingRegister'),
          onPressed: widget.onRegister,
        ),
      ],
    ),
  );

  Widget _slide(TextTheme textTheme, _Slide slide) {
    final (image, key) = slide;
    final titleStyle = textTheme.headlineSmall;
    // Highlights use the link colour: brandOrange text is below 3:1 (D-22.6).
    final title = key == null
        ? TextSpan(
            text: t('signInTitle'),
            children: [
              const TextSpan(
                text: 'Bee',
                style: TextStyle(color: BeeColors.brandOrange),
              ),
              const TextSpan(
                text: 'Kas',
                style: TextStyle(color: BeeColors.logoKas),
              ),
              TextSpan(text: t('signInTitleEnd')),
            ],
          )
        : TextSpan(
            text: t('${key}Pre'),
            children: [
              TextSpan(
                text: t('${key}Mark'),
                style: const TextStyle(color: BeeColors.link),
              ),
              TextSpan(text: t('${key}Post')),
            ],
          );
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: Image.asset(image, excludeFromSemantics: true),
          ),
          const SizedBox(height: 24),
          Text.rich(title, style: titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            t(key == null ? 'onboarding1Body' : '${key}Body'),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < _slides.length; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _page ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _page ? BeeColors.brandOrange : BeeColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}
