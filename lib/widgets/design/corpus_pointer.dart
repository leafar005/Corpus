import 'package:flutter/material.dart';

/// Wraps [child] with a desktop pointer cursor when [enabled].
class CorpusPointer extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final MouseCursor cursor;

  const CorpusPointer({
    super.key,
    required this.child,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return MouseRegion(cursor: cursor, child: child);
  }
}
