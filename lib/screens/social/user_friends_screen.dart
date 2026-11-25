import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import '../../routes/app_navigation_controller.dart';
import '../../routes/corpus_router.dart';
import '../../widgets/friendship_button.dart';
import '../../repositories/social_repository.dart';

class UserFriendsScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserFriendsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserFriendsScreen> createState() => _UserFriendsScreenState();
}

class _UserFriendsScreenState extends State<UserFriendsScreen> {
  final _repo = SocialRepository();

  List<Map<String, dynamic>> _friends = [];
  Map<String, FriendshipStatus> _friendshipStatuses = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userFriends = await _repo.fetchFriendsOf(widget.userId);
      final friendIds = userFriends
          .map((f) => (f['friend'] as Map?)?['id']?.toString())
          .whereType<String>()
          .toList();
      final rawStatuses = await _repo.fetchFriendshipStatuses(friendIds);
      final mappedStatuses = <String, FriendshipStatus>{};
      final myId = _repo.currentUserId;
      for (final id in friendIds) {
        if (id == myId) {
          mappedStatuses[id] = FriendshipStatus.me;
          continue;
        }
        final entry = rawStatuses[id];
        if (entry == null) {
          mappedStatuses[id] = FriendshipStatus.none;
        } else if (entry.status == 'accepted') {
          mappedStatuses[id] = FriendshipStatus.friends;
        } else if (entry.iSent) {
          mappedStatuses[id] = FriendshipStatus.sent;
        } else {
          mappedStatuses[id] = FriendshipStatus.received;
        }
      }

      if (mounted) {
        setState(() {
          _friends = userFriends;
          _friendshipStatuses = mappedStatuses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user friends: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildUserAvatar(String? avatarUrl, {double radius = 22}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null ? CorpusTablerIcon(CorpusIconKind.Person, size: radius) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => AppNavigationController.instance.requestBack(context),
        ),
        title: Text('Amigos de @${widget.username}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? Center(
              child: Text(
                '@${widget.username} aún no tiene amigos.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _friends.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final friendship = _friends[i];
                final friend =
                    friendship['friend'] as Map<String, dynamic>? ?? {};
                final friendId = friend['id'] as String?;
                final displayName =
                    friend['display_name'] as String? ??
                    friend['username'] as String? ??
                    'Usuario';

                final isMe = friendId == _repo.currentUserId;

                Widget? trailing;
                if (isMe) {
                  trailing = Chip(
                    label: const Text('Tú', style: TextStyle(fontSize: 12)),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    side: BorderSide.none,
                  );
                } else if (friendId != null) {
                  trailing = FriendshipButton(
                    key: ValueKey(friendId),
                    targetUserId: friendId,
                    isIconOnly: true,
                    initialStatus:
                        _friendshipStatuses[friendId] ?? FriendshipStatus.none,
                    onStatusChanged: (newStatus) {
                      if (!mounted) return;
                      setState(() {
                        _friendshipStatuses[friendId] = newStatus;
                      });
                    },
                  );
                }

                return ListTile(
                  leading: _buildUserAvatar(friend['avatar_url'] as String?),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('@${friend['username'] ?? ''}'),
                  trailing: trailing,
                  onTap: () {
                    if (friendId == null) return;
                    context.pushProfile(userId: friendId);
                  },
                );
              },
            ),
    );
  }
}
