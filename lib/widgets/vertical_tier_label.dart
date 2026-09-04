import 'package:flutter/material.dart';

/// Etiqueta de tier con letras apiladas verticalmente (p. ej. T / I / E / R / 1).
class VerticalTierLabel extends StatelessWidget {
  final String label;

  const VerticalTierLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = label.toUpperCase().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < text.length; i++) ...[
            if (i > 0 && text[i - 1] != ' ' && text[i] != ' ')
              const SizedBox(height: 3),
            if (text[i] == ' ')
              const SizedBox(height: 10)
            else
              Text(
                text[i],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color,
                  height: 1.2,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
