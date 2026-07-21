import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../activity/review_details_screen.dart';

class GameDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsScreen({super.key, required this.gameData});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _isSaving = false;
  bool _isLoadingUserData = true;
  
  // Si es false, el usuario no tiene este juego en su biblioteca
  bool _inLibrary = false; 
  
  String _status = 'wishlist';
  double _rating = 0;
  String? _updatedAt;
  Map<String, dynamic>? _userData;
  
  // Datos enriquecidos desde IGDB (para cuando venimos de la biblioteca y faltan summary/developer)
  Map<String, dynamic> _enrichedData = {};

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _enrichGameData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  /// Enriquece los datos del juego llamando a IGDB si faltan campos importantes
  Future<void> _enrichGameData() async {
    final hasSummary = widget.gameData['summary'] != null;
    final hasDeveloper = widget.gameData['developer'] != null && widget.gameData['developer'] != 'Desconocido';
    final hasCategory = widget.gameData['category'] != null;

    // Si ya tenemos todo, no hace falta llamar a IGDB
    if (hasSummary && hasDeveloper && hasCategory) return;

    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) return;

    try {
      final game = await IGDBService.getGameById(igdbId is int ? igdbId : int.parse(igdbId.toString()));
      if (game != null && mounted) {
        String? developer;
        if (game['involved_companies'] != null && (game['involved_companies'] as List).isNotEmpty) {
          final companies = game['involved_companies'] as List;
          try {
            final dev = companies.firstWhere((c) => c['developer'] == true);
            developer = dev['company']['name'];
          } catch (_) {
            try { developer = companies[0]['company']['name']; } catch (_) {}
          }
        }

        setState(() {
          _enrichedData = {
            if (!hasSummary && game['summary'] != null) 'summary': game['summary'],
            if (!hasDeveloper && developer != null) 'developer': developer,
            if (!hasCategory && game['category'] != null) 'category': game['category'],
            if (widget.gameData['platforms'] == null || (widget.gameData['platforms'] as List).isEmpty)
              'platforms': game['platforms'] != null 
                  ? (game['platforms'] as List).map((p) => p['name']).toList() 
                  : [],
            if (widget.gameData['genres'] == null || (widget.gameData['genres'] as List).isEmpty)
              'genres': game['genres'] != null 
                  ? (game['genres'] as List).map((g) => g['name']).toList() 
                  : [],
          };
        });
      }
    } catch (e) {
      print('[CORPUS DEBUG] Error enriching game data: $e');
    }
  }

  Future<void> _fetchUserData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    print('[CORPUS DEBUG] _fetchUserData -> userId: $userId, igdbId: $igdbId');
    print('[CORPUS DEBUG] gameData keys: ${widget.gameData.keys.toList()}');

    try {
      final response = await Supabase.instance.client
          .from('user_games')
          .select('*, users!user_games_user_id_fkey(*)')
          .eq('user_id', userId)
          .eq('game_id', igdbId)
          .maybeSingle();

      print('[CORPUS DEBUG] _fetchUserData response: $response');

      if (response != null && mounted) {
        setState(() {
          _inLibrary = true;
          _status = response['status'] ?? 'wishlist';
          _rating = (response['rating'] ?? 0).toDouble();
          _commentController.text = response['comment'] ?? '';
          _updatedAt = response['updated_at'];
          _userData = response['users'];
          
          if (_rating > 0) {
            _ratingController.text = _rating.toStringAsFixed(1);
          }
        });
      } else {
        print('[CORPUS DEBUG] _fetchUserData -> No user_game found for this game');
        // Fetch current user data anyway just for the avatar in case they add a review
        final userResp = await Supabase.instance.client.from('users').select().eq('id', userId).maybeSingle();
        if (mounted) {
          setState(() {
            _userData = userResp;
          });
        }
      }
    } catch (e) {
      print('[CORPUS DEBUG] ERROR en _fetchUserData: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _updateUserData() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    // 1. Nos aseguramos de que el juego existe en el catálogo global
    try {
      await Supabase.instance.client.from('games').upsert({
        'igdb_id': igdbId,
        'title': widget.gameData['title'],
        'cover_url': widget.gameData['cover_url'],
        'release_date': widget.gameData['release_date'] != null 
            ? widget.gameData['release_date'].toString().split('T')[0] 
            : null,
        'genres': widget.gameData['genres'],
      }, onConflict: 'igdb_id', ignoreDuplicates: true);
      print('[CORPUS DEBUG] Game catalog upsert OK for igdbId: $igdbId');
    } catch (e) {
      print('[CORPUS DEBUG] Game catalog upsert error: $e');
    }

    // 2. Guardamos o actualizamos la reseña del usuario
    try {
      final dataToUpsert = {
        'user_id': userId,
        'game_id': igdbId,
        'status': _status,
        'rating': _rating >= 1 ? _rating : null, // CHECK constraint: rating >= 1
        'comment': _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      print('[CORPUS DEBUG] _updateUserData upsert data: $dataToUpsert');
      await Supabase.instance.client.from('user_games').upsert(
        dataToUpsert, 
        onConflict: 'user_id, game_id',
      );
      print('[CORPUS DEBUG] _updateUserData upsert SUCCESS');
      
      if (mounted) {
        // Marcar optimistamente que ya está en la biblioteca
        setState(() => _inLibrary = true);
        libraryUpdateNotifier.value++;
        Navigator.pop(context); // Cerrar el modal primero
        await _fetchUserData(); // Refrescar los datos para obtener el updated_at real
      }
    } catch (e) {
      print('[CORPUS DEBUG] ERROR en _updateUserData upsert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar reseña: $e')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildStatusChip(String value, String label, IconData icon, StateSetter setModalState) {
    final isSelected = _status == value;
    final color = _getStatusColor(value);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? (color == Theme.of(context).colorScheme.secondary ? Theme.of(context).scaffoldBackgroundColor : Colors.white) : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setModalState(() => _status = value),
      selectedColor: color,
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? (color == Theme.of(context).colorScheme.secondary ? Theme.of(context).scaffoldBackgroundColor : Colors.white) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: isSelected ? color : Colors.grey.shade700),
      showCheckmark: false,
    );
  }

  void _showEditModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder para manejar estado local en el modal
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Levantar con el teclado
                top: 24, left: 24, right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Añadir a mi biblioteca', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    const Text('Estado', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusChip('wishlist', 'Quiero', Icons.favorite, setModalState),
                        _buildStatusChip('playing', 'Jugando', Icons.videogame_asset, setModalState),
                        _buildStatusChip('beaten', 'Terminado', Icons.emoji_events, setModalState),
                        _buildStatusChip('abandoned', 'Abandonado', Icons.cancel_outlined, setModalState),
                        _buildStatusChip('on_hold', 'En Pausa', Icons.pause_circle_outline, setModalState),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Nota (Opcional)', style: TextStyle(color: Colors.grey)),
                    Slider(
                      value: _rating,
                      min: 0, max: 10, divisions: 100,
                      activeColor: Theme.of(context).colorScheme.secondary,
                      label: _rating > 0 ? _rating.toStringAsFixed(1) : "-",
                      onChanged: (val) => setModalState(() => _rating = val),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text('Reseña (Opcional)', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 4, minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: '¿Qué te pareció el juego?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () {
                          setState(() {}); // Actualiza padre
                          _updateUserData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: _isSaving 
                          ? CircularProgressIndicator(color: Theme.of(context).scaffoldBackgroundColor) 
                          : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      return "${date.day} de ${months[date.month - 1]} de ${date.year}";
    } catch (e) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch(status) {
      case 'beaten': return Theme.of(context).colorScheme.secondary;
      case 'playing': return Colors.blueAccent;
      case 'wishlist': return Theme.of(context).colorScheme.primary;
      default: return Colors.grey.shade700;
    }
  }

  String _getStatusText(String status) {
    switch(status) {
      case 'beaten': return 'Terminado';
      case 'playing': return 'Jugando';
      case 'wishlist': return 'Quiero';
      case 'abandoned': return 'Abandonado';
      case 'on_hold': return 'En Pausa';
      default: return 'Desconocido';
    }
  }

  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'beaten': return Icons.emoji_events;
      case 'playing': return Icons.videogame_asset;
      case 'wishlist': return Icons.favorite;
      case 'abandoned': return Icons.cancel_outlined;
      case 'on_hold': return Icons.pause_circle_outline;
      default: return Icons.flag;
    }
  }

  Future<void> _deleteFromLibrary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar de biblioteca'),
        content: const Text('¿Seguro que quieres eliminar este juego de tu biblioteca? Se borrará tu reseña y nota.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      await Supabase.instance.client
          .from('user_games')
          .delete()
          .eq('user_id', userId)
          .eq('game_id', igdbId);

      if (mounted) {
        setState(() {
          _inLibrary = false;
          _status = 'wishlist';
          _rating = 0;
          _commentController.clear();
          _ratingController.clear();
          _updatedAt = null;
        });
        libraryUpdateNotifier.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Juego eliminado de tu biblioteca')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Widget _buildStatusButton() {
    final color = _inLibrary ? _getStatusColor(_status) : Theme.of(context).colorScheme.primary;
    final text = _inLibrary ? _getStatusText(_status) : 'Añadir a Biblioteca';
    final icon = _inLibrary ? _getStatusIcon(_status) : Icons.add;
    final textColor = color == Theme.of(context).colorScheme.secondary ? Theme.of(context).scaffoldBackgroundColor : Colors.white;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showEditModal,
            icon: Icon(icon, color: textColor),
            label: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (_inLibrary) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: Theme.of(context).colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditModal();
                } else if (value == 'delete') {
                  _deleteFromLibrary();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 12),
                      Text('Eliminar de biblioteca', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewCard() {
    if (_rating == 0 && _commentController.text.isEmpty) return const SizedBox.shrink();

    final dateStr = _updatedAt != null ? _formatDate(_updatedAt!) : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailsScreen(
              gameData: widget.gameData,
              userData: _userData,
              rating: _rating,
              comment: _commentController.text,
              status: _status,
              updatedAt: _updatedAt,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(_getStatusText(_status), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            if (_rating > 0) ...[
              Row(
                children: [
                  Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(_rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_commentController.text.isNotEmpty)
              Text(
                _commentController.text,
                style: const TextStyle(fontSize: 15, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
    final highResCoverUrl = coverUrl.replaceAll('t_cover_big', 't_1080p');
    
    // Datos con fallback a _enrichedData (para cuando venimos de la biblioteca)
    final summary = widget.gameData['summary'] ?? _enrichedData['summary'];
    final developer = widget.gameData['developer'] ?? _enrichedData['developer'];
    final category = widget.gameData['category'] ?? _enrichedData['category'];
    final List<dynamic> genresList = (widget.gameData['genres'] as List?)?.isNotEmpty == true 
        ? widget.gameData['genres'] 
        : (_enrichedData['genres'] as List? ?? []);
    final List<dynamic> platformsList = (widget.gameData['platforms'] as List?)?.isNotEmpty == true 
        ? widget.gameData['platforms'] 
        : (_enrichedData['platforms'] as List? ?? []);

    // Formatear fecha de lanzamiento
    String? releaseDate;
    if (widget.gameData['release_date'] != null) {
      try {
        final date = DateTime.parse(widget.gameData['release_date'].toString());
        const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
        releaseDate = '${date.day} de ${months[date.month - 1]} de ${date.year}';
      } catch (_) {}
    }

    // Etiqueta de categoría (Remake, Remaster, DLC, etc.)
    String? categoryLabel;
    if (category != null) {
      switch (category) {
        case 1: categoryLabel = 'DLC'; break;
        case 2: categoryLabel = 'Expansión'; break;
        case 8: categoryLabel = 'Remake'; break;
        case 9: categoryLabel = 'Remaster'; break;
        case 10: categoryLabel = 'Edición Expandida'; break;
        case 11: categoryLabel = 'Port'; break;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            centerTitle: false, 
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16), 
              title: Text(
                title, 
                style: TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(color: Theme.of(context).scaffoldBackgroundColor, blurRadius: 10)])
              ),
              background: highResCoverUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(highResCoverUrl, fit: BoxFit.cover, alignment: Alignment.topCenter),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter, 
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(context).scaffoldBackgroundColor, 
                                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8), 
                                Colors.transparent, 
                                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6)
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Theme.of(context).primaryColorDark),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del juego: desarrollador, fecha, categoría
                  if (developer != null && developer != 'Desconocido' && developer != 'Desarrollador desconocido')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(developer, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),

                  // Fecha de lanzamiento y categoría en una fila
                  if (releaseDate != null || categoryLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          if (releaseDate != null) ...[
                            const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                            const SizedBox(width: 6),
                            Text(releaseDate, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                          if (releaseDate != null && categoryLabel != null)
                            const SizedBox(width: 16),
                          if (categoryLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryLabel == 'Remake' ? Theme.of(context).colorScheme.secondary.withOpacity(0.2) 
                                     : categoryLabel == 'Remaster' ? Colors.tealAccent.withOpacity(0.2) 
                                     : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: categoryLabel == 'Remake' ? Theme.of(context).colorScheme.secondary.withOpacity(0.5) 
                                       : categoryLabel == 'Remaster' ? Colors.tealAccent.withOpacity(0.5) 
                                       : Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                categoryLabel,
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold,
                                  color: categoryLabel == 'Remake' ? Theme.of(context).colorScheme.secondary 
                                       : categoryLabel == 'Remaster' ? Colors.tealAccent 
                                       : Colors.grey.shade300,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (_isLoadingUserData)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _buildStatusButton(),
                    _buildReviewCard(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  if (genresList.isNotEmpty) ...[
                    const Text('Géneros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: genresList.map((g) => Chip(
                        label: Text(g.toString()),
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (platformsList.isNotEmpty) ...[
                    const Text('Plataformas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: platformsList.map((p) => Chip(
                        label: Text(p.toString()),
                        backgroundColor: Colors.blueGrey.withOpacity(0.3),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (summary != null) ...[
                    const Text('Sinopsis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(summary, style: const TextStyle(fontSize: 16, height: 1.6)),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
