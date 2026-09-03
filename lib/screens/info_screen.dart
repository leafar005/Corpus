import 'package:flutter/material.dart';
import '../theme/corpus_theme_extension.dart';
import '../utils/url_utils.dart';
import '../widgets/corpus_section_title.dart';


class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final success = await openUrl(urlString);
    if (!success) debugPrint('No se pudo abrir el enlace $urlString');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const CorpusScreenTitle('Información'),
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
            Image.asset(
              'assets/images/logo/logo_default.png',
              height: 100,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Corpus',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Versión 1.2.3',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Tu biblioteca personal de videojuegos. Gestiona tus colecciones, descubre nuevos títulos y comparte reseñas con la comunidad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 40),

            // Sección Desarrollador
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DESARROLLO',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://avatars.githubusercontent.com/leafar005',
                      ),
                    ),
                    title: const Text(
                      'leafar005',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Creador y Desarrollador',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: () => _launchUrl('https://github.com/leafar005'),
                  ),
                  Divider(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    height: 1,
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://avatars.githubusercontent.com/coldrzz',
                      ),
                    ),
                    title: const Text(
                      'coldrzz',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Desarrollador',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: () => _launchUrl('https://github.com/coldrzz'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Tecnologías
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TECNOLOGÍAS UTILIZADAS',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
              ),
              child: Column(
                children: [
                  _buildToolLink(
                    context: context,
                    title: 'Flutter',
                    subtitle: 'Framework de interfaz de usuario',
                    icon: Icons.flutter_dash,
                    url: 'https://flutter.dev/',
                  ),
                  Divider(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    height: 1,
                  ),
                  _buildToolLink(
                    context: context,
                    title: 'Supabase',
                    subtitle: 'Backend, Autenticación y Base de datos',
                    icon: Icons.storage,
                    url: 'https://supabase.com/',
                  ),
                  Divider(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    height: 1,
                  ),
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
            const SizedBox(height: 100),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () => _launchUrl(url),
    );
  }
}
