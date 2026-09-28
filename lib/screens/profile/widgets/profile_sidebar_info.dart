import 'package:flutter/material.dart';
import '../../../theme/corpus_theme_extension.dart';
import '../../../widgets/genre_radar_section.dart';
import 'profile_ratings_histogram.dart';

/// Sidebar del perfil: bio, histograma de ratings, plataformas, radar de géneros.
class ProfileSidebarInfo extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<double> ratings;
  final String? resolvedUserId;
  final bool isMobile;

  const ProfileSidebarInfo({
    super.key,
    required this.userProfile,
    required this.ratings,
    required this.resolvedUserId,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final bio = userProfile?['bio'];
    final platforms = List<String>.from(userProfile?['platforms'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio != null && bio.isNotEmpty) ...[
          Text(
            'Bio',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(bio, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
        ],
        if (!isMobile) ProfileRatingsHistogram(ratings: ratings),
        if (platforms.isNotEmpty) ...[
          Text(
            'Plataformas',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms.map((p) => _buildPlatformIcon(context, p)).toList(),
          ),
          const SizedBox(height: 24),
        ],
        if (!isMobile && resolvedUserId != null)
          GenreRadarSection(userId: resolvedUserId!),
      ],
    );
  }

  Widget _buildPlatformIcon(BuildContext context, String platform) {
    String? imagePath;
    IconData? icon;
    Color color;
    switch (platform) {
      case 'pc':
        icon = Icons.computer;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'linux':
        imagePath = 'assets/images/linux.png';
        color = Colors.orangeAccent.shade700;
        break;
      case 'playstation':
        imagePath = 'assets/images/playstation.png';
        color = Colors.blue;
        break;
      case 'xbox':
        imagePath = 'assets/images/xbox.png';
        color = Colors.green;
        break;
      case 'switch':
        imagePath = 'assets/images/switch.png';
        color = Colors.red;
        break;
      case 'switch2':
        imagePath = 'assets/images/switch2.png';
        color = Colors.red;
        break;
      case 'wii':
        imagePath = 'assets/images/wii.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'wiiu':
        imagePath = 'assets/images/wiiu.png';
        color = const Color(0xFF009AC7);
        break;
      case '3ds':
        imagePath = 'assets/images/3ds.png';
        color = const Color(0xFFCE181E);
        break;
      case 'ds':
        imagePath = 'assets/images/ds.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'mac':
        imagePath = 'assets/images/mac.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'android':
        imagePath = 'assets/images/android.png';
        color = const Color(0xFF3DDC84);
        break;
      case 'vr':
        imagePath = 'assets/images/vr.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'firetv':
        icon = Icons.tv;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'nintendo':
        imagePath = 'assets/images/switch.png';
        color = Colors.red;
        break;
      default:
        icon = Icons.device_unknown;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusSmall,
      ),
      child: imagePath != null
          ? Image.asset(imagePath, width: 24, height: 24, color: color)
          : Icon(icon, color: color, size: 24),
    );
  }
}
