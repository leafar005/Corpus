import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'profile/edit_profile_screen.dart';
import 'info_screen.dart';
import 'appearance_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/import_service.dart';
import 'settings/import_preview_screen.dart';

class SettingsScreen extends StatelessWidget {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>?> hallOfFame;

  const SettingsScreen({super.key, required this.userProfile, required this.hallOfFame});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.person,
            title: 'Cuenta',
            subtitle: 'Editar perfil, nombre de usuario',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(userProfile: userProfile, hallOfFame: hallOfFame),
                ),
              );
            },
          ),
            _buildSettingsTile(
              context: context,
              icon: Icons.palette,
              title: 'Apariencia',
              subtitle: 'Modo, color principal',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppearanceScreen()),
                );
              },
            ),
          _buildSettingsTile(
            context: context,
            icon: Icons.notifications,
            title: 'Notificaciones',
            subtitle: 'Avisos, interacciones',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente...')),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.file_upload_outlined,
            title: 'Importar Biblioteca',
            subtitle: 'Migrar desde CSV',
            onTap: () async {
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom, 
                  allowedExtensions: ['csv'],
                  withData: true,
                );
                
                if (result != null && result.files.single.bytes != null) {
                  bool isCancelled = false;
                  ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
                  ValueNotifier<String> statusNotifier = ValueNotifier("Preparando datos...");

                  // Show matching dialog
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Procesando juegos'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: progressNotifier,
                                builder: (context, progress, child) {
                                  return Column(
                                    children: [
                                      LinearProgressIndicator(
                                        value: progress > 0 ? progress : null, // Indeterminate until progress starts
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      const SizedBox(height: 16),
                                      Text('${(progress * 100).toStringAsFixed(1)}% completado', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  );
                                }
                              ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<String>(
                                valueListenable: statusNotifier,
                                builder: (context, status, child) => Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                isCancelled = true;
                                Navigator.pop(context);
                              },
                              child: const Text('Cancelar'),
                            ),
                          ],
                        );
                      }
                    );
                  }

                  final rows = ImportService.parseCsv(result.files.single.bytes!);
                  
                  await ImportService.matchGamesWithIGDB(
                    rows, 
                    (p, t) {
                      if (t > 0) {
                        progressNotifier.value = p / t;
                        statusNotifier.value = "Buscando coincidencias ($p de $t)...";
                      }
                    }, 
                    isCancelled: () => isCancelled,
                  );

                  // Pop matching dialog if it hasn't been popped by Cancel
                  if (!isCancelled && context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  
                  if (!isCancelled && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ImportPreviewScreen(rows: rows)),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // close loader if it was open
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.info_outline,
            title: 'Información',
            subtitle: 'Acerca de Corpus',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoScreen(),
                ),
              );
            },
          ),
          
          const Divider(color: Colors.white24, height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Preferencias', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Cargando preferencias...'),
                );
              }
              final prefs = snapshot.data!;
              return StatefulBuilder(
                builder: (context, setState) {
                  final localizeLinks = prefs.getBool('localize_links') ?? true;
                  return SwitchListTile(
                    secondary: const Icon(Icons.language),
                    title: const Text('Traducir enlaces de tiendas'),
                    subtitle: const Text('Convierte los enlaces de tiendas a euros y español.'),
                    value: localizeLinks,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (bool value) {
                      prefs.setBool('localize_links', value);
                      setState(() {});
                    },
                  );
                },
              );
            },
          ),
          
          const Divider(color: Colors.white24, height: 32),
          
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.orange),
            title: const Text('DEBUG: Vaciar cuenta', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: const Text('¿Vaciar cuenta por completo?'),
                  content: const Text('Esto borrará TODOS tus juegos y reseñas de la base de datos. Es una acción irreversible.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false), 
                      child: const Text('Cancelar')
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('VACIAR CUENTA'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  // Eliminar primero las reseñas por dependencia de FK
                  await Supabase.instance.client.from('reviews').delete().eq('user_id', userId);
                  // Luego los juegos de la biblioteca
                  await Supabase.instance.client.from('user_games').delete().eq('user_id', userId);
                  
                  libraryUpdateNotifier.value++; // Refrescar biblioteca

                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // Cerrar spinner
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cuenta vaciada limpiamente.'), backgroundColor: Colors.orange)
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // Cerrar spinner
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al vaciar: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              }
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('DEBUG: Limpiar caché de Bundles', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            onTap: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('bundles_full_cache');
                await prefs.remove('bundles_full_cache_time');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caché de bundles eliminada.'), backgroundColor: Colors.orange)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al limpiar caché: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
          ),

          const Divider(color: Colors.white24, height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Cerrar sesión', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context); // Cierra los ajustes
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('main_tab_index', 0);
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle()),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
