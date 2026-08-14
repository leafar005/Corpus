import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import '../../widgets/design/corpus_tabs.dart';
import 'sections/design_buttons_section.dart';
import 'sections/design_feedback_section.dart';
import 'sections/design_foundations_section.dart';
import 'sections/design_inputs_section.dart';
import 'sections/design_navigation_section.dart';
import 'sections/design_selection_section.dart';
import 'sections/design_style_packs_section.dart';
import 'sections/design_surfaces_section.dart';

/// Living style guide — components and rules are added here incrementally.
class DesignScreen extends StatefulWidget {
  const DesignScreen({super.key});

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  int _categoryIndex = 0;

  static const _categories = [
    'Fundamentos',
    'Botones',
    'Inputs',
    'Selección',
    'Navegación',
    'Feedback',
    'Superficies',
    'Style packs',
  ];

  Widget _sectionForIndex(int index) => switch (index) {
    0 => const DesignFoundationsSection(),
    1 => const DesignButtonsSection(),
    2 => const DesignInputsSection(),
    3 => const DesignSelectionSection(),
    4 => const DesignNavigationSection(),
    5 => const DesignFeedbackSection(),
    6 => const DesignSurfacesSection(),
    7 => const DesignStylePacksSection(),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final pack = themeNotifier.currentPack;
        final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
        final cs = Theme.of(context).colorScheme;
        final isDesktop = MediaQuery.sizeOf(context).width >= 800;
        final headerPadding = isDesktop ? 40.0 : 20.0;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 840 : double.infinity,
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          headerPadding,
                          isDesktop ? 40 : 24,
                          headerPadding,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Design System',
                              style: CorpusTypography.display(
                                context,
                                ext,
                                fontSize: isDesktop ? 32 : 26,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pack activo: ${pack.name}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: CorpusTabs(
                        labels: _categories,
                        selectedIndex: _categoryIndex,
                        onChanged: (i) => setState(() => _categoryIndex = i),
                        isScrollable: true,
                        contentPadding: EdgeInsets.all(isDesktop ? 24 : 16),
                        child: _sectionForIndex(_categoryIndex),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: isDesktop ? 48 : 32),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
