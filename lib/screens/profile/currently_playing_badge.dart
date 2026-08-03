import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../library/game_details_screen.dart';

class CurrentlyPlayingBadge extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> initialProfile;

  const CurrentlyPlayingBadge({
    super.key,
    required this.userId,
    required this.initialProfile,
  });

  @override
  State<CurrentlyPlayingBadge> createState() => _CurrentlyPlayingBadgeState();
}

class _CurrentlyPlayingBadgeState extends State<CurrentlyPlayingBadge> {
  RealtimeChannel? _subscription;
  int? _appId;
  String? _appName;

  @override
  void initState() {
    super.initState();
    _appId = widget.initialProfile['currently_playing_appid'];
    _appName = widget.initialProfile['currently_playing_name'];

    _subscription = Supabase.instance.client
        .channel('public:users:${widget.userId}')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.userId,
            ),
            callback: (payload) {
              if (mounted) {
                setState(() {
                  _appId = payload.newRecord['currently_playing_appid'];
                  _appName = payload.newRecord['currently_playing_name'];
                });
              }
            })
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appId == null) return const SizedBox.shrink();

    // Pulse animation logic could go here, or we just keep it simple with colors
    return GestureDetector(
      onTap: () async {
        // Find if we have the game in our db
        final res = await Supabase.instance.client
            .from('games')
            .select('igdb_id, steam_app_id, title')
            .eq('steam_app_id', _appId!)
            .maybeSingle();
            
        if (res != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailsScreen(
                gameData: res,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videogame_asset, size: 18, color: Colors.greenAccent[400]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Jugando: ${_appName ?? 'Juego de Steam'}',
                style: TextStyle(
                  color: Colors.greenAccent[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: const [
                    Shadow(offset: Offset(-1, -1), color: Colors.black, blurRadius: 2),
                    Shadow(offset: Offset(1, -1), color: Colors.black, blurRadius: 2),
                    Shadow(offset: Offset(1, 1), color: Colors.black, blurRadius: 2),
                    Shadow(offset: Offset(-1, 1), color: Colors.black, blurRadius: 2),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
