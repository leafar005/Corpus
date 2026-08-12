import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/widgets/corpus_section_title.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Función para obtener los juegos directamente de Supabase
  Future<List<Map<String, dynamic>>> _fetchMyGames() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    // Hacemos una consulta cruzada (JOIN) entre user_games y games
    final response = await Supabase.instance.client
        .from('user_games')
        .select('*, games(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CorpusScreenTitle('Mi Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Buscar en tu biblioteca (Próximamente)'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('main_tab_index', 0);
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMyGames(),
        builder: (context, snapshot) {
          // 1. Estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Estado de error (ej. sin internet)
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Oops, no hemos podido cargar tu biblioteca.\nRevisa tu conexión a internet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
              ),
            );
          }

          final myGames = snapshot.data ?? [];

          // 3. Estado vacío (cuando la nube dice que tienes 0 juegos)
          if (myGames.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videogame_asset_off,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu biblioteca está vacía',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pulsa el botón + para añadir\ntus primeros juegos.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // 4. Estado de éxito (dibujamos la cuadrícula real)
          return GridView.builder(
            padding: EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              top: 8.0,
              bottom: getBottomSpacer(context),
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150, // Anchura máxima ideal de cada carátula
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: myGames.length,
            itemBuilder: (context, index) {
              final userGame = myGames[index];
              final gameData = Game.fromMap(
                userGame['games'] as Map<String, dynamic>,
              );
              final rating = (userGame['rating'] ?? 0).toDouble();

              return GameCard(
                game: gameData,
                isInLibrary: true,
                userRating: rating,
                onReturn: () => setState(() {}),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Abrimos el buscador y esperamos a que el usuario termine
          await context.pushSearch();
          // Cuando la ventana de búsqueda se cierra, forzamos un redibujado.
          // Esto hará que el FutureBuilder vuelva a descargar los juegos de Supabase
          // mostrando tu nueva adquisición al instante.
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
