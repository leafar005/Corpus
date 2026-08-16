import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/profile_screen.dart';
import '../../widgets/friendship_button.dart';

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
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _friends = [];
  Set<String> _myFriendsIds = {};
  bool _isLoading = true;

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Amigos del usuario
      final asSender = await _supabase
          .from('friendships')
          .select('*, friend:addressee_id(id, username, avatar_url, display_name)')
          .eq('requester_id', widget.userId)
          .eq('status', 'accepted');

      final asReceiver = await _supabase
          .from('friendships')
          .select('*, friend:requester_id(id, username, avatar_url, display_name)')
          .eq('addressee_id', widget.userId)
          .eq('status', 'accepted');

      final userFriends = [
        ...List<Map<String, dynamic>>.from(asSender),
        ...List<Map<String, dynamic>>.from(asReceiver),
      ];

      // 2. Mis propios amigos para ver mutuos (solo si estoy logueado)
      final myFriendsIds = <String>{};
      if (_myId.isNotEmpty) {
        final myAsSender = await _supabase
            .from('friendships')
            .select('addressee_id')
            .eq('requester_id', _myId)
            .eq('status', 'accepted');

        final myAsReceiver = await _supabase
            .from('friendships')
            .select('requester_id')
            .eq('addressee_id', _myId)
            .eq('status', 'accepted');

        for (final p in List<Map<String, dynamic>>.from(myAsSender)) {
          final id = p['addressee_id'] as String?;
          if (id != null) myFriendsIds.add(id);
        }
        for (final p in List<Map<String, dynamic>>.from(myAsReceiver)) {
          final id = p['requester_id'] as String?;
          if (id != null) myFriendsIds.add(id);
        }
      }

      if (mounted) {
        setState(() {
          _friends = userFriends;
          _myFriendsIds = myFriendsIds;
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
      child: avatarUrl == null ? Icon(Icons.person, size: radius) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    final friend = friendship['friend'] as Map<String, dynamic>? ?? {};
                    final friendId = friend['id'] as String?;
                    final displayName = friend['display_name'] as String? ?? friend['username'] as String? ?? 'Usuario';

                    final isMe = friendId == _myId;
                    final isMutual = friendId != null && _myFriendsIds.contains(friendId);

                    Widget? trailing;
                    if (isMe) {
                      trailing = Chip(
                        label: const Text('Tú', style: TextStyle(fontSize: 12)),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        side: BorderSide.none,
                      );
                    } else if (friendId != null) {
                      trailing = FriendshipButton(targetUserId: friendId, isIconOnly: true);
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: friendId),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
