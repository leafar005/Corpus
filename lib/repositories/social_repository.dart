import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/postgrest_utils.dart';

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
    final trimmed = query.trim();
    if (myId == null || trimmed.isEmpty) return [];

    final escaped = escapeLikePattern(trimmed);
    final data = await _client
        .from('users')
        .select('id, username, avatar_url, display_name')
        .ilike('username', '%$escaped%')
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
    final trimmedTarget = targetId.trim();
    if (trimmedTarget.isEmpty) {
      throw ArgumentError.value(targetId, 'targetId', 'ID de usuario vacío');
    }
    if (trimmedTarget == myId) {
      throw ArgumentError.value(
        targetId,
        'targetId',
        'No puedes enviarte una solicitud de amistad a ti mismo',
      );
    }

    await _client.from('friendships').insert({
      'requester_id': myId,
      'addressee_id': trimmedTarget,
      'status': 'pending',
    });
  }

  /// Acepta la solicitud de amistad de [requesterId].
  Future<void> acceptFriendRequest(String requesterId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');
    final trimmedRequester = requesterId.trim();
    if (trimmedRequester.isEmpty) {
      throw ArgumentError.value(
        requesterId,
        'requesterId',
        'ID de solicitante vacío',
      );
    }

    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('requester_id', trimmedRequester)
        .eq('addressee_id', myId);
  }

  /// Rechaza (elimina) la solicitud de amistad de [requesterId].
  Future<void> rejectFriendRequest(String requesterId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');
    final trimmedRequester = requesterId.trim();
    if (trimmedRequester.isEmpty) {
      throw ArgumentError.value(
        requesterId,
        'requesterId',
        'ID de solicitante vacío',
      );
    }

    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', trimmedRequester)
        .eq('addressee_id', myId);
  }

  /// Cancela una solicitud de amistad enviada a [addresseeId].
  Future<void> cancelSentRequest(String addresseeId) async {
    final myId = currentUserId;
    if (myId == null) throw Exception('Not logged in');
    final trimmedAddressee = addresseeId.trim();
    if (trimmedAddressee.isEmpty) {
      throw ArgumentError.value(
        addresseeId,
        'addresseeId',
        'ID de destinatario vacío',
      );
    }

    await _client.from('friendships').delete().match({
      'requester_id': myId,
      'addressee_id': trimmedAddressee,
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
    final safeMyId = requireValidUuid(myId, name: 'myId');
    final safeFriendId = requireValidUuid(friendId, name: 'friendId');

    await _client
        .from('friendships')
        .delete()
        .or(
          'and(requester_id.eq.$safeMyId,addressee_id.eq.$safeFriendId),and(requester_id.eq.$safeFriendId,addressee_id.eq.$safeMyId)',
        );
  }
}
