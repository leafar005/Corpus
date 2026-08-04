import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import '../../services/notification_service.dart';

/// Pantalla de ajustes de notificaciones.
/// Lee y escribe las preferencias del usuario en `notification_preferences` de Supabase.
/// Cada tipo de notificación tiene su propio switch individual.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  // Preferencias — valores por defecto son todos true
  bool _friendStartedPlaying = true;
  bool _friendFinishedGame = true;
  bool _friendWishlistedGame = true;
  bool _newBundle = true;
  bool _bundleExpiring = true;
  bool _commentOnReview = true;
  bool _replyToComment = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _friendStartedPlaying = data['friend_started_playing'] ?? true;
          _friendFinishedGame = data['friend_finished_game'] ?? true;
          _friendWishlistedGame = data['friend_wishlisted_game'] ?? true;
          _newBundle = data['new_bundle'] ?? true;
          _bundleExpiring = data['bundle_expiring'] ?? true;
          _commentOnReview = data['comment_on_review'] ?? true;
          _replyToComment = data['reply_to_comment'] ?? true;
        });
      }
      // Si no hay fila, usamos los valores por defecto (todos true) — se creará al primer save
    } catch (e) {
      debugPrint('[NotificationsScreen] Error cargando preferencias: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('notification_preferences').upsert({
        'user_id': userId,
        'friend_started_playing': _friendStartedPlaying,
        'friend_finished_game': _friendFinishedGame,
        'friend_wishlisted_game': _friendWishlistedGame,
        'new_bundle': _newBundle,
        'bundle_expiring': _bundleExpiring,
        'comment_on_review': _commentOnReview,
        'reply_to_comment': _replyToComment,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando preferencias: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Cambia el switch y guarda inmediatamente
  Future<void> _toggle(String field, bool value) async {
    setState(() {
      switch (field) {
        case 'friend_started_playing':
          _friendStartedPlaying = value;
          break;
        case 'friend_finished_game':
          _friendFinishedGame = value;
          break;
        case 'friend_wishlisted_game':
          _friendWishlistedGame = value;
          break;
        case 'new_bundle':
          _newBundle = value;
          break;
        case 'bundle_expiring':
          _bundleExpiring = value;
          break;
        case 'comment_on_review':
          _commentOnReview = value;
          break;
        case 'reply_to_comment':
          _replyToComment = value;
          break;
      }
    });
    await _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(top: 16.0, bottom: getBottomSpacer(context), left: 16.0, right: 16.0),
              children: [
                // ── Amigos ────────────────────────────────────────────────
                _buildSectionHeader('Amigos'),
                _buildNotifTile(
                  icon: Icons.sports_esports_outlined,
                  iconColor: colorScheme.primary,
                  title: 'Amigo empieza a jugar',
                  subtitle: 'Cuando un amigo inicia un juego nuevo.',
                  value: _friendStartedPlaying,
                  onChanged: (v) => _toggle('friend_started_playing', v),
                ),
                _buildNotifTile(
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.amber,
                  title: 'Amigo termina un juego',
                  subtitle: 'Cuando un amigo marca un juego como completado.',
                  value: _friendFinishedGame,
                  onChanged: (v) => _toggle('friend_finished_game', v),
                ),
                _buildNotifTile(
                  icon: Icons.bookmark_add_outlined,
                  iconColor: Colors.deepPurpleAccent,
                  title: 'Amigo añade a wishlist',
                  subtitle: 'Cuando un amigo quiere jugar a un juego.',
                  value: _friendWishlistedGame,
                  onChanged: (v) => _toggle('friend_wishlisted_game', v),
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),

                // ── Bundles ───────────────────────────────────────────────
                _buildSectionHeader('Bundles'),
                _buildNotifTile(
                  icon: Icons.redeem_outlined,
                  iconColor: Colors.green,
                  title: 'Bundle nuevo disponible',
                  subtitle:
                      'Cuando aparece un nuevo bundle en Humble o Fanatical.',
                  value: _newBundle,
                  onChanged: (v) => _toggle('new_bundle', v),
                ),
                _buildNotifTile(
                  icon: Icons.timer_outlined,
                  iconColor: Colors.orange,
                  title: 'Bundle a punto de caducar',
                  subtitle: 'Aviso 24h antes de que un bundle expire.',
                  value: _bundleExpiring,
                  onChanged: (v) => _toggle('bundle_expiring', v),
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),

                // ── Social ────────────────────────────────────────────────
                _buildSectionHeader('Social'),
                _buildNotifTile(
                  icon: Icons.comment_outlined,
                  iconColor: colorScheme.secondary,
                  title: 'Comentario en tu reseña',
                  subtitle: 'Cuando alguien comenta en una de tus reseñas.',
                  value: _commentOnReview,
                  onChanged: (v) => _toggle('comment_on_review', v),
                ),
                _buildNotifTile(
                  icon: Icons.reply_outlined,
                  iconColor: colorScheme.tertiary,
                  title: 'Respuesta a tu comentario',
                  subtitle:
                      'Cuando alguien te menciona con @tu_usuario en un comentario.',
                  value: _replyToComment,
                  onChanged: (v) => _toggle('reply_to_comment', v),
                ),

                const SizedBox(height: 24),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // ── Prueba ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationService().sendTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notificación de prueba enviada.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Enviar notificación de prueba'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Nota informativa sobre la plataforma
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Las notificaciones de amigos y comentarios se envían incluso con la app cerrada en Android. En Windows, solo funcionan con la app abierta.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildNotifTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      onChanged: onChanged,
    );
  }
}
