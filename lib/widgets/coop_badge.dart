import 'package:flutter/material.dart';
import '../screens/profile/profile_screen.dart';

class CoopBadge extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double size;
  final String? status;
  final String? userId;

  const CoopBadge({
    super.key,
    required this.username,
    this.avatarUrl,
    this.size = 24.0,
    this.status,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final text = status == 'playing'
        ? 'Jugando con @$username'
        : 'Jugado con @$username';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: userId != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: userId!),
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: avatarUrl == null
                  ? Icon(
                      Icons.person,
                      size: size * 0.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
