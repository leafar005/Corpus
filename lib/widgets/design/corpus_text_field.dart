import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';

/// Themed text field that respects the active [StylePack].
class CorpusTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const CorpusTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(color: cs.onSurface),
      cursorColor: cs.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: hasError ? errorText : null,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(icon: Icon(suffixIcon), onPressed: onSuffixTap)
            : null,
        filled: true,
        fillColor: enabled
            ? cs.surface
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: ext.radiusMedium),
        enabledBorder: OutlineInputBorder(
          borderRadius: ext.radiusMedium,
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ext.radiusMedium,
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: ext.radiusMedium,
          borderSide: BorderSide(color: cs.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: ext.radiusMedium,
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Multiline variant with sensible defaults for review comments, etc.
class CorpusTextArea extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const CorpusTextArea({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.minLines = 3,
    this.maxLines = 6,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CorpusTextField(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: onChanged,
    );
  }
}
