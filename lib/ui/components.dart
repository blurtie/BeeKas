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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BeeColors.textMuted),
            ),
          ),
        ],
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
