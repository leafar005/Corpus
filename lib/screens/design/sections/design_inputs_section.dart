import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../../widgets/design/corpus_section.dart';
import '../../../widgets/design/corpus_text_field.dart';

class DesignInputsSection extends StatefulWidget {
  const DesignInputsSection({super.key});

  @override
  State<DesignInputsSection> createState() => _DesignInputsSectionState();
}

class _DesignInputsSectionState extends State<DesignInputsSection> {
  final _emailController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Campos de texto',
          subtitle: 'Email, contraseña y estados.',
          child: Column(
            children: [
              CorpusTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                hint: 'tu@email.com',
                prefixIcon: CorpusIconKind.EmailOutlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CorpusTextField(
                label: 'Contraseña',
                obscureText: _obscure,
                prefixIcon: CorpusIconKind.LockOutline,
                suffixIcon: _obscure ? CorpusIconKind.Visibility : CorpusIconKind.VisibilityOff,
                onSuffixTap: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 16),
              const CorpusTextField(
                label: 'Con error',
                errorText: 'Este campo es obligatorio',
                prefixIcon: CorpusIconKind.WarningAmberOutlined,
              ),
              const SizedBox(height: 16),
              const CorpusTextField(
                label: 'Deshabilitado',
                hint: 'No editable',
                enabled: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const CorpusSection(
          title: 'Área de texto',
          subtitle: 'Comentarios de reseña, notas, etc.',
          child: CorpusTextArea(
            label: 'Comentario',
            hint: 'Escribe tu opinión sobre el juego…',
          ),
        ),
      ],
    );
  }
}
