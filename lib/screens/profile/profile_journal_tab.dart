import 'package:flutter/material.dart';
import '../library/game_details_screen.dart';
import '../activity/review_details_screen.dart';

/// Pestaña "Diario" del perfil: timeline cronológico de las reseñas del
/// usuario, agrupadas por mes, inspirado en el Journal de Letterboxd /
/// Backloggd pero con la estética propia de Corpus.
///
/// Recibe las reseñas ya cargadas por [ProfileScreen] (no hace queries
/// propias) para no duplicar la carga de datos que ya hace
/// `_fetchProfileData()`.
///
/// Uso:
/// ```dart
/// ProfileJournalTab(
///   reviews: _userReviews,
///   userData: _userProfile,
///   onReturn: _fetchProfileData,
/// )
/// ```
class ProfileJournalTab extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;
  final Map<String, dynamic>? userData;
  final VoidCallback? onReturn;

  const ProfileJournalTab({
    super.key,
    required this.reviews,
    required this.userData,
    this.onReturn,
  });

  @override
  State<ProfileJournalTab> createState() => _ProfileJournalTabState();
}

class _ProfileJournalTabState extends State<ProfileJournalTab> {
  int? _selectedYear;

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Fecha que representa la entrada en el diario: preferimos la fecha en
  /// la que se terminó/dejó de jugar, si no la de inicio, y si no hay
  /// ninguna, cuándo se creó la reseña.
  DateTime? _effectiveDate(Map<String, dynamic> review) {
    final raw =
        review['played_until'] ?? review['played_from'] ?? review['created_at'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  List<int> _availableYears(List<Map<String, dynamic>> entries) {
    final years = entries
        .map((r) => _effectiveDate(r)?.year)
        .whereType<int>()
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  /// Agrupa por "año-mes" preservando el orden (más reciente primero).
  Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> entries,
  ) {
    final dated = entries.where((r) => _effectiveDate(r) != null).toList()
      ..sort((a, b) => _effectiveDate(b)!.compareTo(_effectiveDate(a)!));

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final r in dated) {
      final d = _effectiveDate(r)!;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(r);
    }
    return grouped;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'beaten':
        return 'Terminado';
      case 'playing':
        return 'Jugando';
      case 'wishlist':
        return 'Quiero';
      case 'abandoned':
        return 'Abandonado';
      case 'on_hold':
        return 'En Pausa';
      default:
        return 'Desconocido';
    }
  }

  String _platformLabel(String? platform) {
    if (platform == null || platform.isEmpty) return '';
    return platform[0].toUpperCase() + platform.substring(1);
  }

  Widget _buildStarRow(double rating10) {
    // Convertimos la nota de 1-10 a 5 estrellas (con medias).
    final rating5 = rating10 / 2;
    final stars = <Widget>[];
    for (int i = 1; i <= 5; i++) {
      IconData icon;
      if (rating5 >= i) {
        icon = Icons.star;
      } else if (rating5 >= i - 0.5) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  void _openReview(Map<String, dynamic> review) {
    final gameData = review['games'];
    if (gameData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewDetailsScreen(
          gameData: gameData,
          userData: widget.userData,
          reviewData: review,
        ),
      ),
    ).then((_) => widget.onReturn?.call());
  }

  void _openGame(Map<String, dynamic> review) {
    final gameData = review['games'];
    if (gameData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailsScreen(gameData: gameData),
      ),
    ).then((_) => widget.onReturn?.call());
  }

  @override
  Widget build(BuildContext context) {
    final years = _availableYears(widget.reviews);

    final filteredReviews = _selectedYear == null
        ? widget.reviews
        : widget.reviews
              .where((r) => _effectiveDate(r)?.year == _selectedYear)
              .toList();

    final grouped = _groupByMonth(filteredReviews);

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Aún no hay nada en tu diario. En cuanto marques una fecha de\n'
            'juego en una reseña, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (years.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedYear,
                  hint: const Text('Año: Todos'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos los años'),
                    ),
                    ...years.map(
                      (y) => DropdownMenuItem<int?>(
                        value: y,
                        child: Text(y.toString()),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
              ),
            ),
          ),
        ...grouped.entries.map((entry) => _buildMonthGroup(entry.value)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMonthGroup(List<Map<String, dynamic>> entries) {
    final firstDate = _effectiveDate(entries.first)!;
    final monthLabel = '${_monthNames[firstDate.month - 1]}, ${firstDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            monthLabel,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
        ),
        ...entries.map(_buildJournalRow),
      ],
    );
  }

  Widget _buildJournalRow(Map<String, dynamic> review) {
    final gameData = review['games'] as Map<String, dynamic>?;
    if (gameData == null) return const SizedBox.shrink();

    final title = gameData['title'] ?? 'Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';
    final date = _effectiveDate(review)!;
    final rating = (review['rating'] ?? 0).toDouble();
    final status = review['status'] ?? 'beaten';
    final platform = review['platform'] as String?;
    final isReplay = review['is_replay'] == true;

    return InkWell(
      onTap: () => _openReview(review),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Día
            SizedBox(
              width: 28,
              child: Text(
                date.day.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            // Portada
            GestureDetector(
              onTap: () => _openGame(review),
              child: Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).primaryColorDark,
                  image: coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: coverUrl.isEmpty
                    ? Icon(
                        Icons.videogame_asset,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Título + rating
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isReplay) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.replay,
                          size: 14,
                          color: Colors.orangeAccent.shade200,
                        ),
                      ],
                    ],
                  ),
                  if (rating > 0) ...[
                    const SizedBox(height: 2),
                    _buildStarRow(rating),
                  ],
                ],
              ),
            ),
            // Plataforma + estado (se oculta en pantallas estrechas)
            if (MediaQuery.of(context).size.width > 600) ...[
              SizedBox(
                width: 120,
                child: Text(
                  _platformLabel(platform),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
