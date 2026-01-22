import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ai_service.dart';
import '../../../family/data/models/family_model.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../recipe/data/models/recipe_model.dart';

/// 单餐推荐数据
class MealRecommend {
  final String type; // breakfast, lunch, dinner
  final String typeName; // 早餐, 午餐, 晚餐
  final List<RecipeModel> recipes;
  final bool isLoading;
  final String? error;

  const MealRecommend({
    required this.type,
    required this.typeName,
    this.recipes = const [],
    this.isLoading = false,
    this.error,
  });

  MealRecommend copyWith({
    String? type,
    String? typeName,
    List<RecipeModel>? recipes,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MealRecommend(
      type: type ?? this.type,
      typeName: typeName ?? this.typeName,
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 今日推荐状态
class RecommendState {
  final MealRecommend breakfast;
  final MealRecommend lunch;
  final MealRecommend dinner;
  final bool isInitialLoading;
  final String? globalError;

  const RecommendState({
    this.breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐'),
    this.lunch = const MealRecommend(type: 'lunch', typeName: '午餐'),
    this.dinner = const MealRecommend(type: 'dinner', typeName: '晚餐'),
    this.isInitialLoading = false,
    this.globalError,
  });

  RecommendState copyWith({
    MealRecommend? breakfast,
    MealRecommend? lunch,
    MealRecommend? dinner,
    bool? isInitialLoading,
    String? globalError,
    bool clearGlobalError = false,
  }) {
    return RecommendState(
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      globalError: clearGlobalError ? null : (globalError ?? this.globalError),
    );
  }

  bool get hasAnyRecommendation =>
      breakfast.recipes.isNotEmpty ||
      lunch.recipes.isNotEmpty ||
      dinner.recipes.isNotEmpty;

  bool get isAnyLoading =>
      isInitialLoading ||
      breakfast.isLoading ||
      lunch.isLoading ||
      dinner.isLoading;
}

/// 今日推荐通知器
class RecommendNotifier extends StateNotifier<RecommendState> {
  final AIService _aiService;
  final FamilyModel? _currentFamily;
  final List<IngredientModel> _inventory;

  RecommendNotifier({
    required AIService aiService,
    required FamilyModel? currentFamily,
    required List<IngredientModel> inventory,
  })  : _aiService = aiService,
        _currentFamily = currentFamily,
        _inventory = inventory,
        super(const RecommendState());

  /// 生成今日推荐（全部餐次）
  Future<void> generateTodayRecommendations() async {
    if (_currentFamily == null) {
      state = state.copyWith(globalError: '请先创建家庭档案');
      return;
    }

    if (!_aiService.config.isConfigured) {
      state = state.copyWith(globalError: '请先配置 API 密钥');
      return;
    }

    state = state.copyWith(isInitialLoading: true, clearGlobalError: true);

    try {
      final result = await _aiService.generateMealPlan(
        family: _currentFamily!,
        inventory: _inventory,
        days: 1,
        mealTypes: ['早餐', '午餐', '晚餐'],
        dishesPerMeal: 2,
      );

      // 解析结果
      MealRecommend breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐');
      MealRecommend lunch = const MealRecommend(type: 'lunch', typeName: '午餐');
      MealRecommend dinner = const MealRecommend(type: 'dinner', typeName: '晚餐');

      if (result.days.isNotEmpty) {
        final dayData = result.days.first;
        for (final meal in dayData.meals) {
          final recipes = meal.recipes.map((r) => _convertToRecipeModel(r)).toList();
          switch (meal.type.toLowerCase()) {
            case 'breakfast':
            case '早餐':
              breakfast = breakfast.copyWith(recipes: recipes);
              break;
            case 'lunch':
            case '午餐':
              lunch = lunch.copyWith(recipes: recipes);
              break;
            case 'dinner':
            case '晚餐':
              dinner = dinner.copyWith(recipes: recipes);
              break;
          }
        }
      }

      state = state.copyWith(
        breakfast: breakfast,
        lunch: lunch,
        dinner: dinner,
        isInitialLoading: false,
      );
    } on AIServiceException catch (e) {
      state = state.copyWith(isInitialLoading: false, globalError: e.message);
    } catch (e) {
      state = state.copyWith(isInitialLoading: false, globalError: '生成推荐失败：$e');
    }
  }

  /// 刷新单个餐次
  Future<void> refreshMeal(String mealType) async {
    if (_currentFamily == null || !_aiService.config.isConfigured) {
      return;
    }

    // 设置对应餐次为加载中
    switch (mealType) {
      case 'breakfast':
        state = state.copyWith(
          breakfast: state.breakfast.copyWith(isLoading: true, clearError: true),
        );
        break;
      case 'lunch':
        state = state.copyWith(
          lunch: state.lunch.copyWith(isLoading: true, clearError: true),
        );
        break;
      case 'dinner':
        state = state.copyWith(
          dinner: state.dinner.copyWith(isLoading: true, clearError: true),
        );
        break;
    }

    try {
      final mealTypeName = _getMealTypeName(mealType);
      final result = await _aiService.generateMealPlan(
        family: _currentFamily!,
        inventory: _inventory,
        days: 1,
        mealTypes: [mealTypeName],
        dishesPerMeal: 2,
      );

      if (result.days.isNotEmpty && result.days.first.meals.isNotEmpty) {
        final recipes = result.days.first.meals.first.recipes
            .map((r) => _convertToRecipeModel(r))
            .toList();

        switch (mealType) {
          case 'breakfast':
            state = state.copyWith(
              breakfast: state.breakfast.copyWith(recipes: recipes, isLoading: false),
            );
            break;
          case 'lunch':
            state = state.copyWith(
              lunch: state.lunch.copyWith(recipes: recipes, isLoading: false),
            );
            break;
          case 'dinner':
            state = state.copyWith(
              dinner: state.dinner.copyWith(recipes: recipes, isLoading: false),
            );
            break;
        }
      }
    } on AIServiceException catch (e) {
      _setMealError(mealType, e.message);
    } catch (e) {
      _setMealError(mealType, '刷新失败');
    }
  }

  void _setMealError(String mealType, String error) {
    switch (mealType) {
      case 'breakfast':
        state = state.copyWith(
          breakfast: state.breakfast.copyWith(isLoading: false, error: error),
        );
        break;
      case 'lunch':
        state = state.copyWith(
          lunch: state.lunch.copyWith(isLoading: false, error: error),
        );
        break;
      case 'dinner':
        state = state.copyWith(
          dinner: state.dinner.copyWith(isLoading: false, error: error),
        );
        break;
    }
  }

  String _getMealTypeName(String type) {
    switch (type) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      default:
        return type;
    }
  }

  RecipeModel _convertToRecipeModel(Map<String, dynamic> data) {
    final ingredients = (data['ingredients'] as List?)
            ?.map((i) => RecipeIngredientModel(
                  name: i['name'] as String,
                  quantity: (i['quantity'] as num).toDouble(),
                  unit: i['unit'] as String,
                  isOptional: i['isOptional'] as bool? ?? false,
                  substitute: i['substitute'] as String?,
                ))
            .toList() ??
        [];

    final nutritionData = data['nutrition'] as Map<String, dynamic>?;
    final nutrition = nutritionData != null
        ? NutritionInfoModel(
            calories: (nutritionData['calories'] as num?)?.toDouble(),
            protein: (nutritionData['protein'] as num?)?.toDouble(),
            carbs: (nutritionData['carbs'] as num?)?.toDouble(),
            fat: (nutritionData['fat'] as num?)?.toDouble(),
            fiber: (nutritionData['fiber'] as num?)?.toDouble(),
            summary: nutritionData['summary'] as String?,
          )
        : null;

    return RecipeModel.create(
      familyId: _currentFamily?.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      prepTime: data['prepTime'] as int? ?? 0,
      cookTime: data['cookTime'] as int? ?? 0,
      servings: data['servings'] as int? ?? 2,
      ingredients: ingredients,
      steps: (data['steps'] as List?)?.cast<String>() ?? [],
      tips: data['tips'] as String?,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      difficulty: data['difficulty'] as String?,
      nutrition: nutrition,
    );
  }

  /// 检查食材库存状态
  List<String> getMissingIngredients(RecipeModel recipe) {
    final inventoryNames = _inventory.map((i) => i.name.toLowerCase()).toSet();
    return recipe.ingredients
        .where((ing) => !ing.isOptional)
        .where((ing) => !inventoryNames.contains(ing.name.toLowerCase()))
        .map((ing) => ing.name)
        .toList();
  }

  /// 检查是否食材齐全
  bool hasAllIngredients(RecipeModel recipe) {
    return getMissingIngredients(recipe).isEmpty;
  }
}

/// 今日推荐 Provider
final recommendProvider =
    StateNotifierProvider<RecommendNotifier, RecommendState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final currentFamily = ref.watch(currentFamilyProvider);
  final inventoryState = ref.watch(inventoryProvider);

  return RecommendNotifier(
    aiService: aiService,
    currentFamily: currentFamily,
    inventory: inventoryState.ingredients,
  );
});
