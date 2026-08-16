import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/profile_screen.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';

/// Pantalla de gestión de amigos: buscar por username, ver solicitudes,
/// ver amigos aceptados y eliminar amistades.
class FriendsScreen extends StatefulWidget {
  final int initialIndex;
  const FriendsScreen({super.key, this.initialIndex = 2});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _supabase = Supabase.instance.client;

  // Estado de la pestaña "Buscar"
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // Estado de la pestaña "Solicitudes"
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _isLoadingRequests = true;

  // Estado de la pestaña "Mis Amigos"
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;

  // IDs de usuarios a los que ya envié solicitud (o ya son amigos), para el botón
  Set<String> _sentOrAccepted = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _loadRequests();
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  // ──────────────────────────────────────────
  // CARGA DE DATOS
  // ──────────────────────────────────────────

  Future<void> _loadRequests() async {
    if (_myId.isEmpty) {
      if (mounted) setState(() => _isLoadingRequests = false);
      return;
    }
    setState(() => _isLoadingRequests = true);
    try {
      final receivedData = await _supabase
          .from('friendships')
          .select(
            '*, requester:requester_id(id, username, avatar_url, display_name)',
          )
          .eq('addressee_id', _myId)
          .eq('status', 'pending');
          
      final sentData = await _supabase
          .from('friendships')
          .select(
            '*, addressee:addressee_id(id, username, avatar_url, display_name)',
          )
          .eq('requester_id', _myId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _receivedRequests = List<Map<String, dynamic>>.from(receivedData);
          _sentRequests = List<Map<String, dynamic>>.from(sentData);
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _loadFriends() async {
    if (_myId.isEmpty) {
      if (mounted) setState(() => _isLoadingFriends = false);
      return;
    }
    setState(() => _isLoadingFriends = true);
    try {
      // Los amigos pueden estar en cualquiera de los dos campos
      final asSender = await _supabase
          .from('friendships')
          .select(
            '*, friend:addressee_id(id, username, avatar_url, display_name)',
          )
          .eq('requester_id', _myId)
          .eq('status', 'accepted');

      final asReceiver = await _supabase
          .from('friendships')
          .select(
            '*, friend:requester_id(id, username, avatar_url, display_name)',
          )
          .eq('addressee_id', _myId)
          .eq('status', 'accepted');

      final all = [
        ...List<Map<String, dynamic>>.from(asSender),
        ...List<Map<String, dynamic>>.from(asReceiver),
      ];

      final sentOrAcceptedIds = <String>{};
      for (final f in all) {
        final fid = f['friend']['id'] as String?;
        if (fid != null) sentOrAcceptedIds.add(fid);
      }

      // También añadir los que están pendientes (enviados por mí)
      final pendingSent = await _supabase
          .from('friendships')
          .select('addressee_id')
          .eq('requester_id', _myId)
          .eq('status', 'pending');

      for (final p in List<Map<String, dynamic>>.from(pendingSent)) {
        final id = p['addressee_id'] as String?;
        if (id != null) sentOrAcceptedIds.add(id);
      }

      if (mounted) {
        setState(() {
          _friends = all;
          _sentOrAccepted = sentOrAcceptedIds;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  // ──────────────────────────────────────────
  // ACCIONES
  // ──────────────────────────────────────────

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final data = await _supabase
          .from('users')
          .select('id, username, avatar_url, display_name')
          .ilike('username', '%${query.trim()}%')
          .neq('id', _myId)
          .limit(20);
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Error al buscar: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendRequest(String targetId) async {
    try {
      await _supabase.from('friendships').insert({
        'requester_id': _myId,
        'addressee_id': targetId,
        'status': 'pending',
      });
      if (mounted) {
        setState(() => _sentOrAccepted.add(targetId));
        _showSnack('Solicitud enviada ✓');
      }
    } catch (e) {
      _showSnack('Error al enviar solicitud');
    }
  }

  Future<void> _acceptRequest(String requesterId) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('requester_id', requesterId)
          .eq('addressee_id', _myId);
      _showSnack('¡Ahora sois amigos!');
      await _loadRequests();
      await _loadFriends();
    } catch (e) {
      _showSnack('Error al aceptar solicitud');
    }
  }

  Future<void> _rejectRequest(String requesterId) async {
    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('requester_id', requesterId)
          .eq('addressee_id', _myId);
      _showSnack('Solicitud rechazada');
      await _loadRequests();
    } catch (e) {
      _showSnack('Error al rechazar solicitud');
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> friendship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar amigo'),
        content: Text(
          '¿Quieres eliminar a @${friendship['friend']['username']} de tu lista de amigos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final friendId = friendship['friend']['id'] as String;
      // Borramos en ambas direcciones
      await _supabase
          .from('friendships')
          .delete()
          .or(
            'and(requester_id.eq.$_myId,addressee_id.eq.$friendId),and(requester_id.eq.$friendId,addressee_id.eq.$_myId)',
          );
      _showSnack('Amigo eliminado');
      await _loadFriends();
    } catch (e) {
      _showSnack('Error al eliminar amigo');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ──────────────────────────────────────────
  // WIDGETS
  // ──────────────────────────────────────────

  Widget _buildUserAvatar(String? avatarUrl, {double radius = 22}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null ? Icon(Icons.person, size: radius) : null,
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre de usuario…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
              ),
              filled: true,
            ),
            onChanged: _searchUsers,
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else if (_searchError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _searchError!,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else
          Expanded(
            child: _searchResults.isEmpty && _searchController.text.isNotEmpty
                ? const Center(child: Text('No se encontraron usuarios'))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      final userId = user['id'] as String;
                      final alreadySentOrFriend = _sentOrAccepted.contains(
                        userId,
                      );
                      final displayName =
                          user['display_name'] as String? ??
                          user['username'] as String? ??
                          'Usuario';
                      final isFriend = _friends.any(
                        (f) => f['friend']?['id'] == userId,
                      );
                      final isPending = alreadySentOrFriend && !isFriend;

                      Widget? trailingWidget;
                      if (isFriend) {
                        trailingWidget = Chip(
                          label: const Text(
                            'Amigos',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          side: BorderSide.none,
                        );
                      } else if (isPending) {
                        trailingWidget = Chip(
                          label: const Text(
                            'Enviado',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          side: BorderSide.none,
                        );
                      } else {
                        trailingWidget = FilledButton.icon(
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Añadir'),
                          onPressed: () => _sendRequest(userId),
                        );
                      }

                      return ListTile(
                        leading: _buildUserAvatar(
                          user['avatar_url'] as String?,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '@${user['username']}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _FriendProfileScreen(userId: userId),
                            ),
                          );
                        },
                        trailing: trailingWidget,
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_receivedRequests.isEmpty && _sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin solicitudes pendientes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_receivedRequests.isNotEmpty) ...[
            const CorpusSectionTitle('Recibidas'),
            ..._receivedRequests.map((req) {
              final requester = req['requester'] as Map<String, dynamic>? ?? {};
              final requesterId = requester['id'] as String? ?? '';
              final displayName =
                  requester['display_name'] as String? ??
                  requester['username'] as String? ??
                  'Usuario';
              return ListTile(
                leading: _buildUserAvatar(requester['avatar_url'] as String?),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('@${requester['username'] ?? ''}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: requesterId),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 30,
                      ),
                      tooltip: 'Aceptar',
                      onPressed: () => _acceptRequest(requesterId),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.red,
                        size: 30,
                      ),
                      tooltip: 'Rechazar',
                      onPressed: () => _rejectRequest(requesterId),
                    ),
                  ],
                ),
              );
            }),
            if (_sentRequests.isNotEmpty) const Divider(height: 32),
          ],
          if (_sentRequests.isNotEmpty) ...[
            const CorpusSectionTitle('Enviadas'),
            ..._sentRequests.map((req) {
              final addressee = req['addressee'] as Map<String, dynamic>? ?? {};
              final addresseeId = addressee['id'] as String? ?? '';
              final displayName =
                  addressee['display_name'] as String? ??
                  addressee['username'] as String? ??
                  'Usuario';
              return ListTile(
                leading: _buildUserAvatar(addressee['avatar_url'] as String?),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('@${addressee['username'] ?? ''}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: addresseeId),
                    ),
                  );
                },
                trailing: TextButton.icon(
                  onPressed: () => _cancelSentRequest(addresseeId),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _cancelSentRequest(String addresseeId) async {
    try {
      await _supabase.from('friendships').delete().match({
        'requester_id': _myId,
        'addressee_id': addresseeId,
      });
      if (mounted) {
        setState(() {
          _sentRequests.removeWhere((r) => r['addressee_id'] == addresseeId);
          _sentOrAccepted.remove(addresseeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar la solicitud')),
        );
      }
    }
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Todavía no tienes amigos en Corpus.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¡Búscalos por su nombre de usuario!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        separatorBuilder: (_, i) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final friendship = _friends[i];
          final friend = friendship['friend'] as Map<String, dynamic>? ?? {};
          final displayName =
              friend['display_name'] as String? ??
              friend['username'] as String? ??
              'Usuario';
          return ListTile(
            leading: _buildUserAvatar(friend['avatar_url'] as String?),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('@${friend['username'] ?? ''}'),
            onTap: () {
              final friendId = friend['id'] as String?;
              if (friendId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FriendProfileScreen(userId: friendId),
                ),
              );
            },
            trailing: IconButton(
              icon: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Eliminar amigo',
              onPressed: () => _removeFriend(friendship),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CorpusScreenTitle('Amigos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.search), text: 'Buscar'),
            Tab(
              icon: Badge(
                isLabelVisible: _receivedRequests.isNotEmpty,
                label: Text(_receivedRequests.length.toString()),
                child: const Icon(Icons.notifications_rounded),
              ),
              text: 'Solicitudes',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _friends.isNotEmpty,
                label: Text(_friends.length.toString()),
                child: const Icon(Icons.group_rounded),
              ),
              text: 'Mis amigos',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSearchTab(), _buildRequestsTab(), _buildFriendsTab()],
      ),
    );
  }
}

/// Wrapper sencillo para mostrar el perfil de un amigo concreto.
class _FriendProfileScreen extends StatelessWidget {
  final String userId;
  const _FriendProfileScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(userId: userId);
  }
}
