import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../../utils/igdb_constants.dart';
import '../activity/review_details_screen.dart';

class GameDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsScreen({super.key, required this.gameData});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _isSaving = false;
  String? _selectedScreenshotUrl;
  bool _isLoadingUserData = true;
  bool _isEnriching = true;
  int _selectedMainTabIndex = 0;
  int _selectedMediaTabIndex = 0;
  
  // Si es false, el usuario no tiene este juego en su biblioteca
  bool _inLibrary = false; 
  
  String _status = 'wishlist';
  double _rating = 0;
  double _ratingGameplay = 0;
  double _ratingNarrative = 0;
  double _ratingSoundtrack = 0;
  double _ratingVisuals = 0;
  String? _updatedAt;
  Map<String, dynamic>? _userData;
  
  // Datos enriquecidos desde IGDB (para cuando venimos de la biblioteca y faltan summary/developer)
  Map<String, dynamic> _enrichedData = {};

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();

  // Reviews from the reviews table
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _selectRandomScreenshot(widget.gameData['screenshots']);
    _enrichGameData();
    _fetchReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }
  /// Muestra una screenshot aleatoria cada vez que se entra a la ventana del juego
  void _selectRandomScreenshot(dynamic screenshotsData) {
    if (screenshotsData != null && screenshotsData is List && screenshotsData.isNotEmpty) {
      final randomId = screenshotsData[Random().nextInt(screenshotsData.length)];
      final url = IGDBService.getScreenshotUrl(randomId.toString());
      setState(() {
        _selectedScreenshotUrl = url;
      });
    }
  }

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: GestureDetector(
                  onTap: () {}, // Evita que se cierre al tocar la imagen
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enriquece los datos del juego llamando a IGDB si faltan campos importantes
  Future<void> _enrichGameData() async {
    final hasSummary = widget.gameData['summary'] != null;
    final hasDeveloper = widget.gameData['developer'] != null && widget.gameData['developer'] != 'Desconocido';
    final hasCategory = widget.gameData['category'] != null;

    // Si ya tenemos todo, no hace falta llamar a IGDB
    if (hasSummary && hasDeveloper && hasCategory && widget.gameData['screenshots'] != null) {
      if (mounted) setState(() => _isEnriching = false);
      return;
    }

    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) {
      if (mounted) setState(() => _isEnriching = false);
      return;
    }

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
            if (game['parent_game'] != null) 'parent_game': game['parent_game'],
            if (widget.gameData['platforms'] == null || (widget.gameData['platforms'] as List).isEmpty)
              'platforms': game['platforms'] != null 
                  ? (game['platforms'] as List).map((p) => p['name']).toList() 
                  : [],
            if (widget.gameData['genres'] == null || (widget.gameData['genres'] as List).isEmpty)
              'genres': game['genres'] != null 
                  ? (game['genres'] as List).map((g) => g['name']).toList() 
                  : [],
            if (widget.gameData['screenshots'] == null || (widget.gameData['screenshots'] as List).isEmpty)
              'screenshots': game['screenshots'] != null 
                  ? (game['screenshots'] as List).map((s) => s['image_id']).toList() 
                  : [],
            if (widget.gameData['artworks'] == null || (widget.gameData['artworks'] as List).isEmpty)
              'artworks': game['artworks'] != null 
                  ? (game['artworks'] as List).map((a) => a['image_id']).toList() 
                  : [],
            if (widget.gameData['videos'] == null || (widget.gameData['videos'] as List).isEmpty)
              'videos': game['videos'] != null 
                  ? (game['videos'] as List).map((v) => v['video_id']).toList() 
                  : [],
            if (widget.gameData['themes'] == null)
              'themes': game['themes'] != null ? (game['themes'] as List).map((t) => t['name']).toList() : [],
            if (widget.gameData['game_modes'] == null)
              'game_modes': game['game_modes'] != null ? (game['game_modes'] as List).map((m) => m['name']).toList() : [],
            if (widget.gameData['player_perspectives'] == null)
              'player_perspectives': game['player_perspectives'] != null ? (game['player_perspectives'] as List).map((p) => p['name']).toList() : [],
          };
        });
        
        if (_selectedScreenshotUrl == null && _enrichedData['screenshots'] != null) {
          _selectRandomScreenshot(_enrichedData['screenshots']);
        }
      }
    } catch (e) {
      print('[CORPUS DEBUG] Error enriching game data: $e');
    } finally {
      if (mounted) setState(() => _isEnriching = false);
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
          _ratingGameplay = (response['rating_gameplay'] ?? 0).toDouble();
          _ratingNarrative = (response['rating_narrative'] ?? 0).toDouble();
          _ratingSoundtrack = (response['rating_soundtrack'] ?? 0).toDouble();
          _ratingVisuals = (response['rating_visuals'] ?? 0).toDouble();
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

  Future<void> _fetchReviews() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    setState(() => _isLoadingReviews = true);
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*, review_likes(user_id), review_comments(id)')
          .eq('user_id', userId)
          .eq('game_id', igdbId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response);
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('[CORPUS DEBUG] Error fetching reviews: $e');
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }



  Widget _buildSubRatingSlider(String label, IconData icon, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const Spacer(),
            Text(value > 0 ? value.toStringAsFixed(1) : '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        Slider(
          value: value,
          min: 0, max: 10, divisions: 100,
          activeColor: Theme.of(context).colorScheme.primary,
          label: value > 0 ? value.toStringAsFixed(1) : "-",
          onChanged: onChanged,
        ),
      ],
    );
  }



  String _getMonthAbbr(int month) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return months[month - 1];
  }

  String _formatDateRange(String? from, String? until) {
    if (from == null) return '';
    try {
      final f = DateTime.parse(from);
      final fs = '${f.day} ${_getMonthAbbr(f.month)}';
      if (until == null) return '$fs ${f.year}';
      final u = DateTime.parse(until);
      final us = '${u.day} ${_getMonthAbbr(u.month)} ${u.year}';
      return f.year == u.year ? '$fs - $us' : '$fs ${f.year} - $us';
    } catch (_) { return ''; }
  }

  String _getCompletionTypeText(String type) {
    switch(type) {
      case 'story': return 'Historia';
      case 'story_extras': return 'Historia + Extras';
      case '100_percent': return '100%';
      default: return type;
    }
  }

  IconData _getCompletionTypeIcon(String type) {
    switch(type) {
      case 'story': return Icons.auto_stories;
      case 'story_extras': return Icons.extension;
      case '100_percent': return Icons.stars;
      default: return Icons.flag;
    }
  }

  Widget _buildInfoBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showReviewModal({Map<String, dynamic>? existingReview}) {
    final hasReview = existingReview != null;
    final r = existingReview;

    double reviewRating = hasReview ? (r!['rating'] ?? 0).toDouble() : _rating;
    double reviewRatingGameplay = hasReview ? (r!['rating_gameplay'] ?? 0).toDouble() : _ratingGameplay;
    double reviewRatingNarrative = hasReview ? (r!['rating_narrative'] ?? 0).toDouble() : _ratingNarrative;
    double reviewRatingSoundtrack = hasReview ? (r!['rating_soundtrack'] ?? 0).toDouble() : _ratingSoundtrack;
    double reviewRatingVisuals = hasReview ? (r!['rating_visuals'] ?? 0).toDouble() : _ratingVisuals;
    String reviewStatus = hasReview ? (r!['status'] ?? _status) : _status;
    String reviewCompletionType = hasReview ? (r!['completion_type'] ?? 'story') : 'story';
    bool reviewIsReplay = hasReview ? (r!['is_replay'] ?? false) : false;
    int reviewReplayNumber = hasReview ? (r!['replay_number'] ?? 1) : 1;
    String? reviewPlatform = hasReview ? r!['platform'] : null;
    String playTimeText = hasReview && r!['play_time_hours'] != null ? r['play_time_hours'].toString() : '';
    DateTime? reviewPlayedFrom = hasReview && r!['played_from'] != null ? DateTime.parse(r['played_from']) : null;
    DateTime? reviewPlayedUntil = hasReview && r!['played_until'] != null ? DateTime.parse(r['played_until']) : null;
    int reviewProgressPercent = hasReview ? (r!['progress_percent'] ?? 0) : 0;
    
    final reviewCommentController = TextEditingController(text: hasReview ? (r!['comment'] ?? '') : _commentController.text);
    final String? reviewId = hasReview ? r!['id'] : null;

    final List<dynamic> platforms = (widget.gameData['platforms'] as List?)?.isNotEmpty == true
        ? widget.gameData['platforms']
        : (_enrichedData['platforms'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Widget chip(String value, String label, IconData icon, String current, Color color, Function(String) onSelect) {
              final sel = current == value;
              final tc = sel ? (color == Theme.of(modalContext).colorScheme.secondary ? Theme.of(modalContext).scaffoldBackgroundColor : Colors.white) : Colors.white70;
              return ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: sel ? tc : Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(label),
                ]),
                selected: sel,
                onSelected: (_) => setModalState(() => onSelect(value)),
                selectedColor: color,
                backgroundColor: Theme.of(modalContext).colorScheme.surfaceVariant,
                labelStyle: TextStyle(color: tc, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: sel ? color : Colors.grey.shade700),
                showCheckmark: false,
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasReview ? 'Editar Reseña' : 'Añadir Reseña', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    const Text('Estado', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      chip('wishlist', 'Quiero', Icons.favorite, reviewStatus, _getStatusColor('wishlist'), (v) => reviewStatus = v),
                      chip('playing', 'Jugando', Icons.videogame_asset, reviewStatus, _getStatusColor('playing'), (v) => reviewStatus = v),
                      chip('beaten', 'Terminado', Icons.emoji_events, reviewStatus, _getStatusColor('beaten'), (v) => reviewStatus = v),
                      chip('abandoned', 'Abandonado', Icons.cancel_outlined, reviewStatus, _getStatusColor('abandoned'), (v) => reviewStatus = v),
                      chip('on_hold', 'En Pausa', Icons.pause_circle_outline, reviewStatus, _getStatusColor('on_hold'), (v) => reviewStatus = v),
                    ]),
                    const SizedBox(height: 24),

                    if (reviewStatus != 'wishlist') ...[
                      const Text('Tipo de completado', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        chip('story', 'Historia', Icons.auto_stories, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('story_extras', 'Historia + Extras', Icons.extension, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('100_percent', '100%', Icons.stars, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                      ]),
                      const SizedBox(height: 24),

                      Row(children: [
                        const Text('Nota', style: TextStyle(color: Colors.grey)),
                        const Spacer(),
                        Text(reviewRating > 0 ? reviewRating.toStringAsFixed(1) : '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(modalContext).colorScheme.secondary)),
                      ]),
                      Slider(
                        value: reviewRating, min: 0, max: 10, divisions: 100,
                        activeColor: Theme.of(modalContext).colorScheme.secondary,
                        label: reviewRating > 0 ? reviewRating.toStringAsFixed(1) : "-",
                        onChanged: (val) => setModalState(() => reviewRating = val),
                      ),

                      Theme(
                        data: Theme.of(modalContext).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Desglosar nota', style: TextStyle(fontSize: 14)),
                          children: [
                            _buildSubRatingSlider('Gameplay', Icons.sports_esports, reviewRatingGameplay, (val) => setModalState(() => reviewRatingGameplay = val)),
                            _buildSubRatingSlider('Narrativa', Icons.auto_stories, reviewRatingNarrative, (val) => setModalState(() => reviewRatingNarrative = val)),
                            _buildSubRatingSlider('Banda Sonora', Icons.music_note, reviewRatingSoundtrack, (val) => setModalState(() => reviewRatingSoundtrack = val)),
                            _buildSubRatingSlider('Gráficos', Icons.brush, reviewRatingVisuals, (val) => setModalState(() => reviewRatingVisuals = val)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(children: [
                        const Text('Rejugada', style: TextStyle(color: Colors.grey)),
                        const Spacer(),
                        Switch(
                          value: reviewIsReplay,
                          onChanged: (val) => setModalState(() => reviewIsReplay = val),
                          activeColor: Theme.of(modalContext).colorScheme.primary,
                        ),
                      ]),
                      if (reviewIsReplay)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Text('Nº de rejugada', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                controller: TextEditingController(text: reviewReplayNumber.toString()),
                                onChanged: (val) { final n = int.tryParse(val); if (n != null) setModalState(() => reviewReplayNumber = n); },
                              ),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 16),
                      const Text('Reseña', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reviewCommentController,
                        maxLines: 4, minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: '¿Qué te pareció el juego?', border: OutlineInputBorder()),
                      ),

                      Theme(
                        data: Theme.of(modalContext).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Información Extra', style: TextStyle(fontSize: 14)),
                          children: [
                            if (platforms.isNotEmpty) ...[
                              const Text('Plataforma', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: reviewPlatform,
                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                dropdownColor: Theme.of(modalContext).colorScheme.surfaceVariant,
                                items: platforms.map((p) => DropdownMenuItem(value: p.toString(), child: Text(p.toString(), style: const TextStyle(fontSize: 14)))).toList(),
                                onChanged: (val) => setModalState(() => reviewPlatform = val),
                                hint: const Text('Seleccionar plataforma'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Text('Tiempo de juego (horas)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ej: 45.5', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onChanged: (val) => setModalState(() => playTimeText = val),
                            ),
                            const SizedBox(height: 16),
                            const Text('Fecha de juego', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(reviewPlayedFrom != null ? '${reviewPlayedFrom!.day} ${_getMonthAbbr(reviewPlayedFrom!.month)} ${reviewPlayedFrom!.year}' : 'Desde', style: const TextStyle(fontSize: 13)),
                                  onPressed: () async {
                                    final d = await showDatePicker(context: modalContext, initialDate: reviewPlayedFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                                    if (d != null) setModalState(() => reviewPlayedFrom = d);
                                  },
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.grey))),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(reviewPlayedUntil != null ? '${reviewPlayedUntil!.day} ${_getMonthAbbr(reviewPlayedUntil!.month)} ${reviewPlayedUntil!.year}' : 'Hasta', style: const TextStyle(fontSize: 13)),
                                  onPressed: () async {
                                    final d = await showDatePicker(context: modalContext, initialDate: reviewPlayedUntil ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                                    if (d != null) setModalState(() => reviewPlayedUntil = d);
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            Row(children: [
                              const Text('Progreso', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const Spacer(),
                              Text('$reviewProgressPercent%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(modalContext).colorScheme.primary)),
                            ]),
                            Slider(
                              value: reviewProgressPercent.toDouble(), min: 0, max: 100, divisions: 100,
                              activeColor: Theme.of(modalContext).colorScheme.primary,
                              label: '$reviewProgressPercent%',
                              onChanged: (val) => setModalState(() => reviewProgressPercent = val.round()),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () {
                          _saveReview(
                            reviewId: reviewId,
                            rating: reviewRating, ratingGameplay: reviewRatingGameplay,
                            ratingNarrative: reviewRatingNarrative, ratingSoundtrack: reviewRatingSoundtrack,
                            ratingVisuals: reviewRatingVisuals, comment: reviewCommentController.text,
                            status: reviewStatus, completionType: reviewStatus == 'wishlist' ? 'none' : reviewCompletionType,
                            isReplay: reviewStatus == 'wishlist' ? false : reviewIsReplay, replayNumber: reviewIsReplay ? reviewReplayNumber : null,
                            platform: reviewPlatform, playTimeHours: double.tryParse(playTimeText),
                            playedFrom: reviewPlayedFrom, playedUntil: reviewPlayedUntil,
                            progressPercent: reviewProgressPercent > 0 ? reviewProgressPercent : null,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(modalContext).colorScheme.secondary,
                          foregroundColor: Theme.of(modalContext).scaffoldBackgroundColor,
                        ),
                        child: _isSaving
                          ? CircularProgressIndicator(color: Theme.of(modalContext).scaffoldBackgroundColor)
                          : Text(reviewStatus == 'wishlist' ? 'Guardar' : 'Publicar Reseña', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveReview({
    String? reviewId,
    required double rating, required double ratingGameplay,
    required double ratingNarrative, required double ratingSoundtrack,
    required double ratingVisuals, required String comment,
    required String status, required String completionType,
    required bool isReplay, required int? replayNumber,
    required String? platform, required double? playTimeHours,
    required DateTime? playedFrom, required DateTime? playedUntil,
    required int? progressPercent,
  }) async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      await Supabase.instance.client.from('games').upsert({
        'igdb_id': igdbId,
        'title': widget.gameData['title'],
        'cover_url': widget.gameData['cover_url'],
        'release_date': widget.gameData['release_date']?.toString().split('T')[0],
        'genres': widget.gameData['genres'] ?? _enrichedData['genres'],
        'category': widget.gameData['category'] ?? _enrichedData['category'],
        'parent_game': widget.gameData['parent_game'] ?? _enrichedData['parent_game'],
        'themes': widget.gameData['themes'] ?? _enrichedData['themes'],
        'game_modes': widget.gameData['game_modes'] ?? _enrichedData['game_modes'],
        'player_perspectives': widget.gameData['player_perspectives'] ?? _enrichedData['player_perspectives'],
        'platforms': widget.gameData['platforms'] ?? _enrichedData['platforms'],
      }, onConflict: 'igdb_id', ignoreDuplicates: true);
    } catch (e) {
      print('[CORPUS DEBUG] Game catalog upsert error: $e');
    }

    try {
      final reviewData = {
        'user_id': userId,
        'game_id': igdbId,
        'rating': rating >= 1 ? rating : null,
        'rating_gameplay': ratingGameplay >= 1 ? ratingGameplay : null,
        'rating_narrative': ratingNarrative >= 1 ? ratingNarrative : null,
        'rating_soundtrack': ratingSoundtrack >= 1 ? ratingSoundtrack : null,
        'rating_visuals': ratingVisuals >= 1 ? ratingVisuals : null,
        'comment': comment.trim().isNotEmpty ? comment.trim() : null,
        'status': status,
        'completion_type': completionType,
        'is_replay': isReplay,
        'replay_number': isReplay ? replayNumber : null,
        'platform': platform,
        'play_time_hours': playTimeHours != null && playTimeHours > 0 ? playTimeHours : null,
        'played_from': playedFrom?.toIso8601String().split('T')[0],
        'played_until': playedUntil?.toIso8601String().split('T')[0],
        'progress_percent': progressPercent,
      };

      if (reviewId != null) {
        await Supabase.instance.client.from('reviews').update(reviewData).eq('id', reviewId);
      } else {
        await Supabase.instance.client.from('reviews').insert(reviewData);
      }

      await Supabase.instance.client.from('user_games').upsert({
        'user_id': userId,
        'game_id': igdbId,
        'status': status,
        'rating': rating >= 1 ? rating : null,
        'rating_gameplay': ratingGameplay >= 1 ? ratingGameplay : null,
        'rating_narrative': ratingNarrative >= 1 ? ratingNarrative : null,
        'rating_soundtrack': ratingSoundtrack >= 1 ? ratingSoundtrack : null,
        'rating_visuals': ratingVisuals >= 1 ? ratingVisuals : null,
        'comment': comment.trim().isNotEmpty ? comment.trim() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, game_id');

      if (mounted) {
        setState(() => _inLibrary = true);
        libraryUpdateNotifier.value++;
        Navigator.pop(context);
        await Future.wait([_fetchUserData(), _fetchReviews()]);
      }
    } catch (e) {
      print('[CORPUS DEBUG] Error saving review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar reseña: $e')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          _ratingGameplay = 0;
          _ratingNarrative = 0;
          _ratingSoundtrack = 0;
          _ratingVisuals = 0;
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
            onPressed: () => _showReviewModal(existingReview: _reviews.isNotEmpty ? _reviews.first : null),
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
                  _showReviewModal(existingReview: _reviews.isNotEmpty ? _reviews.first : null);
                } else if (value == 'review') {
                  _showReviewModal();
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
                const PopupMenuItem(
                  value: 'review',
                  child: Row(
                    children: [
                      Icon(Icons.rate_review, size: 20),
                      SizedBox(width: 12),
                      Text('Añadir Reseña'),
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

  Widget _buildSubRatingBadge(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 4),
          Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _reviews.map((review) {
        final rating = (review['rating'] ?? 0).toDouble();
        final comment = review['comment'] ?? '';
        final completionType = review['completion_type'] ?? 'story';
        final isReplay = review['is_replay'] ?? false;
        final replayNumber = review['replay_number'];
        final rPlatform = review['platform'];
        final playTime = (review['play_time_hours'] ?? 0).toDouble();
        final playedFrom = review['played_from'];
        final playedUntil = review['played_until'];
        final progress = review['progress_percent'];
        final createdAt = review['created_at'];
        final rGameplay = (review['rating_gameplay'] ?? 0).toDouble();
        final rNarrative = (review['rating_narrative'] ?? 0).toDouble();
        final rSoundtrack = (review['rating_soundtrack'] ?? 0).toDouble();
        final rVisuals = (review['rating_visuals'] ?? 0).toDouble();
        final dateStr = createdAt != null ? _formatDate(createdAt) : '';

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => ReviewDetailsScreen(
                gameData: widget.gameData,
                userData: _userData,
                reviewData: review,
              ),
            ));
          },
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (completionType == 'none')
                    const Text('Quiero', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))
                  else
                    _buildInfoBadge(_getCompletionTypeText(completionType), _getCompletionTypeIcon(completionType), Theme.of(context).colorScheme.primary),
                  if (isReplay) _buildInfoBadge('Rejugada${replayNumber != null ? ' #$replayNumber' : ''}', Icons.replay, Colors.orangeAccent),
                  if (rPlatform != null) _buildInfoBadge(rPlatform, Icons.devices, Colors.blueGrey),
                ]),
                const Divider(height: 24),
                if (rating > 0) ...[
                  Row(children: [
                    Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (rGameplay > 0 || rNarrative > 0 || rSoundtrack > 0 || rVisuals > 0) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (rGameplay > 0) _buildSubRatingBadge('Gameplay', rGameplay),
                    if (rNarrative > 0) _buildSubRatingBadge('Narrativa', rNarrative),
                    if (rSoundtrack > 0) _buildSubRatingBadge('Música', rSoundtrack),
                    if (rVisuals > 0) _buildSubRatingBadge('Gráficos', rVisuals),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (comment.isNotEmpty) Text(comment, style: const TextStyle(fontSize: 15, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
                if (playTime > 0 || playedFrom != null || progress != null) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    if (playTime > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${playTime.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    if (playedFrom != null) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_formatDateRange(playedFrom, playedUntil), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    if (progress != null) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.pie_chart, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$progress%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ]),
                ],
                const SizedBox(height: 16),
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _getPlatformStyle(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('pc') || lower.contains('windows')) {
      return {'color': Colors.blue.shade700, 'icon': 'assets/images/windows.png', 'textColor': Colors.white};
    }
    if (lower.contains('linux')) {
      return {'color': Colors.orangeAccent.shade700, 'icon': 'assets/images/linux.png', 'textColor': Colors.white};
    }
    if (lower.contains('playstation') || lower == 'psn' || lower == 'ps2' || lower == 'ps3' || lower == 'ps4' || lower == 'ps5' || lower.contains('vita')) {
      return {'color': const Color(0xFF003791), 'icon': 'assets/images/playstation.png', 'textColor': Colors.white};
    }
    if (lower.contains('xbox')) {
      return {'color': const Color(0xFF107C10), 'icon': 'assets/images/xbox.png', 'textColor': Colors.white};
    }
    if (lower.contains('wii')) {
      return {'color': Colors.grey.shade400, 'icon': 'assets/images/wii.png', 'textColor': Colors.black87};
    }
    if (lower.contains('switch') || lower.contains('nintendo')) {
      return {'color': const Color(0xFFE60012), 'icon': 'assets/images/switch.png', 'textColor': Colors.white};
    }
    if (lower.contains('mac') || lower.contains('ios') || lower.contains('apple')) {
      return {'color': Colors.grey.shade800, 'icon': 'assets/images/mac.png', 'textColor': Colors.white};
    }
    if (lower.contains('android')) {
      return {'color': const Color(0xFF3DDC84), 'icon': 'assets/images/android.png', 'textColor': Colors.black87};
    }
    if (lower.contains('google') || lower.contains('stadia')) {
      return {'color': Colors.deepOrange, 'icon': 'assets/images/google.png', 'textColor': Colors.white};
    }
    return {'color': Colors.blueGrey.withOpacity(0.3), 'icon': null, 'textColor': Colors.white};
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
    final highResCoverUrl = coverUrl.replaceAll('t_cover_big', 't_1080p');
    
    // Datos con fallback a _enrichedData (para cuando venimos de la biblioteca)
    final summary = widget.gameData['summary'] ?? _enrichedData['summary'];
    final developer = widget.gameData['developer'] ?? _enrichedData['developer'];
    final hasParentGame = widget.gameData['parent_game'] != null || _enrichedData['parent_game'] != null;
    
    // Resolver categoría usando IgdbConstants (centralizado)
    final int? resolvedCategory = IgdbConstants.resolveCategory(
      (widget.gameData['category'] ?? _enrichedData['category']) as int?,
      title,
      hasParentGame: hasParentGame,
    );
    final String? categoryLabel = resolvedCategory != null && !IgdbConstants.isMainGame(resolvedCategory)
        ? IgdbConstants.getCategoryName(resolvedCategory)
        : null;
    final Color catColor = resolvedCategory != null
        ? IgdbConstants.getCategoryColor(resolvedCategory, themeSecondary: Theme.of(context).colorScheme.secondary)
        : Colors.grey;

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

    final Widget coverArtWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: highResCoverUrl.isNotEmpty
            ? Image.network(highResCoverUrl, fit: BoxFit.cover)
            : Container(color: Theme.of(context).primaryColorDark, height: 350),
      ),
    );

    final Widget headerInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, height: 1.1)
        ),
        const SizedBox(height: 12),
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
        if (releaseDate != null || categoryLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (releaseDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                      const SizedBox(width: 6),
                      Text(releaseDate, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                if (categoryLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: catColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      categoryLabel,
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: catColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final Widget interactiveWidget = _isLoadingUserData
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusButton(),
              _buildReviewsList(),
            ],
          );

    final screenshotsList = (widget.gameData['screenshots'] ?? _enrichedData['screenshots'] ?? []) as List;
    final artworksList = (widget.gameData['artworks'] ?? _enrichedData['artworks'] ?? []) as List;
    final videosList = (widget.gameData['videos'] ?? _enrichedData['videos'] ?? []) as List;
    final bool hasMedia = screenshotsList.isNotEmpty || artworksList.isNotEmpty || videosList.isNotEmpty;

    Widget _buildInfoTab() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            children: platformsList.map((p) {
              final style = _getPlatformStyle(p.toString());
              return Chip(
                avatar: style['icon'] != null ? Image.asset(style['icon'], height: 20, fit: BoxFit.contain) : null,
                label: Text(p.toString(), style: TextStyle(color: style['textColor'], fontWeight: FontWeight.bold)),
                backgroundColor: style['color'],
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],

        if (summary != null) ...[
          const Text('Sinopsis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(summary, style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
        ],
      );
    }

    Widget _buildMediaTab() {
      List<Map<String, dynamic>> availableTabs = [];
      if (screenshotsList.isNotEmpty) availableTabs.add({'id': 0, 'label': 'Capturas', 'icon': Icons.screenshot_monitor});
      if (videosList.isNotEmpty) availableTabs.add({'id': 1, 'label': 'Tráilers', 'icon': Icons.video_library});
      if (artworksList.isNotEmpty) availableTabs.add({'id': 2, 'label': 'Artworks', 'icon': Icons.brush});

      if (availableTabs.isEmpty) return const SizedBox.shrink();

      int activeTabId = availableTabs.any((t) => t['id'] == _selectedMediaTabIndex) 
          ? _selectedMediaTabIndex 
          : availableTabs.first['id'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availableTabs.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableTabs.map((tab) {
                  final isSelected = tab['id'] == activeTabId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tab['label']),
                      showCheckmark: false,
                      avatar: Icon(tab['icon'], size: 18, color: isSelected ? Colors.white : Colors.grey),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedMediaTabIndex = tab['id']);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (activeTabId == 0) // Capturas
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 16/9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: screenshotsList.length,
              itemBuilder: (context, index) {
                final url = IGDBService.getScreenshotUrl(screenshotsList[index].toString());
                return InkWell(
                  onTap: () => _showImageFullScreen(url),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          if (activeTabId == 1) // Tráilers
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 16/9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: videosList.length,
              itemBuilder: (context, index) {
                final videoId = videosList[index].toString();
                final thumbUrl = IGDBService.getVideoThumbnailUrl(videoId);
                final videoUrl = IGDBService.getVideoUrl(videoId);
                return InkWell(
                  onTap: () => launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(thumbUrl, fit: BoxFit.cover),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (activeTabId == 2) // Artworks
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200, // Artworks pueden ser verticales a veces, pero asumo cuadrícula igual
                childAspectRatio: 1, // Cuadrado o 16/9, probemos cuadrado
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: artworksList.length,
              itemBuilder: (context, index) {
                final url = IGDBService.getArtworkUrl(artworksList[index].toString());
                return InkWell(
                  onTap: () => _showImageFullScreen(url),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                );
              },
            ),
        ],
      );
    }

    Widget _buildTabButton(int index, String title) {
      final isSelected = _selectedMainTabIndex == index;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedMainTabIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: SelectionContainer.disabled(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[400],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget tabsAndContentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasMedia)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                _buildTabButton(0, 'Información'),
                _buildTabButton(1, 'Media'),
              ],
            ),
          ),
        _selectedMainTabIndex == 0 ? _buildInfoTab() : _buildMediaTab(),
      ],
    );

    Widget buildFadeInImage(String url) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    }

    return SelectionArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            centerTitle: false, 
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: highResCoverUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_selectedScreenshotUrl != null)
                          buildFadeInImage(_selectedScreenshotUrl!)
                        else if (!_isEnriching)
                          buildFadeInImage(highResCoverUrl)
                        else
                          Container(color: Theme.of(context).primaryColorDark),
                          
                        BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(color: Colors.black.withOpacity(0.2)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter, 
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(context).scaffoldBackgroundColor, 
                                Colors.transparent, 
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Theme.of(context).primaryColorDark),
            ),
          ),
          
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 800;

                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              coverArtWidget,
                              const SizedBox(height: 24),
                              interactiveWidget,
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerInfoWidget,
                              const SizedBox(height: 32),
                              tabsAndContentWidget,
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 120, child: coverArtWidget),
                            const SizedBox(width: 16),
                            Expanded(child: headerInfoWidget),
                          ],
                        ),
                        const SizedBox(height: 24),
                        interactiveWidget,
                        const SizedBox(height: 32),
                        tabsAndContentWidget,
                        const SizedBox(height: 60),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    ));
  }
}
