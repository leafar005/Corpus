import 'package:flutter/material.dart';
import '../../../utils/igdb_constants.dart';
import '../../../widgets/corpus_network_image.dart';
import '../../../models/models.dart';
import '../../library/game_details_screen.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../profile_controller.dart';

/// Widget del Hall of Fame del perfil: 5 carátulas de juegos favoritos.
class ProfileHallOfFame extends StatelessWidget {
  final List<Map<String, dynamic>?> hallOfFame;
  final ProfileController controller;

  const ProfileHallOfFame({
    super.key,
    required this.hallOfFame,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Hall of Fame',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final game = hallOfFame[index];
                  final isNumberOne = index == 2;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AspectRatio(
                        aspectRatio: IgdbConstants.coverAspectRatio,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (isNumberOne)
                              Positioned(
                                top: -4,
                                bottom: -4,
                                left: -4,
                                right: -4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    if (game != null) {
                                      final isDesktop =
                                          MediaQuery.of(context).size.width >
                                          800;
                                      if (isDesktop) {
                                        context
                                            .pushGameDetails(Game.fromMap(game))
                                            .then(
                                              (_) => controller
                                                  .fetchProfileData(),
                                            );
                                      } else {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: false,
                                          enableDrag: true,
                                          builder: (context) =>
                                              DraggableScrollableSheet(
                                                initialChildSize: 1.0,
                                                minChildSize: 0.5,
                                                maxChildSize: 1.0,
                                                expand: false,
                                                snap: true,
                                                builder:
                                                    (
                                                      context,
                                                      scrollController,
                                                    ) {
                                                      return GameDetailsScreen(
                                                        gameData: Game.fromMap(
                                                          game,
                                                        ),
                                                        scrollController:
                                                            scrollController,
                                                      );
                                                    },
                                              ),
                                        ).then(
                                          (_) => controller.fetchProfileData(),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child:
                                        game != null &&
                                            game['cover_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            child: CorpusNetworkImage(
                                              url: game['cover_url'].replaceAll(
                                                't_cover_big',
                                                't_1080p',
                                              ),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                            if (isNumberOne)
                              Positioned(
                                top: -18,
                                left: 0,
                                right: 0,
                                child: Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 26,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
