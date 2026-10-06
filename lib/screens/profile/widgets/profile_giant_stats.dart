import 'package:flutter/material.dart';
import '../../../widgets/profile_stat_icon.dart';

/// Fila de estadísticas gigantes del perfil (Completados, Platinos, Jugando, Wishlist).
class ProfileGiantStats extends StatelessWidget {
  final int beatenCount;
  final int platinumCount;
  final int playingCount;
  final int toPlayCount;
  final int wishlistCount;
  final bool isMobile;
  final void Function(String status) onStatTapped;

  const ProfileGiantStats({
    super.key,
    required this.beatenCount,
    required this.platinumCount,
    required this.playingCount,
    this.toPlayCount = 0,
    required this.wishlistCount,
    this.isMobile = false,
    required this.onStatTapped,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _buildGiantStat(
        context,
        beatenCount.toString().padLeft(3, '0'),
        'Completados',
        ProfileStatIconType.beaten,
        () => onStatTapped('beaten'),
      ),
      _buildGiantStat(
        context,
        platinumCount.toString().padLeft(3, '0'),
        'Platinos',
        ProfileStatIconType.platinum,
        () => onStatTapped('completed'),
      ),
      _buildGiantStat(
        context,
        playingCount.toString().padLeft(3, '0'),
        'Jugando',
        ProfileStatIconType.playing,
        () => onStatTapped('playing'),
      ),
      if (!isMobile)
        _buildGiantStat(
          context,
          toPlayCount.toString().padLeft(3, '0'),
          'Por jugar',
          ProfileStatIconType.toPlay,
          toPlayCount > 0 ? () => onStatTapped('to_play') : null,
        ),
      _buildGiantStat(
        context,
        wishlistCount.toString().padLeft(3, '0'),
        'En Wishlist',
        ProfileStatIconType.wishlist,
        wishlistCount > 0 ? () => onStatTapped('wishlist') : null,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Center(child: stats[0])),
                    Expanded(child: Center(child: stats[1])),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Center(child: stats[2])),
                    Expanded(child: Center(child: stats[3])),
                  ],
                ),
              ],
            )
          : Center(
              child: Wrap(
                spacing: 48,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: stats,
              ),
            ),
    );
  }

  Widget _buildGiantStat(
    BuildContext context,
    String number,
    String label,
    ProfileStatIconType iconType,
    VoidCallback? onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(child: ProfileStatIcon(type: iconType, size: 32)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
