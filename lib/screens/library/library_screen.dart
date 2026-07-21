import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'search_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Función para obtener los juegos directamente de Supabase
  Future<List<Map<String, dynamic>>> _fetchMyGames() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
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
        title: const Text('Mi Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buscar en tu biblioteca (Próximamente)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Supabase.instance.client.auth.signOut();
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
                style: TextStyle(color: Colors.redAccent.shade100, fontSize: 16),
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
                  Icon(Icons.videogame_asset_off, size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu biblioteca está vacía',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pulsa el botón + para añadir\ntus primeros juegos.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // 4. Estado de éxito (dibujamos la cuadrícula real)
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150, // Anchura máxima ideal de cada carátula
              childAspectRatio: 0.7, 
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: myGames.length,
            itemBuilder: (context, index) {
              final userGame = myGames[index];
              // gameData contiene los datos que cruzamos de la tabla 'games'
              final gameData = userGame['games']; 
              final title = gameData['title'] ?? 'Desconocido';
              final coverUrl = gameData['cover_url'] ?? '';
              
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl.isNotEmpty
                        ? Image.network(coverUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.deepPurple.shade900,
                            child: const Center(child: Icon(Icons.videogame_asset, size: 40, color: Colors.white54)),
                          ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Abrimos el buscador y esperamos a que el usuario termine
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
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
