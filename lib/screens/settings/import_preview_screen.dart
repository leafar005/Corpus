import 'package:flutter/material.dart';
import 'package:corpus/services/import_service.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/screens/library/review_modal.dart';

class ImportPreviewScreen extends StatefulWidget {
  final List<CsvGameRow> rows;

  const ImportPreviewScreen({super.key, required this.rows});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _statusFilter = 'todos';

  bool _matchesFilters(CsvGameRow r) {
    if (_statusFilter != 'todos' && r.status.toLowerCase() != _statusFilter) {
      return false;
    }
    if (_searchQuery.isNotEmpty) {
      final name = r.igdbData?['name']?.toString().toLowerCase() ?? r.title.toLowerCase();
      if (!name.contains(_searchQuery.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  List<CsvGameRow> get allMatchedRows => widget.rows
      .where((r) => r.matchStatus == 'matched' && r.igdbData != null)
      .toList();
      
  List<CsvGameRow> get matchedRows => allMatchedRows
      .where(_matchesFilters)
      .toList();
      
  List<CsvGameRow> get ambiguousRows =>
      widget.rows.where((r) => r.matchStatus == 'ambiguous' && _matchesFilters(r)).toList();
      
  List<CsvGameRow> get notFoundRows =>
      widget.rows.where((r) => r.matchStatus == 'notFound' && _matchesFilters(r)).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _importData() async {
    final readyRows = allMatchedRows;
    if (readyRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay juegos listos para importar.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ImportService.saveImportedGames(
        readyRows,
        onProgress: (current, total) {
          debugPrint('Guardados $current de $total juegos en la nube...');
        },
      );

      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Destruye el spinner de carga siempre
        libraryUpdateNotifier.value++; // Refresca biblioteca y feed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Importación completada con éxito! (${readyRows.length} juegos)',
            ),
          ),
        );
        Navigator.pop(context); // Cierra la pantalla de revisión
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Destruye el spinner en caso de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en base de datos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTabs = ambiguousRows.isNotEmpty || notFoundRows.isNotEmpty;
    final totalMatched = allMatchedRows.length;
    final isSteamImport = widget.rows.any((r) => r.steamOwned);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Importación'),
        bottom: hasTabs
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Listos ($totalMatched)'),
                  Tab(text: 'Dudas (${ambiguousRows.length})'),
                  Tab(text: 'No encontrados (${notFoundRows.length})'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar juego...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                if (!isSteamImport) const SizedBox(width: 8),
                if (!isSteamImport)
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      // ignore: deprecated_member_use
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'playing', child: Text('Jugando')),
                        DropdownMenuItem(value: 'beaten', child: Text('Completado')),
                        DropdownMenuItem(value: 'wishlist', child: Text('Pendiente')),
                        DropdownMenuItem(value: 'abandoned', child: Text('Abandonado')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _statusFilter = val;
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: hasTabs
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchedTab(matchedRows),
                      _buildAmbiguousTab(ambiguousRows),
                      _buildNotFoundTab(notFoundRows),
                    ],
                  )
                : _buildMatchedTab(matchedRows),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: totalMatched == 0 ? null : _importData,
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  'Importar $totalMatched juegos a mi biblioteca',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedTab(List<CsvGameRow> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No hay juegos emparejados.'));
    }
    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = rows[index];
        final game = row.igdbData!;
        final coverId = (game['cover'] is Map)
            ? game['cover']['image_id']
            : null;
        String coverUrl =
            game['cover_url'] ?? IGDBService.getCoverUrl(coverId as String?);
        if (coverUrl.isNotEmpty) {
          coverUrl = coverUrl
              .replaceAll('t_cover_big', 't_1080p')
              .replaceAll('t_thumb', 't_1080p');
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            onTap: () => _editRow(row),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      width: 45,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(width: 45, height: 60, color: Colors.grey),
            ),
            title: Text(
              game['name'] ?? row.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Estado: ${row.status.toUpperCase()} ${row.rating != null ? "• Nota: ${row.rating!.toStringAsFixed(1).replaceAll(RegExp(r'\\.0\$'), '')}" : ""}',
            ),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  Widget _buildAmbiguousTab(List<CsvGameRow> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No hay juegos ambiguos. ¡Perfecto!'));
    }
    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV: "${row.title}"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona la opción correcta de IGDB:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: row.candidates.length,
                    itemBuilder: (context, cIdx) {
                      final cand = row.candidates[cIdx] as Map<String, dynamic>;
                      final coverId = (cand['cover'] is Map)
                          ? cand['cover']['image_id']
                          : null;
                      String coverUrl =
                          cand['cover_url'] ??
                          IGDBService.getCoverUrl(coverId as String?);
                      if (coverUrl.isNotEmpty) {
                        coverUrl = coverUrl
                            .replaceAll('t_cover_big', 't_1080p')
                            .replaceAll('t_thumb', 't_1080p');
                      }
                      int? year;
                      if (cand['first_release_date'] != null) {
                        year = DateTime.fromMillisecondsSinceEpoch(
                          (cand['first_release_date'] as int) * 1000,
                        ).year;
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            row.igdbData = cand;
                            row.matchStatus = 'matched';
                          });
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: coverUrl.isNotEmpty
                                      ? Image.network(
                                          coverUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Container(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${cand["name"] ?? ""} ${year != null ? "($year)" : ""}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotFoundTab(List<CsvGameRow> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('Se encontraron todos los juegos.'));
    }
    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.redAccent),
            title: Text(
              row.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('No se encontró coincidencia en Twitch/IGDB.'),
          ),
        );
      },
    );
  }

  void _editRow(CsvGameRow row) {
    ReviewModal.show(
      context: context,
      gameData: row.igdbData ?? {},
      enrichedData: const {},
      isSaving: false,
      currentRating: row.rating ?? 0.0,
      currentRatingGameplay: 0.0,
      currentRatingNarrative: 0.0,
      currentRatingSoundtrack: 0.0,
      currentRatingVisuals: 0.0,
      currentStatus: row.status,
      commentController: TextEditingController(text: row.comment ?? ''),
      onSave: ({
        required rating,
        required ratingGameplay,
        required ratingNarrative,
        required ratingSoundtrack,
        required ratingVisuals,
        required comment,
        required status,
        required completionType,
        required isReplay,
        required replayNumber,
        required platform,
        required playTimeHours,
        required playedFrom,
        required playedUntil,
        required progressPercent,
        required newImages,
        required existingImages,
        required partnerId,
        reviewId,
      }) async {
        setState(() {
          row.rating = rating > 0 ? rating : null;
          row.comment = comment;
          row.status = status;
          row.completionType = completionType;
          row.platform = platform;
          row.playTimeHours = playTimeHours;
        });
        Navigator.pop(context);
      },
    );
  }
}
