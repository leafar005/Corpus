import 'dart:async';
import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import 'package:corpus/routes/corpus_router.dart';

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
  static int _nextChannelId = 0;

  RealtimeChannel? _subscription;
  int? _appId;
  String? _appName;

  SupabaseClient? _supabaseOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _syncFromInitialProfile() {
    _appId = (widget.initialProfile['currently_playing_appid'] as num?)?.toInt();
    _appName = widget.initialProfile['currently_playing_name']?.toString();
  }

  void _unsubscribe() {
    final channel = _subscription;
    _subscription = null;
    final client = _supabaseOrNull();
    if (channel != null && client != null) {
      try {
        unawaited(
          client
              .removeChannel(channel)
              .then<void>(
                (_) {},
                onError: (Object e) {
                  debugPrint(
                    '[CurrentlyPlayingBadge] Error removing channel: $e',
                  );
                },
              ),
        );
      } catch (e) {
        debugPrint('[CurrentlyPlayingBadge] Error removing channel: $e');
      }
    }
  }

  void _subscribe() {
    _unsubscribe();
    if (widget.userId.isEmpty) return;
    final client = _supabaseOrNull();
    if (client == null) return;

    final channelName = 'public:users:${widget.userId}:${_nextChannelId++}';
    _subscription = client
        .channel(channelName)
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
                _appId = (payload.newRecord['currently_playing_appid'] as num?)
                    ?.toInt();
                _appName = payload.newRecord['currently_playing_name']
                    ?.toString();
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void initState() {
    super.initState();
    _syncFromInitialProfile();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant CurrentlyPlayingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProfile != widget.initialProfile) {
      _syncFromInitialProfile();
    }
    if (oldWidget.userId != widget.userId) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appId = _appId;
    if (appId == null) return const SizedBox.shrink();

    // Pulse animation logic could go here, or we just keep it simple with colors
    return GestureDetector(
      onTap: () async {
        final client = _supabaseOrNull();
        if (client == null) return;
        try {
          // Find if we have the game in our db
          final res = await client
              .from('games')
              .select('igdb_id, steam_app_id, title')
              .eq('steam_app_id', appId)
              .maybeSingle();

          if (res != null && context.mounted) {
            context.pushGameDetails(Game.fromMap(res));
          }
        } catch (e) {
          debugPrint('[CurrentlyPlayingBadge] Error opening game details: $e');
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: widget.inline ? 0 : (widget.compact ? 2 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CorpusTablerIcon(CorpusIconKind.VideogameAsset,
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
