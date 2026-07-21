import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile/edit_profile_screen.dart';
import 'info_screen.dart';
import '../globals.dart';

class SettingsScreen extends StatelessWidget {
  final Map<String, dynamic> userProfile;

  const SettingsScreen({super.key, required this.userProfile});

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
                  builder: (context) => EditProfileScreen(userProfile: userProfile),
                ),
              );
            },
          ),
            _buildSettingsTile(
              context: context,
              icon: Icons.palette,
              title: 'Apariencia',
              subtitle: 'Tema oscuro, claro o sistema',
              onTap: () {
                _showThemePicker(context);
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
          
          Divider(color: Colors.white24, height: 32),
          
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Cerrar sesión', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context); // Cierra los ajustes
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

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Apariencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('Sistema'),
                trailing: themeNotifier.currentMode == ThemeMode.system ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  themeNotifier.setTheme(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Claro'),
                trailing: themeNotifier.currentMode == ThemeMode.light ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  themeNotifier.setTheme(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Oscuro'),
                trailing: themeNotifier.currentMode == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  themeNotifier.setTheme(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
