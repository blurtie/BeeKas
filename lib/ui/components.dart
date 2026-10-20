import 'package:flutter/material.dart';

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
            decoration: InputDecoration(
              hintText: widget.hint,
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
