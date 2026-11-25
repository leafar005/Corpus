import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../repositories/game_group_repository.dart';
import '../../utils/safe_change_notifier.dart';

class GameGroupsController extends SafeChangeNotifier {
  GameGroupsController({
    required this.userId,
    GameGroupRepository? repository,
  }) : _repo = repository ?? GameGroupRepository() {
    load();
  }

  final String userId;
  final GameGroupRepository _repo;

  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  List<GameGroup> groups = [];

  bool _isLoading = false;

  Future<void> load({bool silent = false}) async {
    if (isDisposed || _isLoading) return;
    _isLoading = true;

    if (!silent) {
      isLoading = true;
      hasError = false;
      errorMessage = null;
      notify();
    }

    try {
      groups = await _repo.fetchGroups(userId);
      isLoading = false;
      hasError = false;
    } catch (e) {
      debugPrint('[GameGroupsController] load: $e');
      hasError = true;
      errorMessage = 'No se pudieron cargar las colecciones.';
      isLoading = false;
    } finally {
      _isLoading = false;
    }
    notify();
  }

  Future<GameGroup?> createGroup({
    required String name,
    String? description,
    bool isRanked = false,
  }) async {
    try {
      final created = await _repo.createGroup(
        userId: userId,
        name: name,
        description: description,
        isRanked: isRanked,
      );
      groups = [...groups, created];
      notify();
      return created;
    } catch (e) {
      debugPrint('[GameGroupsController] createGroup: $e');
      return null;
    }
  }

  Future<GameGroup?> updateGroup({
    required String groupId,
    String? name,
    String? description,
    int? coverGameId,
    bool clearCover = false,
    bool? isRanked,
  }) async {
    try {
      final updated = await _repo.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        coverGameId: coverGameId,
        clearCover: clearCover,
        isRanked: isRanked,
      );
      final idx = groups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        final current = groups[idx];
        final merged = current.copyWith(
          name: updated.name,
          description: updated.description,
          coverGameId: updated.coverGameId,
          isRanked: updated.isRanked,
        );
        groups = [
          for (var i = 0; i < groups.length; i++)
            i == idx ? merged : groups[i],
        ];
        notify();
      } else {
        await load(silent: true);
      }
      return updated;
    } catch (e) {
      debugPrint('[GameGroupsController] updateGroup: $e');
      return null;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await _repo.deleteGroup(groupId);
      groups = groups.where((g) => g.id != groupId).toList();
      notify();
      return true;
    } catch (e) {
      debugPrint('[GameGroupsController] deleteGroup: $e');
      return false;
    }
  }

  Future<void> reorderGroups(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= groups.length ||
        newIndex >= groups.length) {
      return;
    }
    final updated = List<GameGroup>.from(groups);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    groups = [
      for (var i = 0; i < updated.length; i++)
        updated[i].copyWith(sortOrder: i),
    ];
    notify();

    try {
      await _repo.reorderGroups(groups.map((g) => g.id).toList());
    } catch (e) {
      debugPrint('[GameGroupsController] reorderGroups: $e');
      await load(silent: true);
    }
  }

  Future<GameGroup?> loadGroupDetail(String groupId) async {
    try {
      return await _repo.fetchGroupDetail(groupId, userId);
    } catch (e) {
      debugPrint('[GameGroupsController] loadGroupDetail: $e');
      return null;
    }
  }

  Future<GameGroupItem?> addGameToGroup({
    required String groupId,
    required Game game,
    String? note,
  }) async {
    try {
      final item = await _repo.addGameToGroup(
        groupId: groupId,
        game: game,
        note: note,
      );
      final idx = groups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        final current = groups[idx];
        final newItems = current.items.length < 4
            ? [...current.items, item]
            : current.items;
        groups = [
          for (var i = 0; i < groups.length; i++)
            i == idx
                ? current.copyWith(
                    items: newItems,
                    gameCount: current.gameCount + 1,
                  )
                : groups[i],
        ];
        notify();
      }
      return item;
    } catch (e) {
      debugPrint('[GameGroupsController] addGameToGroup: $e');
      return null;
    }
  }

  Future<bool> removeGameFromGroup(String groupId, String itemId) async {
    try {
      await _repo.removeGameFromGroup(itemId);
      final idx = groups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        final current = groups[idx];
        final newCount = current.gameCount > 0 ? current.gameCount - 1 : 0;
        final removedFromPreview = current.items.any((i) => i.id == itemId);
        if (removedFromPreview && newCount >= 4) {
          // Si había >4 juegos y se quitó uno de la vista previa, recargamos solo si hace falta rellenar el 4º slot.
          await load(silent: true);
        } else {
          final remaining =
              current.items.where((i) => i.id != itemId).toList();
          groups = [
            for (var i = 0; i < groups.length; i++)
              i == idx
                  ? current.copyWith(items: remaining, gameCount: newCount)
                  : groups[i],
          ];
          notify();
        }
      }
      return true;
    } catch (e) {
      debugPrint('[GameGroupsController] removeGameFromGroup: $e');
      return false;
    }
  }

  Future<void> reorderItems(
    String groupId,
    List<GameGroupItem> orderedItems,
  ) async {
    try {
      await _repo.reorderItems(
        groupId,
        orderedItems.map((i) => i.id).toList(),
      );
    } catch (e) {
      debugPrint('[GameGroupsController] reorderItems: $e');
    }
  }
}
