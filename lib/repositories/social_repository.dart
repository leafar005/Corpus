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
  SocialRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

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
        .select(kPublicUserBasicColumns)
        .ilike('username', '%$escaped%')
        .neq('id', myId)
        .limit(20);

    return (data as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ── Solicitudes de amistad ───────────────────────────────────────────────

  /// Devuelve las solicitudes de amistad recibidas por el usuario actual.
  Future<List<Map<String, dynamic>>> fetchReceivedRequests() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final data = await _client
        .from('friendships')
        .select(
          'requester_id, addressee_id, status, created_at, '
          'requester:requester_id($kPublicUserBasicColumns)',
        )
        .eq('addressee_id', myId)
        .eq('status', 'pending')
        .limit(200);

    return (data as List)
        .whereType<Map>()
        .where((e) => e['requester'] is Map)
        .map((e) {
          final copy = Map<String, dynamic>.from(e);
          copy['requester'] = Map<String, dynamic>.from(e['requester'] as Map);
          return copy;
        })
        .toList();
  }

  /// Devuelve las solicitudes de amistad enviadas por el usuario actual.
  Future<List<Map<String, dynamic>>> fetchSentRequests() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final data = await _client
        .from('friendships')
        .select(
          'requester_id, addressee_id, status, created_at, '
          'addressee:addressee_id($kPublicUserBasicColumns)',
        )
        .eq('requester_id', myId)
        .eq('status', 'pending')
        .limit(200);

    return (data as List)
        .whereType<Map>()
        .where((e) => e['addressee'] is Map)
        .map((e) {
          final copy = Map<String, dynamic>.from(e);
          copy['addressee'] = Map<String, dynamic>.from(e['addressee'] as Map);
          return copy;
        })
        .toList();
  }

  /// Envía una solicitud de amistad a [targetId].
  Future<void> sendFriendRequest(String targetId) async {
    final myId = requireAuthenticatedUserId(_client);
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
    final myId = requireAuthenticatedUserId(_client);
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
    final myId = requireAuthenticatedUserId(_client);
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
    final myId = requireAuthenticatedUserId(_client);
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
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return [];

    final results = await Future.wait([
      _client
          .from('friendships')
          .select(
            'requester_id, addressee_id, status, created_at, '
            'friend:addressee_id($kPublicUserBasicColumns)',
          )
          .eq('requester_id', trimmedUserId)
          .eq('status', 'accepted')
          .limit(500),
      _client
          .from('friendships')
          .select(
            'requester_id, addressee_id, status, created_at, '
            'friend:requester_id($kPublicUserBasicColumns)',
          )
          .eq('addressee_id', trimmedUserId)
          .eq('status', 'accepted')
          .limit(500),
    ]);

    return [
      for (final list in results)
        ...(list as List)
            .whereType<Map>()
            .where((e) => e['friend'] is Map)
            .map((e) {
              final copy = Map<String, dynamic>.from(e);
              copy['friend'] = Map<String, dynamic>.from(e['friend'] as Map);
              return copy;
            }),
    ];
  }

  /// Devuelve los estados de amistad del usuario actual con [targetUserIds]
  /// en lote (2 queries paralelas máximas en vez de N queries).
  Future<Map<String, ({String status, bool iSent})>> fetchFriendshipStatuses(
    List<String> targetUserIds,
  ) async {
    final myId = currentUserId;
    if (myId == null) return {};

    final targets = targetUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != myId)
        .toSet()
        .toList();
    if (targets.isEmpty) return {};

    final results = await Future.wait([
      _client
          .from('friendships')
          .select('addressee_id, status')
          .eq('requester_id', myId)
          .inFilter('addressee_id', targets)
          .limit(500),
      _client
          .from('friendships')
          .select('requester_id, status')
          .eq('addressee_id', myId)
          .inFilter('requester_id', targets)
          .limit(500),
    ]);

    final out = <String, ({String status, bool iSent})>{};
    for (final row in (results[0] as List).whereType<Map>()) {
      final id = row['addressee_id']?.toString();
      final status = row['status']?.toString() ?? 'pending';
      if (id != null && id.isNotEmpty) {
        out[id] = (status: status, iSent: true);
      }
    }
    for (final row in (results[1] as List).whereType<Map>()) {
      final id = row['requester_id']?.toString();
      final status = row['status']?.toString() ?? 'pending';
      if (id != null && id.isNotEmpty) {
        out.putIfAbsent(id, () => (status: status, iSent: false));
      }
    }
    return out;
  }

  /// Devuelve los IDs de usuarios que ya son amigos o tienen solicitud pendiente
  /// (enviada o recibida) en 1 sola consulta.
  Future<Set<String>> fetchSentOrAcceptedIds() async {
    final myId = currentUserId;
    if (myId == null) return {};
    final safeMyId = requireValidUuid(myId, name: 'myId');

    final rows = await _client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .or('requester_id.eq.$safeMyId,addressee_id.eq.$safeMyId')
        .inFilter('status', ['pending', 'accepted'])
        .limit(1000);

    final ids = <String>{};
    for (final row in (rows as List).whereType<Map>()) {
      final requester = row['requester_id']?.toString();
      final addressee = row['addressee_id']?.toString();
      if (requester == myId && addressee != null && addressee.isNotEmpty) {
        ids.add(addressee);
      } else if (addressee == myId &&
          requester != null &&
          requester.isNotEmpty) {
        ids.add(requester);
      }
    }
    return ids;
  }

  /// Elimina la amistad con [friendId] (borrando en ambas direcciones).
  Future<void> removeFriend(String friendId) async {
    final myId = requireAuthenticatedUserId(_client);
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
