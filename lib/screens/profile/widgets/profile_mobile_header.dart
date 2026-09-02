import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import '../../../widgets/activity_story_ring.dart';
import '../../../repositories/activity_repository.dart';
import '../currently_playing_badge.dart';
import '../../../widgets/level_progress_bar.dart';

class ProfileMobileHeader extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final double collapseProgress;
  final VoidCallback openOwnStory;
  final List<Map<String, dynamic>> stories; // from _controller.stories
  final bool isOwnProfile;
  final VoidCallback onLevelTapped;
  final Widget Function({
    required bool isDesktop,
    required bool compact,
    required bool onImage,
  })
  buildFriendsCountLink;

  const ProfileMobileHeader({
    super.key,
    required this.userProfile,
    required this.collapseProgress,
    required this.openOwnStory,
    required this.stories,
    required this.isOwnProfile,
    required this.onLevelTapped,
    required this.buildFriendsCountLink,
  });

  @override
  Widget build(BuildContext context) {
    final username = userProfile?['username'] ?? 'Jugador';
    final displayName = userProfile?['display_name'] ?? username;
    final avatarUrl = userProfile?['avatar_url'];
    final t = collapseProgress.clamp(0.0, 1.0);

    final nameFontSize = 22.0 - (4.0 * t);
    final handleFontSize = 13.0 - (1.0 * t);
    const nameHandleGap = 2.0;
    const expandedAvatarRadius = 40.0;
    final collapsedAvatarRadius =
        (nameFontSize * 1.1 + nameHandleGap + handleFontSize * 1.1) / 2;
    final avatarRadius =
        expandedAvatarRadius -
        (expandedAvatarRadius - collapsedAvatarRadius) * t;
    final showLevel = t < 0.5;
    final showPlaying = t < 0.35 && userProfile != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8.0 - (2.0 * t), 16, 8.0 - (2.0 * t)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: openOwnStory,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: viewedStoryIdsNotifier,
              builder: (context, viewedIds, _) {
                final hasStory = stories.isNotEmpty;
                final hasUnseenStory =
                    hasStory &&
                    ActivityRepository.groupHasUnseenStory(stories, viewedIds);
                return Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ActivityStoryRing(
                    radius: avatarRadius,
                    hasStory: hasStory,
                    hasUnseenStory: hasUnseenStory,
                    avatarUrl: avatarUrl,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    ringWidth: 3.0,
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 12.0 - (2.0 * t)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (userProfile != null)
                      buildFriendsCountLink(
                        isDesktop: false,
                        compact: true,
                        onImage: false,
                      ),
                  ],
                ),
                const SizedBox(height: nameHandleGap),
                Row(
                  children: [
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: handleFontSize,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                    if (showPlaying && userProfile != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: CurrentlyPlayingBadge(
                          userId: userProfile!['id'],
                          initialProfile: userProfile!,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                ),
                if (showLevel) ...[
                  SizedBox(height: 4.0 - (1.0 * t)),
                  LevelProgressBar(
                    xp: (userProfile?['xp'] as num?)?.toInt() ?? 0,
                    compact: t > 0.25,
                    onTap: isOwnProfile ? onLevelTapped : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MobileProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _tabBarHeight = 48.0;
  static const double _expandedProfileHeight = 120.0;
  static const double _playingExtraHeight = 22.0;
  static const double _collapsedProfileHeight = 60.0;

  final double topPadding;
  final bool hasCurrentlyPlaying;
  final Widget Function(double collapseProgress) profileBuilder;
  final Widget Function() tabBarBuilder;

  MobileProfileHeaderDelegate({
    required this.topPadding,
    this.hasCurrentlyPlaying = false,
    required this.profileBuilder,
    required this.tabBarBuilder,
  });

  double get _expandedProfile =>
      _expandedProfileHeight +
      (hasCurrentlyPlaying ? _playingExtraHeight : 0.0);

  @override
  double get minExtent => topPadding + _collapsedProfileHeight + _tabBarHeight;

  @override
  double get maxExtent => topPadding + _expandedProfile + _tabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;
    final collapseProgress = collapseRange > 0
        ? (shrinkOffset / collapseRange).clamp(0.0, 1.0)
        : 0.0;
    final profileHeight =
        _expandedProfile -
        ((_expandedProfile - _collapsedProfileHeight) * collapseProgress);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: Colors.black26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPadding),
          SizedBox(
            height: profileHeight,
            child: ClipRect(child: profileBuilder(collapseProgress)),
          ),
          SizedBox(
            height: _tabBarHeight,
            child: ClipRect(child: tabBarBuilder()),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant MobileProfileHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.hasCurrentlyPlaying != hasCurrentlyPlaying ||
        oldDelegate.profileBuilder != profileBuilder ||
        oldDelegate.tabBarBuilder != tabBarBuilder;
  }
}
