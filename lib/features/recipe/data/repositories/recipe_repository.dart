import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../models/recipe_model.dart';

/// 菜谱仓库
class RecipeRepository {
  final StorageService _storage;

  RecipeRepository(this._storage);

  /// 获取所有菜谱
  List<RecipeModel> getAllRecipes() {
    return _storage.recipesBox.values.toList();
  }

  /// 获取家庭菜谱（包括通用菜谱）
  List<RecipeModel> getRecipesForFamily(String? familyId) {
    return _storage.recipesBox.values
        .where((r) => r.familyId == null || r.familyId == familyId)
        .toList();
  }

  /// 根据 ID 获取菜谱
  RecipeModel? getRecipeById(String id) {
    try {
      return _storage.recipesBox.values.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 保存菜谱
  Future<void> saveRecipe(RecipeModel recipe) async {
    await _storage.recipesBox.put(recipe.id, recipe);
  }

  /// 删除菜谱
  Future<void> deleteRecipe(String id) async {
    await _storage.recipesBox.delete(id);
  }

  /// 获取收藏菜谱
  List<RecipeModel> getFavoriteRecipes(String? familyId) {
    return _storage.recipesBox.values
        .where((r) =>
            r.isFavorite &&
            (r.familyId == null || r.familyId == familyId))
        .toList();
  }

  /// 获取收藏菜谱名称列表
  List<String> getFavoriteRecipeNames(String? familyId) {
    return getFavoriteRecipes(familyId).map((r) => r.name).toList();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String id) async {
    final recipe = getRecipeById(id);
    if (recipe != null) {
      recipe.toggleFavorite();
      await recipe.save();
    }
  }

  /// 按标签搜索菜谱
  List<RecipeModel> searchByTags(List<String> tags, {String? familyId}) {
    return _storage.recipesBox.values
        .where((r) =>
            (r.familyId == null || r.familyId == familyId) &&
            tags.any((tag) => r.tags.contains(tag)))
        .toList();
  }

  /// 按名称搜索菜谱
  List<RecipeModel> searchByName(String query, {String? familyId}) {
    final lowercaseQuery = query.toLowerCase();
    return _storage.recipesBox.values
        .where((r) =>
            (r.familyId == null || r.familyId == familyId) &&
            (r.name.toLowerCase().contains(lowercaseQuery) ||
                (r.description?.toLowerCase().contains(lowercaseQuery) ?? false)))
        .toList();
  }

  /// 按难度获取菜谱
  List<RecipeModel> getRecipesByDifficulty(String difficulty, {String? familyId}) {
    return _storage.recipesBox.values
        .where((r) =>
            (r.familyId == null || r.familyId == familyId) &&
            r.difficulty == difficulty)
        .toList();
  }

  /// 获取快手菜（总时间 <= 30分钟）
  List<RecipeModel> getQuickRecipes({String? familyId, int maxMinutes = 30}) {
    return _storage.recipesBox.values
        .where((r) =>
            (r.familyId == null || r.familyId == familyId) &&
            r.totalTime <= maxMinutes)
        .toList();
  }

  /// 根据食材查找可做菜谱
  List<RecipeModel> findRecipesWithIngredients(
    List<String> availableIngredients, {
    String? familyId,
    double matchThreshold = 0.7, // 至少匹配70%的食材
  }) {
    final available = availableIngredients.map((e) => e.toLowerCase()).toSet();

    return _storage.recipesBox.values.where((r) {
      if (r.familyId != null && r.familyId != familyId) return false;

      final requiredIngredients = r.ingredients
          .where((i) => !i.isOptional)
          .map((i) => i.name.toLowerCase())
          .toSet();

      if (requiredIngredients.isEmpty) return false;

      final matched = requiredIngredients.intersection(available);
      return matched.length / requiredIngredients.length >= matchThreshold;
    }).toList();
  }
}

/// Recipe Repository Provider
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecipeRepository(storage);
});

/// 所有菜谱 Provider
final allRecipesProvider = Provider<List<RecipeModel>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getAllRecipes();
});

/// 收藏菜谱 Provider
final favoriteRecipesProvider = Provider.family<List<RecipeModel>, String?>((ref, familyId) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getFavoriteRecipes(familyId);
});

/// 快手菜 Provider
final quickRecipesProvider = Provider.family<List<RecipeModel>, String?>((ref, familyId) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getQuickRecipes(familyId: familyId);
});

/// 根据 ID 获取菜谱 Provider
final recipeByIdProvider = Provider.family<RecipeModel?, String>((ref, id) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getRecipeById(id);
});
