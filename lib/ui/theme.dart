import 'package:flutter/material.dart';

import 'tokens.dart';

const _font = 'Poppins';

ThemeData beeTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: BeeColors.brandPrimary)
      .copyWith(
        primary: BeeColors.brandPrimary,
        onPrimary: BeeColors.onPrimary,
        surface: BeeColors.surface,
        onSurface: BeeColors.textBody,
        onSurfaceVariant: BeeColors.textLabel,
        outline: BeeColors.border,
        outlineVariant: BeeColors.border,
      );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(BeeRadius.field),
    borderSide: const BorderSide(color: BeeColors.border),
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: BeeColors.surface,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: BeeColors.textHeading,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: BeeColors.textBody,
      ),
      bodySmall: TextStyle(fontSize: 12, color: BeeColors.textMuted),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: BeeColors.textLabel,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BeeColors.surface,
      foregroundColor: BeeColors.textLabel,
      surfaceTintColor: BeeColors.surface,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BeeColors.brandPrimary,
        foregroundColor: BeeColors.onPrimary,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BeeColors.textLabel,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: BeeColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeeRadius.field),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BeeColors.link,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BeeColors.surface,
      hintStyle: const TextStyle(fontSize: 14, color: BeeColors.placeholder),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: BeeColors.focusBorder, width: 2),
      ),
    ),
  );
}
