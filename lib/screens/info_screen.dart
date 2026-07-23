import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir el enlace $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Información'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header del Proyecto
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColorDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.library_books, size: 60, ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Corpus',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Versión 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Tu biblioteca personal de videojuegos. Gestiona tus colecciones, descubre nuevos títulos y comparte reseñas con la comunidad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 40),

            // Sección Desarrollador
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DESARROLLO',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.person),
                ),
                title: const Text('leafar005', style: TextStyle(fontWeight: FontWeight.bold, )),
                subtitle: const Text('Creador y Desarrollador', style: TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
                onTap: () => _launchUrl('https://github.com/leafar005'),
              ),
            ),
            
            const SizedBox(height: 32),

            // Tecnologías
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TECNOLOGÍAS UTILIZADAS',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildToolLink(
                    context: context,
                    title: 'Flutter',
                    subtitle: 'Framework de interfaz de usuario',
                    icon: Icons.flutter_dash,
                    url: 'https://flutter.dev/',
                  ),
                  Divider(color: Theme.of(context).scaffoldBackgroundColor, height: 1),
                  _buildToolLink(
                    context: context,
                    title: 'Supabase',
                    subtitle: 'Backend, Autenticación y Base de datos',
                    icon: Icons.storage,
                    url: 'https://supabase.com/',
                  ),
                  Divider(color: Theme.of(context).scaffoldBackgroundColor, height: 1),
                  _buildToolLink(
                    context: context,
                    title: 'IGDB API',
                    subtitle: 'Base de datos de videojuegos (Twitch)',
                    icon: Icons.videogame_asset,
                    url: 'https://www.igdb.com/api',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildToolLink({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String url,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, )),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _launchUrl(url),
    );
  }
}
