import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import '../../repositories/social_repository.dart';

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
  final _repo = SocialRepository();

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
    // Resetear badge de solicitudes al abrir la pantalla
    unreadFriendRequestsCount.value = 0;
    _loadRequests();
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // CARGA DE DATOS
  // ──────────────────────────────────────────

  Future<void> _loadRequests() async {
    if (_repo.currentUserId == null) {
      if (mounted) setState(() => _isLoadingRequests = false);
      return;
    }
    setState(() => _isLoadingRequests = true);
    try {
      final received = await _repo.fetchReceivedRequests();
      final sent = await _repo.fetchSentRequests();

      if (mounted) {
        setState(() {
          _receivedRequests = received;
          _sentRequests = sent;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _loadFriends() async {
    if (_repo.currentUserId == null) {
      if (mounted) setState(() => _isLoadingFriends = false);
      return;
    }
    setState(() => _isLoadingFriends = true);
    try {
      final friends = await _repo.fetchMyFriends();
      final sentOrAcceptedIds = await _repo.fetchSentOrAcceptedIds();

      if (mounted) {
        setState(() {
          _friends = friends;
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
      final results = await _repo.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
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
      await _repo.sendFriendRequest(targetId);
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
      await _repo.acceptFriendRequest(requesterId);
      _showSnack('¡Ahora sois amigos!');
      await _loadRequests();
      await _loadFriends();
    } catch (e) {
      _showSnack('Error al aceptar solicitud');
    }
  }

  Future<void> _rejectRequest(String requesterId) async {
    try {
      await _repo.rejectFriendRequest(requesterId);
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
      await _repo.removeFriend(friendId);
      _showSnack('Amigo eliminado');
      await _loadFriends();
    } catch (e) {
      _showSnack('Error al eliminar amigo');
    }
  }

  Future<void> _cancelSentRequest(String addresseeId) async {
    try {
      await _repo.cancelSentRequest(addresseeId);
      if (mounted) {
        setState(() {
          _sentRequests.removeWhere((r) => r['addressee_id'] == addresseeId);
          _sentOrAccepted.remove(addresseeId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitud cancelada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar la solicitud')),
        );
      }
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
      child: avatarUrl == null ? CorpusTablerIcon(CorpusIconKind.Person, size: radius) : null,
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
              prefixIcon: const CorpusTablerIcon(CorpusIconKind.Search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const CorpusTablerIcon(CorpusIconKind.Clear),
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
                          icon: const CorpusTablerIcon(CorpusIconKind.PersonAdd, size: 18),
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
                          context.pushProfile(userId: userId);
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
            CorpusTablerIcon(CorpusIconKind.InboxRounded,
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
                  context.pushProfile(userId: requesterId);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const CorpusTablerIcon(CorpusIconKind.CheckCircleRounded,
                        color: Colors.green,
                        size: 30,
                      ),
                      tooltip: 'Aceptar',
                      onPressed: () => _acceptRequest(requesterId),
                    ),
                    IconButton(
                      icon: const CorpusTablerIcon(CorpusIconKind.CancelRounded,
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
                  context.pushProfile(userId: addresseeId);
                },
                trailing: TextButton.icon(
                  onPressed: () => _cancelSentRequest(addresseeId),
                  icon: const CorpusTablerIcon(CorpusIconKind.CloseRounded, size: 18),
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

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CorpusTablerIcon(CorpusIconKind.GroupRounded,
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
              context.pushProfile(userId: friendId);
            },
            trailing: IconButton(
              icon: CorpusTablerIcon(CorpusIconKind.PersonRemoveOutlined,
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
        leading: IconButton(
          icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
          onPressed: () =>
              AppNavigationController.instance.requestBack(context),
        ),
        title: const CorpusScreenTitle('Amigos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: CorpusTablerIcon(CorpusIconKind.Search), text: 'Buscar'),
            Tab(
              icon: Badge(
                isLabelVisible: _receivedRequests.isNotEmpty,
                label: Text(_receivedRequests.length.toString()),
                child: const CorpusTablerIcon(CorpusIconKind.NotificationsRounded),
              ),
              text: 'Solicitudes',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _friends.isNotEmpty,
                label: Text(_friends.length.toString()),
                child: const CorpusTablerIcon(CorpusIconKind.GroupRounded),
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
