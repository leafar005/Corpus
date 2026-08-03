import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/services/import_service.dart';
import 'import_preview_screen.dart';

class SteamImportProgressScreen extends StatefulWidget {
  final int minPlaytimeMinutes;

  const SteamImportProgressScreen({
    super.key,
    required this.minPlaytimeMinutes,
  });

  @override
  State<SteamImportProgressScreen> createState() =>
      _SteamImportProgressScreenState();
}

class _SteamImportProgressScreenState extends State<SteamImportProgressScreen> {
  RealtimeChannel? _subscription;

  String _status = 'Iniciando importación...';
  int _processedGames = 0;
  int _totalGames = 0;
  bool _isError = false;
  bool _isDone = false;
  final List<CsvGameRow> _accumulatedRows = [];

  @override
  void initState() {
    super.initState();
    _subscribeToProgress();
    _runImportLoop();
  }

  void _subscribeToProgress() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = Supabase.instance.client
        .channel('public:steam_import_jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'steam_import_jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _processedGames = newRecord['processed_games'] as int? ?? 0;
                  _totalGames = newRecord['total_games'] as int? ?? 0;
                  final status = newRecord['status'] as String?;
                  if (status == 'failed') {
                    _isError = true;
                    _status = newRecord['error_message'] == 'PRIVATE_PROFILE'
                        ? 'Tu perfil de Steam es privado. Haz pública tu biblioteca.'
                        : 'Error en la importación: ${newRecord['error_message']}';
                  } else if (status == 'completed') {
                    _isDone = true;
                    _status = '¡Importación completada!';
                  } else {
                    _status =
                        'Procesando $_processedGames de $_totalGames juegos...';
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _runImportLoop() async {
    bool done = false;
    while (!done && !_isError && mounted) {
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'steam-library-import',
          body: {'minPlaytimeMinutes': widget.minPlaytimeMinutes},
        );

        final data = res.data;
        if (data != null) {
          final catalogList = data['catalogGames'] as List<dynamic>? ?? [];
          final userList = data['userGames'] as List<dynamic>? ?? [];

          for (final ug in userList) {
            final gameId = ug['game_id'];
            final cg = catalogList.firstWhere(
              (c) => c['igdb_id'] == gameId,
              orElse: () => null,
            );
            if (cg != null) {
              _accumulatedRows.add(
                CsvGameRow(
                  title: cg['title']?.toString() ?? 'Desconocido',
                  igdbId: gameId,
                  status: 'beaten',
                  matchStatus: 'matched',
                  igdbData: cg,
                  steamOwned: true,
                  steamPlaytimeMinutes: ug['steam_playtime_minutes'] as int?,
                  isSteamOnly: (gameId as int? ?? 0) < 0,
                  steamLastPlayedAt: ug['steam_last_played_at']?.toString(),
                ),
              );
            }
          }

          if (data['done'] == true) {
            done = true;
            if (mounted) {
              setState(() {
                _isDone = true;
                _status = '¡Importación completada!';
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ImportPreviewScreen(rows: _accumulatedRows),
                ),
              );
            }
          } else {
            // done == false, we wait a bit and loop
            await Future.delayed(const Duration(seconds: 2));
          }
        } else {
          done = true;
          if (mounted)
            setState(() {
              _isError = true;
              _status = 'Respuesta vacía';
            });
        }
      } on FunctionException catch (e) {
        done = true;
        if (mounted) {
          setState(() {
            _isError = true;
            String msg = (e.details ?? e.toString()).toString();
            if (msg.contains('PRIVATE_PROFILE')) {
              _status =
                  'Tu perfil de Steam es privado. Por favor, haz pública tu biblioteca en Steam y vuelve a intentarlo.';
            } else {
              _status = 'Error en la Edge Function: $msg';
            }
          });
        }
      } catch (e) {
        done = true;
        if (mounted) {
          setState(() {
            _isError = true;
            _status = 'Error inesperado: $e';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalGames > 0
        ? (_processedGames / _totalGames).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso de Importación'),
        automaticallyImplyLeading:
            _isDone || _isError, // Solo permitir salir si acabó o falló
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isDone && !_isError)
                const CircularProgressIndicator()
              else if (_isDone)
                const Icon(Icons.check_circle, color: Colors.green, size: 64)
              else
                const Icon(Icons.error, color: Colors.red, size: 64),

              const SizedBox(height: 32),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),

              if (!_isError && !_isDone) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text('$_processedGames / $_totalGames'),
              ],

              if (_isDone || _isError) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
