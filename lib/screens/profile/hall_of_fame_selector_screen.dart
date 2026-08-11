import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';

class HallOfFameSelectorScreen extends StatefulWidget {
  final int pinOrder;

  const HallOfFameSelectorScreen({super.key, required this.pinOrder});

  @override
  State<HallOfFameSelectorScreen> createState() =>
      _HallOfFameSelectorScreenState();
}

class _HallOfFameSelectorScreenState extends State<HallOfFameSelectorScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _beatenGames = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBeatenGames();
  }

  Future<void> _fetchBeatenGames() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final response = await Supabase.instance.client
        .from('user_games')
        .select('*, games(*)')
        .eq('user_id', userId)
        .eq('status', 'beaten')
        .order('updated_at', ascending: false);

    final gamesList = <Map<String, dynamic>>[];
    for (var row in response) {
      if (row['games'] != null) {
        gamesList.add(row['games']);
      }
    }

    if (mounted) {
      setState(() {
        _beatenGames = gamesList;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectGame(int gameId) async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await Supabase.instance.client.from('hall_of_fame').upsert({
        'user_id': userId,
        'game_id': gameId,
        'pin_order': widget.pinOrder,
      }, onConflict: 'user_id, pin_order');

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeGame() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await Supabase.instance.client
          .from('hall_of_fame')
          .delete()
          .eq('user_id', userId)
          .eq('pin_order', widget.pinOrder);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGames = _beatenGames.where((game) {
      final title = (game['title'] ?? game['name'] ?? '')
          .toString()
          .toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: CorpusScreenTitle('Pin #${widget.pinOrder}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Vaciar hueco',
            onPressed: _removeGame,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _beatenGames.isEmpty
          ? const Center(
              child: Text('No tienes juegos completados para destacar.'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar juego...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                if (filteredGames.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No se encontraron juegos con ese nombre.'),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: filteredGames.length,
                      itemBuilder: (context, index) {
                        final game = filteredGames[index];
                        final coverUrl =
                            game['cover_url']?.replaceAll(
                              't_cover_big',
                              't_1080p',
                            ) ??
                            '';

                        return GestureDetector(
                          onTap: () =>
                              _selectGame(game['igdb_id'] ?? game['id']),
                          child: ClipRRect(
                            borderRadius: Theme.of(
                              context,
                            ).extension<CorpusThemeExtension>()!.radiusSmall,
                            child: coverUrl.isNotEmpty
                                ? Image.network(coverUrl, fit: BoxFit.cover)
                                : Container(
                                    color: Theme.of(context).primaryColorDark,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
