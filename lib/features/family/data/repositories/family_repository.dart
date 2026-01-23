import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/storage_service.dart';
import '../models/family_model.dart';

/// 家庭数据仓库
class FamilyRepository {
  final StorageService _storage;

  FamilyRepository(this._storage);

  /// 获取所有家庭
  List<FamilyModel> getAllFamilies() {
    return _storage.familiesBox.values.toList();
  }

  /// 根据 ID 获取家庭
  FamilyModel? getFamilyById(String id) {
    return _storage.familiesBox.values.firstWhere(
      (f) => f.id == id,
      orElse: () => throw Exception('Family not found'),
    );
  }

  /// 保存家庭
  Future<void> saveFamily(FamilyModel family) async {
    await _storage.familiesBox.put(family.id, family);
  }

  /// 删除家庭
  Future<void> deleteFamily(String id) async {
    await _storage.familiesBox.delete(id);
  }

  /// 添加家庭成员
  Future<void> addMember(String familyId, FamilyMemberModel member) async {
    final family = getFamilyById(familyId);
    if (family != null) {
      family.members.add(member);
      family.updatedAt = DateTime.now();
      await family.save();
    }
  }

  /// 更新家庭成员
  Future<void> updateMember(
    String familyId,
    String memberId,
    FamilyMemberModel updatedMember,
  ) async {
    final family = getFamilyById(familyId);
    if (family != null) {
      final index = family.members.indexWhere((m) => m.id == memberId);
      if (index >= 0) {
        family.members[index] = updatedMember;
        family.updatedAt = DateTime.now();
        await family.save();
      }
    }
  }

  /// 删除家庭成员
  Future<void> removeMember(String familyId, String memberId) async {
    final family = getFamilyById(familyId);
    if (family != null) {
      family.members.removeWhere((m) => m.id == memberId);
      family.updatedAt = DateTime.now();
      await family.save();
    }
  }

  /// 更新餐次设置
  Future<void> updateMealSettings(
    String familyId,
    MealSettingsModel settings,
  ) async {
    final family = getFamilyById(familyId);
    if (family != null) {
      family.mealSettings = settings;
      family.updatedAt = DateTime.now();
      await family.save();
    }
  }

  /// 获取当前选中的家庭 ID
  String? getCurrentFamilyId() {
    return _storage.settingsBox.get('currentFamilyId') as String?;
  }

  /// 设置当前选中的家庭 ID
  Future<void> setCurrentFamilyId(String familyId) async {
    await _storage.settingsBox.put('currentFamilyId', familyId);
  }

  /// 获取当前家庭
  FamilyModel? getCurrentFamily() {
    final id = getCurrentFamilyId();
    if (id == null) return null;
    try {
      return getFamilyById(id);
    } catch (_) {
      return null;
    }
  }
}

/// Family Repository Provider
final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FamilyRepository(storage);
});

/// 所有家庭 Provider
final allFamiliesProvider = Provider<List<FamilyModel>>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getAllFamilies();
});

/// 当前家庭 Provider
final currentFamilyProvider = StateNotifierProvider<CurrentFamilyNotifier, FamilyModel?>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return CurrentFamilyNotifier(repo);
});

class CurrentFamilyNotifier extends StateNotifier<FamilyModel?> {
  final FamilyRepository _repository;

  CurrentFamilyNotifier(this._repository) : super(null) {
    _loadCurrentFamily();
  }

  void _loadCurrentFamily() {
    state = _repository.getCurrentFamily();
  }

  Future<void> setCurrentFamily(String familyId) async {
    await _repository.setCurrentFamilyId(familyId);
    state = _repository.getFamilyById(familyId);
  }

  Future<void> refresh() async {
    _loadCurrentFamily();
  }
}
