import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile/edit_profile_screen.dart';
import 'info_screen.dart';
import 'appearance_screen.dart';

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
}
