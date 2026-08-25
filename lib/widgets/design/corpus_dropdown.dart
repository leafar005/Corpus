import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import 'corpus_pointer.dart';

/// Item for [CorpusDropdown].
class CorpusDropdownItem<T> {
  final T? value;
  final String label;

  const CorpusDropdownItem({required this.value, required this.label});
}

/// Pill-shaped dropdown — filtros de año, ordenación, etc.
///
/// Matches the journal/profile filter style (`Todos`, `2026`, …).
class CorpusDropdown<T> extends StatelessWidget {
  final T? value;
  final List<CorpusDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool expand;
  final EdgeInsetsGeometry contentPadding;

  const CorpusDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hint,
    this.expand = true,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final enabled = onChanged != null;

    final radius = BorderRadius.circular(
      ext.borderRadiusLarge > 0 ? ext.borderRadiusLarge : 12,
    );

    final field = DropdownButtonFormField<T>(
      key: ValueKey<Object?>(value),
      initialValue: _safeValue(),
      hint: hint != null
          ? Text(hint!, style: TextStyle(color: cs.onSurfaceVariant))
          : null,
      isExpanded: expand,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4),
      ),
      style: TextStyle(
        color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: cs.surface,
      borderRadius: ext.radiusMedium,
      decoration: InputDecoration(
        contentPadding: contentPadding,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: Text(item.label),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );

    return CorpusPointer(
      enabled: enabled,
      child: field,
    );
  }

  /// Evita error si [value] no está en [items].
  T? _safeValue() {
    for (final item in items) {
      if (item.value == value) return value;
    }
    return null;
  }
}
