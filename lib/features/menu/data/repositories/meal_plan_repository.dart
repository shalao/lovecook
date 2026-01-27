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
    try {
      return _storage.mealPlansBox.values.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 保存菜单计划
  Future<void> saveMealPlan(MealPlanModel mealPlan) async {
    await _storage.mealPlansBox.put(mealPlan.id, mealPlan);
  }

  /// 删除菜单计划
  Future<void> deleteMealPlan(String id) async {
    await _storage.mealPlansBox.delete(id);
  }

  /// 合并新菜单到现有菜单（按日期+餐次粒度）
  /// [newDays] - 新生成的天计划列表
  /// [replaceExisting] - true=覆盖同日期餐次, false=跳过已有
  Future<MealPlanModel> mergeMenuPlan({
    required String familyId,
    required List<DayPlanModel> newDays,
    required bool replaceExisting,
    String? notes,
    String? shoppingListId,
  }) async {
    // 获取现有菜单或创建新菜单
    MealPlanModel? existingPlan = getCurrentMealPlan(familyId);

    if (existingPlan == null) {
      // 没有现有菜单，直接创建新的
      final allDates = newDays.map((d) => d.date).toList();
      final startDate = allDates.reduce((a, b) => a.isBefore(b) ? a : b);
      final endDate = allDates.reduce((a, b) => a.isAfter(b) ? a : b);

      final plan = MealPlanModel.create(
        familyId: familyId,
        startDate: startDate,
        days: (endDate.difference(startDate).inDays + 1),
      );

      // 填充新的天计划
      for (final newDay in newDays) {
        final dayIndex = plan.days.indexWhere((d) =>
            d.date.year == newDay.date.year &&
            d.date.month == newDay.date.month &&
            d.date.day == newDay.date.day);
        if (dayIndex >= 0) {
          plan.days[dayIndex] = newDay;
        }
      }

      plan.notes = notes;
      plan.shoppingListId = shoppingListId;
      await saveMealPlan(plan);
      return plan;
    }

    // 合并到现有菜单
    for (final newDay in newDays) {
      final normalizedDate = DateTime(newDay.date.year, newDay.date.month, newDay.date.day);

      // 查找现有天计划
      final existingDayIndex = existingPlan.days.indexWhere((d) =>
          d.date.year == normalizedDate.year &&
          d.date.month == normalizedDate.month &&
          d.date.day == normalizedDate.day);

      if (existingDayIndex >= 0) {
        // 该日期已有计划，合并餐次
        final existingDay = existingPlan.days[existingDayIndex];

        for (final newMeal in newDay.meals) {
          final existingMealIndex = existingDay.meals.indexWhere(
              (m) => m.type == newMeal.type);

          if (existingMealIndex >= 0) {
            // 该餐次已有
            if (replaceExisting) {
              existingDay.meals[existingMealIndex] = newMeal;
            }
            // 如果不替换，则跳过
          } else {
            // 该餐次不存在，添加
            existingDay.meals.add(newMeal);
          }
        }
      } else {
        // 该日期没有计划，需要扩展菜单日期范围
        // 先检查日期是否在范围内
        if (normalizedDate.isBefore(existingPlan.startDate)) {
          // 扩展开始日期
          final daysToAdd = existingPlan.startDate.difference(normalizedDate).inDays;
          final newDaysList = <DayPlanModel>[];
          for (var i = 0; i < daysToAdd; i++) {
            final date = normalizedDate.add(Duration(days: i));
            if (date.year == newDay.date.year &&
                date.month == newDay.date.month &&
                date.day == newDay.date.day) {
              newDaysList.add(newDay);
            } else {
              newDaysList.add(DayPlanModel(date: date, meals: []));
            }
          }
          existingPlan.days.insertAll(0, newDaysList);
          existingPlan.startDate = normalizedDate;
        } else if (normalizedDate.isAfter(existingPlan.endDate)) {
          // 扩展结束日期
          final daysToAdd = normalizedDate.difference(existingPlan.endDate).inDays;
          for (var i = 1; i <= daysToAdd; i++) {
            final date = existingPlan.endDate.add(Duration(days: i));
            if (date.year == newDay.date.year &&
                date.month == newDay.date.month &&
                date.day == newDay.date.day) {
              existingPlan.days.add(newDay);
            } else {
              existingPlan.days.add(DayPlanModel(date: date, meals: []));
            }
          }
          existingPlan.endDate = normalizedDate;
        }
      }
    }

    if (notes != null) {
      existingPlan.notes = notes;
    }
    if (shoppingListId != null) {
      existingPlan.shoppingListId = shoppingListId;
    }

    await existingPlan.save();
    return existingPlan;
  }

  /// 删除指定日期的指定餐次
  Future<void> deleteMeals({
    required String familyId,
    required DateTime date,
    required List<String> mealTypes,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 查找包含该日期的菜单
    for (final plan in _storage.mealPlansBox.values) {
      if (plan.familyId != familyId) continue;

      final dayIndex = plan.days.indexWhere((d) =>
          d.date.year == normalizedDate.year &&
          d.date.month == normalizedDate.month &&
          d.date.day == normalizedDate.day);

      if (dayIndex < 0) continue;

      // 移除指定餐次
      plan.days[dayIndex].meals.removeWhere(
          (m) => mealTypes.contains(m.type));

      await plan.save();
      return;
    }
  }

  /// 删除指定日期指定餐次的单道菜
  Future<void> deleteRecipeFromMeal({
    required String familyId,
    required DateTime date,
    required String mealType,
    required int recipeIndex,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    for (final plan in _storage.mealPlansBox.values) {
      if (plan.familyId != familyId) continue;

      final dayIndex = plan.days.indexWhere((d) =>
          d.date.year == normalizedDate.year &&
          d.date.month == normalizedDate.month &&
          d.date.day == normalizedDate.day);

      if (dayIndex < 0) continue;

      final mealIndex = plan.days[dayIndex].meals.indexWhere(
          (m) => m.type.toLowerCase() == mealType.toLowerCase());

      if (mealIndex < 0) continue;

      final meal = plan.days[dayIndex].meals[mealIndex];
      if (recipeIndex >= 0 && recipeIndex < meal.recipeIds.length) {
        meal.recipeIds.removeAt(recipeIndex);

        // 更新 notes（移除对应菜名）
        if (meal.notes != null) {
          final names = meal.notes!.split('、');
          if (recipeIndex < names.length) {
            names.removeAt(recipeIndex);
            plan.days[dayIndex].meals[mealIndex] = MealModel(
              type: meal.type,
              recipeIds: meal.recipeIds,
              notes: names.join('、'),
            );
          }
        }

        await plan.save();
      }
      return;
    }
  }

  /// 替换指定日期指定餐次的单道菜
  Future<void> replaceRecipeInMeal({
    required String familyId,
    required DateTime date,
    required String mealType,
    required int recipeIndex,
    required String newRecipeId,
    required String newRecipeName,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    for (final plan in _storage.mealPlansBox.values) {
      if (plan.familyId != familyId) continue;

      final dayIndex = plan.days.indexWhere((d) =>
          d.date.year == normalizedDate.year &&
          d.date.month == normalizedDate.month &&
          d.date.day == normalizedDate.day);

      if (dayIndex < 0) continue;

      final mealIndex = plan.days[dayIndex].meals.indexWhere(
          (m) => m.type.toLowerCase() == mealType.toLowerCase());

      if (mealIndex < 0) continue;

      final meal = plan.days[dayIndex].meals[mealIndex];
      if (recipeIndex >= 0 && recipeIndex < meal.recipeIds.length) {
        meal.recipeIds[recipeIndex] = newRecipeId;

        // 更新 notes（替换对应菜名）
        if (meal.notes != null) {
          final names = meal.notes!.split('、');
          if (recipeIndex < names.length) {
            names[recipeIndex] = newRecipeName;
            plan.days[dayIndex].meals[mealIndex] = MealModel(
              type: meal.type,
              recipeIds: meal.recipeIds,
              notes: names.join('、'),
            );
          }
        }

        await plan.save();
      }
      return;
    }
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

  /// v1.2: 添加菜谱到指定日期和餐次
  Future<void> addRecipeToDate({
    required String familyId,
    required DateTime date,
    required String mealType,
    required dynamic recipe, // RecipeModel
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 获取或创建当前菜单
    MealPlanModel? plan = getCurrentMealPlan(familyId);

    if (plan == null) {
      // 创建新菜单
      plan = MealPlanModel.create(
        familyId: familyId,
        startDate: normalizedDate,
        days: 1,
      );
      await saveMealPlan(plan);
    }

    // 查找或扩展到包含目标日期
    final dayIndex = plan.days.indexWhere((d) =>
        d.date.year == normalizedDate.year &&
        d.date.month == normalizedDate.month &&
        d.date.day == normalizedDate.day);

    if (dayIndex >= 0) {
      // 日期已存在，添加到对应餐次
      final dayPlan = plan.days[dayIndex];
      final mealIndex = dayPlan.meals.indexWhere((m) => m.type == mealType);

      if (mealIndex >= 0) {
        // 餐次已存在，追加菜谱
        final meal = dayPlan.meals[mealIndex];
        meal.recipeIds.add(recipe.id);
        final names = meal.notes?.split('、') ?? [];
        names.add(recipe.name);
        dayPlan.meals[mealIndex] = MealModel(
          type: meal.type,
          recipeIds: meal.recipeIds,
          notes: names.join('、'),
        );
      } else {
        // 餐次不存在，创建新餐次
        dayPlan.meals.add(MealModel(
          type: mealType,
          recipeIds: [recipe.id],
          notes: recipe.name,
        ));
      }
    } else {
      // 日期不存在，需要扩展菜单
      if (normalizedDate.isBefore(plan.startDate)) {
        // 向前扩展
        final daysToAdd = plan.startDate.difference(normalizedDate).inDays;
        final newDays = <DayPlanModel>[];
        for (var i = 0; i < daysToAdd; i++) {
          final d = normalizedDate.add(Duration(days: i));
          if (d.year == normalizedDate.year &&
              d.month == normalizedDate.month &&
              d.day == normalizedDate.day) {
            // 目标日期
            newDays.add(DayPlanModel(
              date: d,
              meals: [
                MealModel(
                  type: mealType,
                  recipeIds: [recipe.id],
                  notes: recipe.name,
                ),
              ],
            ));
          } else {
            newDays.add(DayPlanModel(date: d, meals: []));
          }
        }
        plan.days.insertAll(0, newDays);
        plan.startDate = normalizedDate;
      } else {
        // 向后扩展
        final daysToAdd = normalizedDate.difference(plan.endDate).inDays;
        for (var i = 1; i <= daysToAdd; i++) {
          final d = plan.endDate.add(Duration(days: i));
          if (d.year == normalizedDate.year &&
              d.month == normalizedDate.month &&
              d.day == normalizedDate.day) {
            // 目标日期
            plan.days.add(DayPlanModel(
              date: d,
              meals: [
                MealModel(
                  type: mealType,
                  recipeIds: [recipe.id],
                  notes: recipe.name,
                ),
              ],
            ));
          } else {
            plan.days.add(DayPlanModel(date: d, meals: []));
          }
        }
        plan.endDate = normalizedDate;
      }
    }

    await plan.save();
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

  /// 从菜单中移除指定菜谱（用于标记已吃后清理推荐）
  /// [recipeId] - 菜谱ID
  /// [date] - 可选，限定日期（null则搜索所有日期）
  /// [mealType] - 可选，限定餐次（null则搜索所有餐次）
  Future<bool> removeRecipeFromPlan({
    required String familyId,
    required String recipeId,
    DateTime? date,
    String? mealType,
  }) async {
    bool removed = false;
    final normalizedDate = date != null
        ? DateTime(date.year, date.month, date.day)
        : null;

    for (final plan in _storage.mealPlansBox.values) {
      if (plan.familyId != familyId) continue;

      for (final dayPlan in plan.days) {
        // 如果指定了日期，检查日期是否匹配
        if (normalizedDate != null &&
            (dayPlan.date.year != normalizedDate.year ||
             dayPlan.date.month != normalizedDate.month ||
             dayPlan.date.day != normalizedDate.day)) {
          continue;
        }

        for (final meal in dayPlan.meals) {
          // 如果指定了餐次，检查餐次是否匹配
          if (mealType != null &&
              meal.type.toLowerCase() != mealType.toLowerCase()) {
            continue;
          }

          final index = meal.recipeIds.indexOf(recipeId);
          if (index >= 0) {
            meal.recipeIds.removeAt(index);
            // 同步更新 notes
            if (meal.notes != null) {
              final names = meal.notes!.split('、');
              if (index < names.length) {
                names.removeAt(index);
                // 由于 MealModel 的 notes 是 final，需要重建
                final mealIndex = dayPlan.meals.indexOf(meal);
                dayPlan.meals[mealIndex] = MealModel(
                  type: meal.type,
                  recipeIds: meal.recipeIds,
                  notes: names.isEmpty ? null : names.join('、'),
                );
              }
            }
            removed = true;
          }
        }
      }

      if (removed) {
        await plan.save();
      }
    }

    return removed;
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
