import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendshipButton extends StatefulWidget {
  final String targetUserId;
  final bool isIconOnly;

  const FriendshipButton({
    super.key,
    required this.targetUserId,
    this.isIconOnly = false,
  });

  @override
  State<FriendshipButton> createState() => _FriendshipButtonState();
}

enum FriendshipStatus { loading, none, friends, sent, received, me }

class _FriendshipButtonState extends State<FriendshipButton> {
  final _supabase = Supabase.instance.client;
  FriendshipStatus _status = FriendshipStatus.loading;
  bool _isProcessing = false;

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_myId.isEmpty) {
      if (mounted) setState(() => _status = FriendshipStatus.none);
      return;
    }
    if (_myId == widget.targetUserId) {
      if (mounted) setState(() => _status = FriendshipStatus.me);
      return;
    }

    try {
      final res = await _supabase
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or(
            'and(requester_id.eq.$_myId,addressee_id.eq.${widget.targetUserId}),and(requester_id.eq.${widget.targetUserId},addressee_id.eq.$_myId)',
          )
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        setState(() => _status = FriendshipStatus.none);
      } else {
        final status = res['status'] as String;
        if (status == 'accepted') {
          setState(() => _status = FriendshipStatus.friends);
        } else {
          // pending
          if (res['requester_id'] == _myId) {
            setState(() => _status = FriendshipStatus.sent);
          } else {
            setState(() => _status = FriendshipStatus.received);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking friendship: $e');
      if (mounted) setState(() => _status = FriendshipStatus.none);
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _isProcessing = true);
    try {
      await _supabase.from('friendships').insert({
        'requester_id': _myId,
        'addressee_id': widget.targetUserId,
        'status': 'pending',
      });
      if (mounted) setState(() => _status = FriendshipStatus.sent);
    } catch (e) {
      debugPrint('[FriendshipButton] Error enviando solicitud: $e');
      if (mounted) setState(() => _status = FriendshipStatus.none);
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _cancelRequest() async {
    setState(() => _isProcessing = true);
    try {
      await _supabase.from('friendships').delete().match({
        'requester_id': _myId,
        'addressee_id': widget.targetUserId,
      });
      if (mounted) setState(() => _status = FriendshipStatus.none);
    } catch (e) {
      debugPrint('[FriendshipButton] Error cancelando solicitud: $e');
      if (mounted) setState(() => _status = FriendshipStatus.sent);
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _acceptRequest() async {
    setState(() => _isProcessing = true);
    try {
      await _supabase.from('friendships').update({'status': 'accepted'}).match({
        'requester_id': widget.targetUserId,
        'addressee_id': _myId,
      });
      if (mounted) setState(() => _status = FriendshipStatus.friends);
    } catch (e) {
      debugPrint('[FriendshipButton] Error aceptando solicitud: $e');
      if (mounted) setState(() => _status = FriendshipStatus.received);
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _removeFriend() async {
    setState(() => _isProcessing = true);
    try {
      await _supabase
          .from('friendships')
          .delete()
          .or(
            'and(requester_id.eq.$_myId,addressee_id.eq.${widget.targetUserId}),and(requester_id.eq.${widget.targetUserId},addressee_id.eq.$_myId)',
          );
      if (mounted) setState(() => _status = FriendshipStatus.none);
    } catch (e) {
      debugPrint('[FriendshipButton] Error eliminando amistad: $e');
      if (mounted) setState(() => _status = FriendshipStatus.friends);
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_status == FriendshipStatus.loading ||
        _myId.isEmpty ||
        _status == FriendshipStatus.me) {
      return const SizedBox.shrink();
    }

    if (_isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (_status) {
      case FriendshipStatus.none:
        if (widget.isIconOnly) {
          return IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _sendRequest,
            tooltip: 'Añadir amigo',
          );
        }
        return ElevatedButton.icon(
          onPressed: _sendRequest,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Añadir amigo'),
        );

      case FriendshipStatus.sent:
        if (widget.isIconOnly) {
          return IconButton(
            icon: Icon(
              Icons.cancel_schedule_send_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: _cancelRequest,
            tooltip: 'Cancelar solicitud',
          );
        }
        return OutlinedButton.icon(
          onPressed: _cancelRequest,
          icon: const Icon(Icons.cancel_schedule_send_rounded, size: 18),
          label: const Text('Cancelar solicitud'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        );

      case FriendshipStatus.received:
        if (widget.isIconOnly) {
          return IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
            onPressed: _acceptRequest,
            tooltip: 'Aceptar solicitud',
          );
        }
        return ElevatedButton.icon(
          onPressed: _acceptRequest,
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Aceptar solicitud'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        );

      case FriendshipStatus.friends:
        if (widget.isIconOnly) {
          return IconButton(
            icon: const Icon(Icons.person_remove_rounded),
            onPressed: _removeFriend,
            tooltip: 'Eliminar amigo',
          );
        }
        return OutlinedButton.icon(
          onPressed: _removeFriend,
          icon: const Icon(Icons.person_remove_rounded, size: 18),
          label: const Text('Amigos'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
