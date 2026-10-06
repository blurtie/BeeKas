import 'package:flutter/material.dart';

/// The only place colours are written. Values from docs/design/tokens.md.
abstract final class BeeColors {
  static const brandPrimary = Color(0xFFFEAF1A);
  static const brandOrange = Color(0xFFFE9402);
  static const logoKas = Color(0xFF000000);
  static const textHeading = Color(0xFF213D57);
  static const textBody = Color(0xFF475F76);
  static const textLabel = Color(0xFF5C5C5C);
  static const border = Color(0xFFEBEBEB);
  static const surface = Color(0xFFFFFFFF);
  static const warningSurface = Color(0xFFFEF7E4);
  static const stepperInactive = Color(0xFFFFEAC4);
  static const infoSurface = Color(0xFFDFECFF);
  static const success = Color(0xFF269447);

  /// Contrast-adjusted replacements (≥ 4.5:1) for design colours.
  static const onPrimary = textHeading; // design: white on brandPrimary, 1.85:1
  static const link = Color(0xFFBB4902); // design: designYellowText, 1.73:1
  static const textMuted = textLabel; // design: designGrayText / designSubtle
  static const placeholder = Color(0xFF767676); // design: designPlaceholder
  static const error = Color(0xFFB3261E); // not in tokens.md; 6.54:1 on surface
  static const focusBorder =
      link; // brandPrimary is 1.85:1, below WCAG 1.4.11's 3:1

  /// Original design colours, kept so the team can switch back.
  static const designYellowText = Color(0xFFFFB81C);
  static const designGrayText = Color(0xFF8C8C8C);
  static const designSubtle = Color(0xFFA3A3A3);
  static const designPlaceholder = Color(0xFFDDDDDD);
  static const designHeadingDark = Color(0xFF292929);
}

abstract final class BeeRadius {
  static const field = 8.0;
  static const banner = 10.0;
}

abstract final class BeeSpacing {
  static const screenX = 36.0;
}
