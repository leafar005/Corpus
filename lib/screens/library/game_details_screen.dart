import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class GameDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsScreen({super.key, required this.gameData});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _isSaving = false;
  
  // Variables de estado del panel de usuario
  bool _isLoadingUserData = true;
  String _status = 'wishlist'; // Por defecto
  double _rating = 0; // 0 significa sin nota
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Siempre intentamos buscar los datos personales (si no existen, quedará limpio)
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'];

    try {
      final response = await Supabase.instance.client
          .from('user_games')
          .select()
          .eq('user_id', userId)
          .eq('game_id', igdbId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _status = response['status'] ?? 'wishlist';
          _rating = (response['rating'] ?? 0).toDouble();
          _commentController.text = response['comment'] ?? '';
          if (_rating > 0) {
            _ratingController.text = _rating.toStringAsFixed(1);
          }
        });
      }
    } catch (e) {
      // Si no encuentra los datos, no pasa nada, se queda con los valores por defecto (nuevo juego)
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _updateUserData() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'];

    try {
      // 1. Guardar primero la información pública del juego en la tabla global (por si nadie lo había guardado)
      await Supabase.instance.client.from('games').upsert({
        'igdb_id': igdbId,
        'title': widget.gameData['title'],
        'cover_url': widget.gameData['cover_url'],
        'release_date': widget.gameData['release_date'],
        'summary': widget.gameData['summary'],
        'genres': widget.gameData['genres'],
        'platforms': widget.gameData['platforms'],
        'developer': widget.gameData['developer'],
      });

      // 2. Guardar nuestra información privada de progreso
      await Supabase.instance.client.from('user_games').upsert({
        'user_id': userId,
        'game_id': igdbId,
        'status': _status,
        'rating': _rating > 0 ? _rating : null, // Si es 0, lo quitamos
        'comment': _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progreso guardado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
    
    // Truco: IGDB nos da por defecto 't_cover_big' que es muy pequeña (264x374). 
    // Para esta pantalla gigante, la cambiamos al vuelo a resolución 1080p.
    final highResCoverUrl = coverUrl.replaceAll('t_cover_big', 't_1080p');
    
    final summary = widget.gameData['summary'] ?? 'No hay sinopsis disponible para este juego.';
    final developer = widget.gameData['developer'] ?? 'Desarrollador desconocido';
    
    // Las listas en Supabase (JSONB) nos llegan a Flutter como List<dynamic>
    final List<dynamic> genresList = widget.gameData['genres'] ?? [];
    final List<dynamic> platformsList = widget.gameData['platforms'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Cabecera expansible con la imagen (SliverAppBar)
          SliverAppBar(
            expandedHeight: 350, // Muy alta para que la portada luzca
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
              background: highResCoverUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagen de fondo con recorte automático
                        Image.network(highResCoverUrl, fit: BoxFit.cover),
                        // Degradado oscuro para que el texto (título y botón de atrás) sea legible
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Colors.deepPurple.shade900),
            ),
          ),
          
          // Contenido de la ficha (Hacemos Scroll hacia abajo)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PANEL DE USUARIO (Visible siempre) ---
                  if (!_isLoadingUserData) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mi Progreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          
                          // Selector de Estado
                          Row(
                            children: [
                              const Icon(Icons.videogame_asset, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Estado:', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _status,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 'playing', child: Text('Jugando')),
                                    DropdownMenuItem(value: 'beaten', child: Text('Completado')),
                                    DropdownMenuItem(value: 'wishlist', child: Text('Lista de Deseos')),
                                    DropdownMenuItem(value: 'abandoned', child: Text('Abandonado')),
                                    DropdownMenuItem(value: 'on_hold', child: Text('En Pausa')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _status = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Selector de Nota
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 8),
                              const Text('Nota: ', style: TextStyle(fontSize: 16)),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _ratingController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    border: OutlineInputBorder(),
                                    hintText: '-',
                                  ),
                                  onChanged: (val) {
                                    // Sincronizar el texto con el slider
                                    final parsed = double.tryParse(val.replaceAll(',', '.'));
                                    if (parsed != null && parsed >= 0 && parsed <= 10) {
                                      setState(() => _rating = parsed);
                                    } else if (val.isEmpty) {
                                      setState(() => _rating = 0);
                                    }
                                  },
                                ),
                              ),
                              const Text(' / 10', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          Slider(
                            value: _rating,
                            min: 0,
                            max: 10,
                            divisions: 100, // Saltos de 0.1 para todos los decimales
                            activeColor: Colors.amber,
                            label: _rating > 0 ? _rating.toStringAsFixed(1) : "-",
                            onChanged: (value) {
                              setState(() {
                                _rating = value;
                                // Sincronizar el slider con el texto
                                _ratingController.text = value.toStringAsFixed(1);
                              });
                            },
                          ),
                          const Divider(height: 24),

                          // Caja de texto de Comentario
                          const Row(
                            children: [
                              Icon(Icons.edit_note, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Mi Diario / Reseña', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _commentController,
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: '¿Qué te está pareciendo el juego?',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _updateUserData,
                              icon: _isSaving 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.save),
                              label: Text(_isSaving ? 'Guardando...' : 'Guardar Progreso'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  // --- FIN PANEL DE USUARIO ---

                  // 1. Empresa Desarrolladora
                  Row(
                    children: [
                      const Icon(Icons.business, color: Colors.grey, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          developer,
                          style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // 2. Géneros (Chips dinámicos)
                  if (genresList.isNotEmpty) ...[
                    const Text('Géneros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, // Espacio horizontal
                      runSpacing: 8, // Espacio vertical si saltan de línea
                      children: genresList.map((g) => Chip(
                        label: Text(g.toString()),
                        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 3. Plataformas (Chips dinámicos)
                  if (platformsList.isNotEmpty) ...[
                    const Text('Plataformas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: platformsList.map((p) => Chip(
                        label: Text(p.toString()),
                        backgroundColor: Colors.blueGrey.withOpacity(0.3),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 4. Sinopsis (Texto largo)
                  const Text('Sinopsis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
                  ),
                  const SizedBox(height: 60), // Espacio extra al final para que respire
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
