import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/copy.dart';
import 'tokens.dart';

// Buttons need no wrapper: FilledButton (primary), OutlinedButton (secondary)
// and TextButton are styled in theme.dart.

/// Labelled text field; [password] adds a show/hide toggle.
class BeeTextField extends StatefulWidget {
  const BeeTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.password = false,
    this.keyboardType,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.textInputAction,
    this.autofillHints,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool password;
  final TextInputType? keyboardType;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;

  /// Null grows with the text, as in the Deskripsi box.
  final int? maxLines;

  /// Shows the "0/500" counter of the Deskripsi box.
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<BeeTextField> createState() => _BeeTextFieldState();
}

class _BeeTextFieldState extends State<BeeTextField> {
  late bool _obscured = widget.password;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The field announces the label itself, so the visible text is excluded.
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            maxLines: widget.password ? 1 : widget.maxLines,
            minLines: widget.maxLines == null ? 3 : null,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon),
              errorText: widget.errorText,
              helperText: widget.helperText,
              helperMaxLines: 3,
              suffixIcon: widget.password
                  ? IconButton(
                      tooltip: t(_obscured ? 'showPassword' : 'hidePassword'),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class BeeWarningBanner extends StatelessWidget {
  const BeeWarningBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BeeColors.warningSurface,
        border: Border.all(color: BeeColors.brandPrimary),
        borderRadius: BorderRadius.circular(BeeRadius.banner),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: BeeColors.brandPrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: BeeColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A form-level error above the submit button, announced when it appears.
class BeeFormError extends StatelessWidget {
  const BeeFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// Top bar with a back button; [title] holds e.g. the Daftar stepper.
class BeeHeader extends StatelessWidget implements PreferredSizeWidget {
  const BeeHeader({super.key, this.title, this.onBack});

  final Widget? title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: t('back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack ?? () => Navigator.maybePop(context),
      ),
      title: title,
      centerTitle: true,
    );
  }
}

/// Labelled dropdown styled like [BeeTextField] (Kampus Asal in Daftar).
class BeeDropdownField<T> extends StatelessWidget {
  const BeeDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.hint,
    this.errorText,
  });

  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? hint;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            style: theme.textTheme.bodyLarge,
            hint: hint == null
                ? null
                : Text(hint!, style: theme.inputDecorationTheme.hintStyle),
            // FormField overrides decoration.errorText; this is the way in.
            forceErrorText: errorText,
            items: [
              for (final item in items)
                DropdownMenuItem(value: item, child: Text(itemLabel(item))),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Daftar progress: [count] dots joined by lines, the first [current] + 1
/// filled.
class BeeStepper extends StatelessWidget {
  const BeeStepper({super.key, required this.current, this.count = 3});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) => Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i <= current ? BeeColors.brandPrimary : BeeColors.surface,
        border: Border.all(
          color: i <= current
              ? BeeColors.brandPrimary
              : BeeColors.stepperInactive,
          width: 2,
        ),
      ),
    );
    return Semantics(
      label: t('registerStep').replaceFirst('{n}', '${current + 1}'),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0)
                Container(
                  width: 24,
                  height: 2,
                  color: BeeColors.stepperInactive,
                ),
              dot(i),
            ],
          ],
        ),
      ),
    );
  }
}

/// Daftar step layout: stepper header, title, subtitle, then [children].
/// The steps after L4 (OTP, phone, password) have no frame yet and reuse it.
class BeeSignupPage extends StatelessWidget {
  const BeeSignupPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.step = 0,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Stepper position: 0 data diri, 1 kartu, 2 wajah; null hides it.
  final int? step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: BeeHeader(
        title: step == null ? null : BeeStepper(current: step!),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            24,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text(title, style: textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: textTheme.bodyMedium),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Primary button label that turns into a spinner while [loading].
class BeeButtonLabel extends StatelessWidget {
  const BeeButtonLabel(this.label, {super.key, this.loading = false});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) => loading
      ? const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        )
      : Text(label);
}

/// One rule in a live checklist (Buat kata sandi), announced as checked.
class BeeChecklistItem extends StatelessWidget {
  const BeeChecklistItem(this.label, {super.key, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      checked: met,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: met ? BeeColors.success : BeeColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pill button with a brand outline (Daftar Akun Baru on Onboarding).
class BeeOutlinedPillButton extends StatelessWidget {
  const BeeOutlinedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: BeeColors.link,
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: BeeColors.brandPrimary),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.labelLarge,
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// EN | ID (D-11) on Onboarding and Masuk. Sets [language]; the pressed
/// side is bold and read out as selected.
class BeeLanguageToggle extends StatelessWidget {
  const BeeLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    // Each language is named in itself, whatever the current language.
    Widget option(Lang lang, String text, String name) {
      final selected = language.value == lang;
      return TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          foregroundColor: selected
              ? BeeColors.textHeading
              : BeeColors.textMuted,
          textStyle: style?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        onPressed: () => language.value = lang,
        child: Semantics(
          selected: selected,
          child: Text(
            text,
            semanticsLabel: t('languageLabel').replaceFirst('{name}', name),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option(Lang.en, 'EN', 'English'),
        ExcludeSemantics(
          child: Text('|', style: style?.copyWith(color: BeeColors.textMuted)),
        ),
        option(Lang.id, 'ID', 'Bahasa Indonesia'),
      ],
    );
  }
}

/// Rebuilds everything below when [language] changes, so each t() reads the
/// new language at once while screens keep their state (no restart).
class BeeLanguageScope extends StatefulWidget {
  const BeeLanguageScope({super.key, required this.child});

  final Widget child;

  @override
  State<BeeLanguageScope> createState() => _BeeLanguageScopeState();
}

class _BeeLanguageScopeState extends State<BeeLanguageScope> {
  @override
  void initState() {
    super.initState();
    language.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    language.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A selectable card with an illustration: Jual Barang / Donasi Barang in
/// daftar-11.png.
class BeeChoiceCard extends StatelessWidget {
  const BeeChoiceCard({
    super.key,
    required this.image,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final String image;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeeRadius.banner),
          side: BorderSide(
            color: selected ? theme.colorScheme.primary : BeeColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(BeeRadius.banner),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ExcludeSemantics(child: Image.asset(image, height: 72)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
