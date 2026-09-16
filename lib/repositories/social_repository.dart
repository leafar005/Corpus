import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio para toda la lógica social: amigos, solicitudes de amistad
/// y búsqueda de usuarios.
///
/// Extrae las queries directas a `Supabase.instance.client` que estaban
/// dispersas en [FriendsScreen] y [UserFriendsScreen].
///
/// See: audit hallazgo C-01 (Fase 2).
class SocialRepository {
  SocialRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ── Búsqueda de usuarios ─────────────────────────────────────────────────

  /// Busca usuarios cuyo username contenga [query] (case-insensitive).
  /// Excluye al usuario actual.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final myId = currentUserId;
    if (myId == null || query.trim().isEmpty) return [];

    final data = await _client
        .from('users')
        .select('id, username, avatar_url, display_name')
        .ilike('username', '%${query.trim()}%')
        .neq('id', myId)
        .limit(20);

    return List<Map<String, dynamic>>.from(data);
  }

  // ── Solicitudes de amistad ───────────────────────────────────────────────

  /// Devuelve las solicitudes de amistad recibidas por el usuario actual.
  Future<List<Map<String, dynamic>>> fetchReceivedRequests() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final data = await _client
        .from('friendships')
        .select(
          '*, requester:requester_id(id, username, avatar_url, display_name)',
        )
        .eq('addressee_id', myId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(data);
  }

  /// Devuelve las solicitudes de amistad enviadas por el usuario actual.
  Future<List<Map<String, dynamic>>> fetchSentRequests() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final data = await _client
        .from('friendships')
        .select(
          '*, addressee:addressee_id(id, username, avatar_url, display_name)',
        )
        .eq('requester_id', myId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(data);
  }

  /// Envía una solicitud de amistad a [targetId].
  Future<void> sendFriendRequest(String targetId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');

    await _client.from('friendships').insert({
      'requester_id': myId,
      'addressee_id': targetId,
      'status': 'pending',
    });
  }

  /// Acepta la solicitud de amistad de [requesterId].
  Future<void> acceptFriendRequest(String requesterId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');

    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('requester_id', requesterId)
        .eq('addressee_id', myId);
  }

  /// Rechaza (elimina) la solicitud de amistad de [requesterId].
  Future<void> rejectFriendRequest(String requesterId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');

    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', requesterId)
        .eq('addressee_id', myId);
  }

  /// Cancela una solicitud de amistad enviada a [addresseeId].
  Future<void> cancelSentRequest(String addresseeId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');

    await _client.from('friendships').delete().match({
      'requester_id': myId,
      'addressee_id': addresseeId,
    });
  }

  // ── Lista de amigos ──────────────────────────────────────────────────────

  /// Devuelve la lista de amigos aceptados del usuario actual.
  Future<List<Map<String, dynamic>>> fetchMyFriends() async {
    final myId = currentUserId;
    if (myId == null) return [];
    return fetchFriendsOf(myId);
  }

  /// Devuelve la lista de amigos aceptados de [userId].
  Future<List<Map<String, dynamic>>> fetchFriendsOf(String userId) async {
    final asSender = await _client
        .from('friendships')
        .select(
          '*, friend:addressee_id(id, username, avatar_url, display_name)',
        )
        .eq('requester_id', userId)
        .eq('status', 'accepted');

    final asReceiver = await _client
        .from('friendships')
        .select(
          '*, friend:requester_id(id, username, avatar_url, display_name)',
        )
        .eq('addressee_id', userId)
        .eq('status', 'accepted');

    return [
      ...List<Map<String, dynamic>>.from(asSender),
      ...List<Map<String, dynamic>>.from(asReceiver),
    ];
  }

  /// Devuelve los IDs de usuarios que ya son amigos o tienen solicitud pendiente.
  /// Útil para deshabilitar el botón "Añadir" en la búsqueda.
  Future<Set<String>> fetchSentOrAcceptedIds() async {
    final myId = currentUserId;
    if (myId == null) return {};

    final friends = await fetchMyFriends();
    final ids = <String>{};
    for (final f in friends) {
      final fid = f['friend']['id'] as String?;
      if (fid != null) ids.add(fid);
    }

    // También incluir solicitudes pendientes enviadas por mí
    final pendingSent = await _client
        .from('friendships')
        .select('addressee_id')
        .eq('requester_id', myId)
        .eq('status', 'pending');

    for (final p in List<Map<String, dynamic>>.from(pendingSent)) {
      final id = p['addressee_id'] as String?;
      if (id != null) ids.add(id);
    }

    return ids;
  }

  /// Elimina la amistad con [friendId] (borrando en ambas direcciones).
  Future<void> removeFriend(String friendId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');

    await _client
        .from('friendships')
        .delete()
        .or(
          'and(requester_id.eq.$myId,addressee_id.eq.$friendId),and(requester_id.eq.$friendId,addressee_id.eq.$myId)',
        );
  }
}
