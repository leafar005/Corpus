import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../library/game_details_screen.dart';

class CurrentlyPlayingBadge extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> initialProfile;

  /// Versión más baja para el header sticky de móvil.
  final bool compact;

  /// Cuando se usa inline (al lado del @) elimina el margin top.
  final bool inline;

  const CurrentlyPlayingBadge({
    super.key,
    required this.userId,
    required this.initialProfile,
    this.compact = false,
    this.inline = false,
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
          },
        )
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
              builder: (context) => GameDetailsScreen(gameData: res),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: widget.inline ? 0 : (widget.compact ? 2 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset,
              size: widget.compact ? 14 : 18,
              color: Colors.greenAccent[400],
            ),
            SizedBox(width: widget.compact ? 4 : 6),
            Flexible(
              child: Text(
                'Jugando: ${_appName ?? 'Juego de Steam'}',
                style: TextStyle(
                  color: Colors.greenAccent[400],
                  fontWeight: FontWeight.bold,
                  fontSize: widget.compact ? 12 : 14,
                  height: 1.1,
                  shadows: widget.compact
                      ? null
                      : const [
                          Shadow(
                            offset: Offset(-1, -1),
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                          Shadow(
                            offset: Offset(1, -1),
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                          Shadow(
                            offset: Offset(1, 1),
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                          Shadow(
                            offset: Offset(-1, 1),
                            color: Colors.black,
                            blurRadius: 2,
                          ),
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
