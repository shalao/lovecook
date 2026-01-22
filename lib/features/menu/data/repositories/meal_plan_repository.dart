import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../models/meal_plan_model.dart';

/// 菜单计划仓库
class MealPlanRepository {
  final StorageService _storage;

  MealPlanRepository(this._storage);

  /// 获取家庭的所有菜单计划
  List<MealPlanModel> getMealPlansByFamily(String familyId) {
    return _storage.mealPlansBox.values
        .where((m) => m.familyId == familyId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 根据 ID 获取菜单计划
  MealPlanModel? getMealPlanById(String id) {
    return _storage.mealPlansBox.values.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('MealPlan not found'),
    );
  }

  /// 保存菜单计划
  Future<void> saveMealPlan(MealPlanModel mealPlan) async {
    await _storage.mealPlansBox.put(mealPlan.id, mealPlan);
  }

  /// 删除菜单计划
  Future<void> deleteMealPlan(String id) async {
    await _storage.mealPlansBox.delete(id);
  }

  /// 获取当前有效的菜单计划
  MealPlanModel? getCurrentMealPlan(String familyId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      return _storage.mealPlansBox.values.firstWhere((m) =>
          m.familyId == familyId &&
          !m.startDate.isAfter(today) &&
          !m.endDate.isBefore(today));
    } catch (_) {
      return null;
    }
  }

  /// 获取今日菜单
  DayPlanModel? getTodayPlan(String familyId) {
    final currentPlan = getCurrentMealPlan(familyId);
    if (currentPlan == null) return null;

    final today = DateTime.now();
    return currentPlan.getDayPlan(today);
  }

  /// 获取某日菜单
  DayPlanModel? getDayPlan(String familyId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    for (final plan in _storage.mealPlansBox.values) {
      if (plan.familyId == familyId) {
        final dayPlan = plan.getDayPlan(normalizedDate);
        if (dayPlan != null && dayPlan.meals.isNotEmpty) {
          return dayPlan;
        }
      }
    }
    return null;
  }

  /// 更新某日某餐的菜品
  Future<void> updateMeal(
    String mealPlanId,
    DateTime date,
    String mealType,
    List<String> recipeIds, {
    String? notes,
  }) async {
    final mealPlan = getMealPlanById(mealPlanId);
    if (mealPlan == null) return;

    final dayIndex = mealPlan.days.indexWhere(
      (d) => d.date.year == date.year &&
             d.date.month == date.month &&
             d.date.day == date.day,
    );

    if (dayIndex < 0) return;

    final mealIndex = mealPlan.days[dayIndex].meals.indexWhere(
      (m) => m.type == mealType,
    );

    final meal = MealModel(
      type: mealType,
      recipeIds: recipeIds,
      notes: notes,
    );

    if (mealIndex >= 0) {
      mealPlan.days[dayIndex].meals[mealIndex] = meal;
    } else {
      mealPlan.days[dayIndex].meals.add(meal);
    }

    await mealPlan.save();
  }

  /// 获取历史菜单计划
  List<MealPlanModel> getHistoryMealPlans(String familyId, {int limit = 10}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _storage.mealPlansBox.values
        .where((m) => m.familyId == familyId && m.endDate.isBefore(today))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
      ..take(limit);
  }

  /// 获取即将到来的菜单计划
  List<MealPlanModel> getUpcomingMealPlans(String familyId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _storage.mealPlansBox.values
        .where((m) => m.familyId == familyId && m.startDate.isAfter(today))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }
}

/// MealPlan Repository Provider
final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MealPlanRepository(storage);
});

/// 当前菜单计划 Provider
final currentMealPlanProvider = Provider.family<MealPlanModel?, String>((ref, familyId) {
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.getCurrentMealPlan(familyId);
});

/// 今日菜单 Provider
final todayPlanProvider = Provider.family<DayPlanModel?, String>((ref, familyId) {
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.getTodayPlan(familyId);
});

/// 历史菜单 Provider
final historyMealPlansProvider = Provider.family<List<MealPlanModel>, String>((ref, familyId) {
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.getHistoryMealPlans(familyId);
});
