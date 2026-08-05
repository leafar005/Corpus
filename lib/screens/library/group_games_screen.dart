import 'package:flutter/material.dart';
import '../../services/igdb_service.dart';
import '../../widgets/game_card.dart';
import '../../models/models.dart';

class GroupGamesScreen extends StatefulWidget {
  final String title;
  final int collectionId;
  final bool isFranchise;
  final bool isCompany;

  const GroupGamesScreen({
    super.key,
    required this.title,
    required this.collectionId,
    this.isFranchise = false,
    this.isCompany = false,
  });

  @override
  State<GroupGamesScreen> createState() => _GroupGamesScreenState();
}

class _GroupGamesScreenState extends State<GroupGamesScreen> {
  List<dynamic> _games = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = widget.isCompany
          ? await IGDBService.getAchievementGames(
              companyId: widget.collectionId,
              limit: 100,
            )
          : await IGDBService.getGamesByCollection(
              widget.collectionId,
              isFranchise: widget.isFranchise,
            );
      if (mounted) {
        setState(() {
          _games = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _games.isEmpty
          ? const Center(
              child: Text(
                'No se encontraron juegos para esta saga/franquicia.',
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _games.length,
              itemBuilder: (context, index) {
                return GameCard(
                  game: Game.fromMap(_games[index] as Map<String, dynamic>),
                  onReturn: () {},
                );
              },
            ),
    );
  }
}
