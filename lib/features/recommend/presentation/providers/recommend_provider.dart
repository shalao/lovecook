import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ai_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../family/data/models/family_model.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../history/data/repositories/meal_history_repository.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../data/models/recommend_settings.dart';

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

/// 一天的菜单计划
class DayPlan {
  final int dayIndex; // 第几天 (0-based)
  final DateTime date; // 日期
  final MealRecommend breakfast;
  final MealRecommend lunch;
  final MealRecommend dinner;
  final MealRecommend snacks;

  const DayPlan({
    required this.dayIndex,
    required this.date,
    this.breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐'),
    this.lunch = const MealRecommend(type: 'lunch', typeName: '午餐'),
    this.dinner = const MealRecommend(type: 'dinner', typeName: '晚餐'),
    this.snacks = const MealRecommend(type: 'snacks', typeName: '甜点'),
  });

  String get dayLabel {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == 2) return '后天';
    return '第${dayIndex + 1}天';
  }

  String get dateLabel {
    return '${date.month}月${date.day}日';
  }

  bool get hasAnyRecipes =>
      breakfast.recipes.isNotEmpty ||
      lunch.recipes.isNotEmpty ||
      dinner.recipes.isNotEmpty ||
      snacks.recipes.isNotEmpty;

  DayPlan copyWith({
    int? dayIndex,
    DateTime? date,
    MealRecommend? breakfast,
    MealRecommend? lunch,
    MealRecommend? dinner,
    MealRecommend? snacks,
  }) {
    return DayPlan(
      dayIndex: dayIndex ?? this.dayIndex,
      date: date ?? this.date,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snacks: snacks ?? this.snacks,
    );
  }
}

/// 今日推荐状态
class RecommendState {
  final MealRecommend breakfast;
  final MealRecommend lunch;
  final MealRecommend dinner;
  final MealRecommend snacks;
  final List<DayPlan> dayPlans; // 多天计划
  final bool isInitialLoading;
  final String? globalError;
  final RecommendSettings settings;

  const RecommendState({
    this.breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐'),
    this.lunch = const MealRecommend(type: 'lunch', typeName: '午餐'),
    this.dinner = const MealRecommend(type: 'dinner', typeName: '晚餐'),
    this.snacks = const MealRecommend(type: 'snacks', typeName: '甜点'),
    this.dayPlans = const [],
    this.isInitialLoading = false,
    this.globalError,
    this.settings = const RecommendSettings(),
  });

  RecommendState copyWith({
    MealRecommend? breakfast,
    MealRecommend? lunch,
    MealRecommend? dinner,
    MealRecommend? snacks,
    List<DayPlan>? dayPlans,
    bool? isInitialLoading,
    String? globalError,
    bool clearGlobalError = false,
    RecommendSettings? settings,
  }) {
    return RecommendState(
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snacks: snacks ?? this.snacks,
      dayPlans: dayPlans ?? this.dayPlans,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      globalError: clearGlobalError ? null : (globalError ?? this.globalError),
      settings: settings ?? this.settings,
    );
  }

  bool get hasAnyRecommendation =>
      dayPlans.any((d) => d.hasAnyRecipes) ||
      breakfast.recipes.isNotEmpty ||
      lunch.recipes.isNotEmpty ||
      dinner.recipes.isNotEmpty ||
      snacks.recipes.isNotEmpty;

  bool get isAnyLoading =>
      isInitialLoading ||
      breakfast.isLoading ||
      lunch.isLoading ||
      dinner.isLoading ||
      snacks.isLoading;

  /// 是否为多天计划
  bool get isMultiDay => dayPlans.length > 1;

  /// 获取指定餐次的推荐
  MealRecommend getMealByType(String type) {
    switch (type) {
      case 'breakfast':
        return breakfast;
      case 'lunch':
        return lunch;
      case 'dinner':
        return dinner;
      case 'snacks':
        return snacks;
      default:
        return breakfast;
    }
  }
}

/// 今日推荐通知器
class RecommendNotifier extends StateNotifier<RecommendState> {
  final AIService _aiService;
  final FamilyModel? _currentFamily;
  final List<IngredientModel> _inventory;
  final MealHistoryRepository _historyRepository;
  final RecipeRepository _recipeRepository;
  final StorageService _storage;

  RecommendNotifier({
    required AIService aiService,
    required FamilyModel? currentFamily,
    required List<IngredientModel> inventory,
    required MealHistoryRepository historyRepository,
    required RecipeRepository recipeRepository,
    required StorageService storage,
  })  : _aiService = aiService,
        _currentFamily = currentFamily,
        _inventory = inventory,
        _historyRepository = historyRepository,
        _recipeRepository = recipeRepository,
        _storage = storage,
        super(RecommendState(
          settings: currentFamily != null
              ? RecommendSettings.withFamilySize(currentFamily.members.length)
              : const RecommendSettings(),
        ));

  /// 获取避重天数设置
  int get _avoidRecentDays {
    return _storage.settingsBox.get('avoidRecentDays', defaultValue: 7) as int;
  }

  /// 更新推荐设置
  void updateSettings(RecommendSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  /// 更新天数
  void updateDays(int days) {
    state = state.copyWith(
      settings: state.settings.copyWith(days: days),
    );
  }

  /// 更新餐次开关
  void updateMealType({
    bool? breakfast,
    bool? lunch,
    bool? dinner,
    bool? snacks,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        breakfast: breakfast,
        lunch: lunch,
        dinner: dinner,
        snacks: snacks,
      ),
    );
  }

