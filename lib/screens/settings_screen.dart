import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_section_title.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import '../services/notification_service.dart';
import '../services/user_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>?> hallOfFame;

  const SettingsScreen({
    super.key,
    required this.userProfile,
    required this.hallOfFame,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<SharedPreferences> _prefsFuture;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
  }

  Future<void> _handleDebugClearAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: const Text('¿Vaciar cuenta por completo?'),
        content: const Text(
          'Esto borrará TODOS tus juegos y reseñas de la base de datos. Es una acción irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('VACIAR CUENTA'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay sesión activa.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var loadingDialogOpen = true;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: 'loading_dialog'),
      builder: (context) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() {
      loadingDialogOpen = false;
    });

    Object? deleteError;
    try {
      Future<void> batchDelete(String table) async {
        while (true) {
          final response = await supabase
              .from(table)
              .select('id')
              .eq('user_id', userId)
              .limit(50);
          if (response.isEmpty) break;

          final ids = (response as List).map((e) => e['id']).toList();
          await supabase.from(table).delete().inFilter('id', ids);
        }
      }

      // Eliminar en lotes para evitar statement timeout por los triggers de XP
      await batchDelete('reviews');

      Future<void> batchDeleteUserGames() async {
        while (true) {
          final response = await supabase
              .from('user_games')
              .select('game_id')
              .eq('user_id', userId)
              .limit(50);
          if (response.isEmpty) break;

          final gameIds = (response as List).map((e) => e['game_id']).toList();
          await supabase
              .from('user_games')
              .delete()
              .eq('user_id', userId)
              .inFilter('game_id', gameIds);
        }
      }

      await batchDeleteUserGames();
      libraryUpdateNotifier.value++; // Refrescar biblioteca
    } catch (e) {
      deleteError = e;
    } finally {
      if (loadingDialogOpen &&
          rootNavigator.mounted &&
          rootNavigator.canPop()) {
        loadingDialogOpen = false;
        rootNavigator.pop(); // Cerrar spinner
      }
    }

    if (!mounted) return;
    if (deleteError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al vaciar: $deleteError'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta vaciada limpiamente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const CorpusScreenTitle('Ajustes'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8,
          left: 16,
          right: 16,
          bottom: getBottomSpacer(context),
        ),
        children: [
          _buildSettingsTile(
            context: context,
            leading: const CorpusTablerIcon.userFilled(size: 20),
            title: 'Cuenta',
            subtitle: 'Editar perfil, nombre de usuario',
            onTap: () {
              context.pushEditProfile(widget.userProfile, widget.hallOfFame);
            },
          ),
          _buildSettingsTile(
            context: context,
            leading: const CorpusTablerIcon.palette(size: 20),
            title: 'Apariencia',
            subtitle: 'Modo, color principal',
            onTap: () {
              context.pushAppearance().then((_) {
                libraryUpdateNotifier.value++;
              });
            },
          ),
          _buildSettingsTile(
            context: context,
            leading: const CorpusTablerIcon.bell(size: 20),
            title: 'Notificaciones',
            subtitle: 'Avisos, interacciones',
            onTap: () {
              context.pushNotifications();
            },
          ),
          _buildSettingsTile(
            context: context,
            leading: const CorpusTablerIcon.plug(size: 20),
            title: 'Integraciones',
            subtitle: 'Vincular Steam, importar Stash',
            trailing: const CorpusTablerIcon.chevronRight(size: 20),
            onTap: () {
              context.pushIntegrations();
            },
          ),
          _buildSettingsTile(
            context: context,
            leading: const CorpusTablerIcon.info(size: 20),
            title: 'Información',
            subtitle: 'Acerca de Corpus',
            onTap: () {
              context.pushInfo();
            },
          ),

          Divider(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.24),
            height: 32,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Preferencias',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FutureBuilder<SharedPreferences>(
            future: _prefsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Cargando preferencias...'),
                );
              }
              final prefs = snapshot.data!;
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  final localizeLinks = prefs.getBool('localize_links') ?? true;
                  final duracionDeEnabled =
                      (prefs.getString('time_source_pref') ?? 'igdb') ==
                      'duracionde';
                  return Column(
                    children: [
                      SwitchListTile(
                        secondary: const CorpusTablerIcon.language(size: 20),
                        title: const Text('Traducir enlaces de tiendas'),
                        subtitle: const Text(
                          'Convierte los enlaces de tiendas a euros y español.',
                        ),
                        value: localizeLinks,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool value) {
                          prefs.setBool('localize_links', value);
                          UserSettingsService().push({'localize_links': value});
                          setLocalState(() {});
                        },
                      ),
                      SwitchListTile(
                        secondary: const CorpusTablerIcon.timer(size: 20),
                        title: const Text('DuracionDe (experimental)'),
                        subtitle: const Text(
                          'Obtener tiempos de duración en español desde duracionde.com (con fallback a IGDB).',
                        ),
                        value: duracionDeEnabled,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool value) {
                          final prefValue = value ? 'duracionde' : 'igdb';
                          prefs.setString('time_source_pref', prefValue);
                          UserSettingsService().push({
                            'time_source_pref': prefValue,
                          });
                          setLocalState(() {});
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),

          if (kDebugMode) ...[
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
              height: 32,
            ),

            ListTile(
              leading: const CorpusTablerIcon.trashX(
                size: 20,
                color: Colors.orange,
              ),
              title: const Text(
                'DEBUG: Vaciar cuenta',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleDebugClearAccount,
            ),

            ListTile(
              leading: const CorpusTablerIcon.broom(
                size: 20,
                color: Colors.orange,
              ),
              title: const Text(
                'DEBUG: Limpiar caché de Bundles',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                try {
                  final prefs = await _prefsFuture;
                  await prefs.remove('bundles_full_cache');
                  await prefs.remove('bundles_full_cache_time');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Caché de bundles eliminada.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al limpiar caché: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],

          Divider(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.24),
            height: 32,
          ),
          ListTile(
            leading: CorpusTablerIcon.logout(
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.pop(context); // Cierra los ajustes
              final prefs = await _prefsFuture;
              await prefs.setInt('main_tab_index', 0);
              await NotificationService().deleteFcmToken();
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: ext.radiusMedium,
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: ext.radiusMedium,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: leading,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: const TextStyle()),
          trailing: trailing ?? const CorpusTablerIcon.chevronRight(size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}
