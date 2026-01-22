import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../models/meal_history_model.dart';

/// 用餐历史数据仓库
class MealHistoryRepository {
  final StorageService _storage;

  MealHistoryRepository(this._storage);

  /// 获取所有历史记录
  List<MealHistoryModel> getAllHistory() {
    return _storage.mealHistoryBox.values.toList();
  }

  /// 获取某个家庭的所有历史记录
  List<MealHistoryModel> getHistoryByFamily(String familyId) {
    return _storage.mealHistoryBox.values
        .where((h) => h.familyId == familyId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 根据日期获取历史记录
  List<MealHistoryModel> getHistoryByDate(String familyId, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _storage.mealHistoryBox.values
        .where((h) =>
            h.familyId == familyId &&
            h.date.year == targetDate.year &&
            h.date.month == targetDate.month &&
            h.date.day == targetDate.day)
        .toList()
      ..sort((a, b) => _mealTypeOrder(a.mealType).compareTo(_mealTypeOrder(b.mealType)));
  }

  /// 获取日期范围内的历史记录
  List<MealHistoryModel> getHistoryByDateRange(
    String familyId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return _storage.mealHistoryBox.values
        .where((h) =>
            h.familyId == familyId &&
            h.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            h.date.isBefore(end.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 获取最近N天吃过的菜品名称
  List<String> getRecentRecipeNames(String familyId, int days) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final history = getHistoryByDateRange(familyId, startDate, endDate);
    final recipeNames = <String>{};

    for (final h in history) {
      for (final r in h.recipes) {
        recipeNames.add(r.recipeName);
      }
    }

    return recipeNames.toList();
  }

  /// 获取有历史记录的日期列表
  List<DateTime> getDatesWithHistory(String familyId, {int? year, int? month}) {
    final dates = <DateTime>{};

    for (final h in _storage.mealHistoryBox.values) {
      if (h.familyId != familyId) continue;
      if (year != null && h.date.year != year) continue;
      if (month != null && h.date.month != month) continue;

      dates.add(DateTime(h.date.year, h.date.month, h.date.day));
    }

    return dates.toList()..sort();
  }

  /// 保存历史记录
  Future<void> saveHistory(MealHistoryModel history) async {
    await _storage.mealHistoryBox.put(history.id, history);
  }

  /// 添加一条用餐记录
  Future<MealHistoryModel> addMealHistory({
    required String familyId,
    required DateTime date,
    required String mealType,
    required String recipeId,
    required String recipeName,
  }) async {
    // 检查是否已有该日期和餐次的记录
    final existing = _storage.mealHistoryBox.values.firstWhere(
      (h) =>
          h.familyId == familyId &&
          h.date.year == date.year &&
          h.date.month == date.month &&
          h.date.day == date.day &&
          h.mealType == mealType,
      orElse: () => MealHistoryModel.create(
        familyId: familyId,
        date: date,
        mealType: mealType,
        recipes: [],
      ),
    );

    // 检查菜品是否已存在
    final recipeExists = existing.recipes.any((r) => r.recipeId == recipeId);
    if (!recipeExists) {
      existing.recipes.add(MealHistoryRecipeModel.fromRecipe(
        recipeId: recipeId,
        recipeName: recipeName,
      ));
      existing.updatedAt = DateTime.now();
      await _storage.mealHistoryBox.put(existing.id, existing);
    }

    return existing;
  }

  /// 更新菜品评价
  Future<void> updateRecipeRating({
    required String historyId,
    required String recipeId,
    required int? rating,
    String? comment,
  }) async {
    final history = _storage.mealHistoryBox.get(historyId);
    if (history == null) return;

    final recipeIndex = history.recipes.indexWhere((r) => r.recipeId == recipeId);
    if (recipeIndex < 0) return;

    history.recipes[recipeIndex] = history.recipes[recipeIndex].copyWith(
      rating: rating,
      comment: comment,
      clearRating: rating == null,
    );
    history.updatedAt = DateTime.now();
    await history.save();
  }

  /// 删除历史记录
  Future<void> deleteHistory(String id) async {
    await _storage.mealHistoryBox.delete(id);
  }

  /// 从历史记录中移除菜品
  Future<void> removeRecipeFromHistory({
    required String historyId,
    required String recipeId,
  }) async {
    final history = _storage.mealHistoryBox.get(historyId);
    if (history == null) return;

    history.recipes.removeWhere((r) => r.recipeId == recipeId);

    if (history.recipes.isEmpty) {
      await _storage.mealHistoryBox.delete(historyId);
    } else {
      history.updatedAt = DateTime.now();
      await history.save();
    }
  }

  /// 获取用户喜欢的菜品（评分4-5）
  List<String> getLikedRecipes(String familyId) {
    final likedRecipes = <String>{};

    for (final h in _storage.mealHistoryBox.values) {
      if (h.familyId != familyId) continue;
      for (final r in h.recipes) {
        if (r.rating != null && r.rating! >= 4) {
          likedRecipes.add(r.recipeName);
        }
      }
    }

    return likedRecipes.toList();
  }

  /// 获取用户不喜欢的菜品（评分1-2）
  List<String> getDislikedRecipes(String familyId) {
    final dislikedRecipes = <String>{};

    for (final h in _storage.mealHistoryBox.values) {
      if (h.familyId != familyId) continue;
      for (final r in h.recipes) {
        if (r.rating != null && r.rating! <= 2) {
          dislikedRecipes.add(r.recipeName);
        }
      }
    }

    return dislikedRecipes.toList();
  }

  /// 餐次排序顺序
  int _mealTypeOrder(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 0;
      case 'lunch':
        return 1;
      case 'dinner':
        return 2;
      case 'snacks':
        return 3;
      default:
        return 4;
    }
  }
}

/// MealHistory Repository Provider
final mealHistoryRepositoryProvider = Provider<MealHistoryRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MealHistoryRepository(storage);
});