  /// 更新每餐菜品数
  void updateDishesPerMeal(int dishes) {
    state = state.copyWith(
      settings: state.settings.copyWith(dishesPerMeal: dishes),
    );
  }

  /// 更新心情输入
  void updateMoodInput(String? moodInput) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        moodInput: moodInput,
        clearMoodInput: moodInput == null || moodInput.isEmpty,
      ),
    );
  }

  /// 添加快捷标签到心情输入
  void addMoodTag(String tag) {
    final currentMood = state.settings.moodInput ?? '';
    final newMood = currentMood.isEmpty ? tag : '$currentMood、$tag';
    state = state.copyWith(
      settings: state.settings.copyWith(moodInput: newMood),
    );
  }

  /// 清除心情输入
  void clearMoodInput() {
    state = state.copyWith(
      settings: state.settings.copyWith(clearMoodInput: true),
    );
  }

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

    final settings = state.settings;
    if (!settings.hasSelectedMealType) {
      state = state.copyWith(globalError: '请至少选择一个餐次');
      return;
    }

    state = state.copyWith(isInitialLoading: true, clearGlobalError: true);

    try {
      // 获取偏好数据
      final recentRecipeNames = _historyRepository.getRecentRecipeNames(
        _currentFamily!.id,
        _avoidRecentDays,
      );
      final likedRecipes = _historyRepository.getLikedRecipes(_currentFamily!.id);
      final dislikedRecipes = _historyRepository.getDislikedRecipes(_currentFamily!.id);
      final favoriteRecipes = _recipeRepository.getFavoriteRecipeNames(_currentFamily!.id);

      final result = await _aiService.generateMealPlan(
        family: _currentFamily!,
        inventory: _inventory,
        days: settings.days,
        mealTypes: settings.selectedMealTypes,
        dishesPerMeal: settings.dishesPerMeal,
        moodInput: settings.moodInput,
        recentRecipeNames: recentRecipeNames,
        likedRecipes: likedRecipes,
        dislikedRecipes: dislikedRecipes,
        favoriteRecipes: favoriteRecipes,
      );

      // 解析结果 - 按天分组
      final dayPlans = <DayPlan>[];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (result.days.isNotEmpty) {
        for (int i = 0; i < result.days.length; i++) {
          final dayData = result.days[i];
          final date = today.add(Duration(days: i));

          MealRecommend breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐');
          MealRecommend lunch = const MealRecommend(type: 'lunch', typeName: '午餐');
          MealRecommend dinner = const MealRecommend(type: 'dinner', typeName: '晚餐');
          MealRecommend snacks = const MealRecommend(type: 'snacks', typeName: '甜点');

          for (final meal in dayData.meals) {
            // 转换并保存菜谱到数据库
            final recipes = <RecipeModel>[];
            for (final r in meal.recipes) {
              final recipe = _convertToRecipeModel(r);
              await _recipeRepository.saveRecipe(recipe);
              recipes.add(recipe);
            }
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
              case 'snack':
              case 'snacks':
              case '加餐':
              case '甜点':
                snacks = snacks.copyWith(recipes: recipes);
                break;
            }
          }

          dayPlans.add(DayPlan(
            dayIndex: i,
            date: date,
            breakfast: breakfast,
            lunch: lunch,
            dinner: dinner,
            snacks: snacks,
          ));
        }
      }

      // 检查是否有结果
      if (dayPlans.isEmpty) {
        state = state.copyWith(
          isInitialLoading: false,
          globalError: 'AI 未能生成有效菜单，请重试',
        );
        return;
      }

      // 设置第一天数据到兼容字段（向后兼容）
      final firstDay = dayPlans.first;

      state = state.copyWith(
        breakfast: firstDay.breakfast,
        lunch: firstDay.lunch,
        dinner: firstDay.dinner,
        snacks: firstDay.snacks,
        dayPlans: dayPlans,
        isInitialLoading: false,
        clearGlobalError: true,
      );
    } on AIServiceException catch (e) {
      state = state.copyWith(isInitialLoading: false, globalError: e.message);
    } catch (e, stackTrace) {
      // 打印详细错误用于调试
      print('生成推荐失败: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(isInitialLoading: false, globalError: '生成推荐失败，请检查网络后重试');
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
      case 'snacks':
        state = state.copyWith(
          snacks: state.snacks.copyWith(isLoading: true, clearError: true),
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
        dishesPerMeal: state.settings.dishesPerMeal,
        moodInput: state.settings.moodInput,
      );

      if (result.days.isNotEmpty && result.days.first.meals.isNotEmpty) {
        // 转换并保存菜谱到数据库
        final recipes = <RecipeModel>[];
        for (final r in result.days.first.meals.first.recipes) {
          final recipe = _convertToRecipeModel(r);
          await _recipeRepository.saveRecipe(recipe);
          recipes.add(recipe);
        }

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
          case 'snacks':
            state = state.copyWith(
              snacks: state.snacks.copyWith(recipes: recipes, isLoading: false),
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
      case 'snacks':
        state = state.copyWith(
          snacks: state.snacks.copyWith(isLoading: false, error: error),
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
      case 'snacks':
        return '加餐';
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
  final historyRepository = ref.watch(mealHistoryRepositoryProvider);
  final recipeRepository = ref.watch(recipeRepositoryProvider);
  final storage = ref.watch(storageServiceProvider);

  return RecommendNotifier(
    aiService: aiService,
    currentFamily: currentFamily,
    inventory: inventoryState.ingredients,
    historyRepository: historyRepository,
    recipeRepository: recipeRepository,
    storage: storage,
  );
});
