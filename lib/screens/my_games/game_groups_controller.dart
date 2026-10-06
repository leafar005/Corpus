import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../repositories/game_group_repository.dart';

class GameGroupsController extends ChangeNotifier {
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
    if (_isLoading) return;
    _isLoading = true;

    if (!silent) {
      isLoading = true;
      hasError = false;
      errorMessage = null;
      notifyListeners();
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
    notifyListeners();
  }

  Future<GameGroup?> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      final created = await _repo.createGroup(
        userId: userId,
        name: name,
        description: description,
      );
      groups = [...groups, created];
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('[GameGroupsController] createGroup: $e');
      return null;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await _repo.deleteGroup(groupId);
      groups = groups.where((g) => g.id != groupId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[GameGroupsController] deleteGroup: $e');
      return false;
    }
  }

  Future<void> reorderGroups(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final updated = List<GameGroup>.from(groups);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    groups = updated;
    notifyListeners();

    try {
      await _repo.reorderGroups(updated.map((g) => g.id).toList());
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
      await load(silent: true);
      return item;
    } catch (e) {
      debugPrint('[GameGroupsController] addGameToGroup: $e');
      return null;
    }
  }

  Future<bool> removeGameFromGroup(String groupId, String itemId) async {
    try {
      await _repo.removeGameFromGroup(itemId);
      await load(silent: true);
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
