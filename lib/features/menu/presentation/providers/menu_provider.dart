import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ai_service.dart';
import '../../../family/data/models/family_model.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../../shopping/data/models/shopping_list_model.dart';
import '../../../shopping/data/repositories/shopping_list_repository.dart';
import '../../data/models/meal_plan_model.dart';
import '../../data/repositories/meal_plan_repository.dart';

/// 菜单生成设置
class MenuGenerateSettings {
  final int days;
  final bool breakfast;
  final bool lunch;
  final bool dinner;
  final bool snacks;
  final int dishesPerMeal;

  const MenuGenerateSettings({
    this.days = 7,
    this.breakfast = true,
    this.lunch = true,
    this.dinner = true,
    this.snacks = false,
    this.dishesPerMeal = 2,
  });

  MenuGenerateSettings copyWith({
    int? days,
    bool? breakfast,
    bool? lunch,
    bool? dinner,
    bool? snacks,
    int? dishesPerMeal,
  }) {
    return MenuGenerateSettings(
      days: days ?? this.days,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snacks: snacks ?? this.snacks,
      dishesPerMeal: dishesPerMeal ?? this.dishesPerMeal,
    );
  }

  List<String> get selectedMealTypes {
    final types = <String>[];
    if (breakfast) types.add('早餐');
    if (lunch) types.add('午餐');
    if (dinner) types.add('晚餐');
    if (snacks) types.add('加餐');
    return types;
  }

  bool get hasAnyMealSelected => breakfast || lunch || dinner || snacks;
}

/// 菜单生成状态
class MenuGenerateState {
  final MenuGenerateSettings settings;
  final bool isGenerating;
  final MenuPlanResult? result;
  final String? error;

  const MenuGenerateState({
    this.settings = const MenuGenerateSettings(),
    this.isGenerating = false,
    this.result,
    this.error,
  });

  MenuGenerateState copyWith({
    MenuGenerateSettings? settings,
    bool? isGenerating,
    MenuPlanResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return MenuGenerateState(
      settings: settings ?? this.settings,
      isGenerating: isGenerating ?? this.isGenerating,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 菜单生成通知器
class MenuGenerateNotifier extends StateNotifier<MenuGenerateState> {
  final AIService _aiService;
  final FamilyModel? _currentFamily;
  final List<IngredientModel> _inventory;
  final MealPlanRepository _repository;
  final RecipeRepository _recipeRepository;
  final ShoppingListRepository _shoppingListRepository;

  MenuGenerateNotifier({
    required AIService aiService,
    required FamilyModel? currentFamily,
    required List<IngredientModel> inventory,
    required MealPlanRepository repository,
    required RecipeRepository recipeRepository,
    required ShoppingListRepository shoppingListRepository,
  })  : _aiService = aiService,
        _currentFamily = currentFamily,
        _inventory = inventory,
        _repository = repository,
        _recipeRepository = recipeRepository,
        _shoppingListRepository = shoppingListRepository,
        super(const MenuGenerateState());

  void setDays(int days) {
    state = state.copyWith(
      settings: state.settings.copyWith(days: days),
      clearError: true,
    );
  }

  void setBreakfast(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(breakfast: value),
    );
  }

  void setLunch(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(lunch: value),
    );
  }

  void setDinner(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(dinner: value),
    );
  }

  void setSnacks(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(snacks: value),
    );
  }

  void setDishesPerMeal(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(dishesPerMeal: value),
    );
  }

  Future<void> generateMenu() async {
    final family = _currentFamily;
    if (family == null) {
      state = state.copyWith(error: '请先创建家庭');
      return;
    }

    if (!state.settings.hasAnyMealSelected) {
      state = state.copyWith(error: '请至少选择一个餐次');
      return;
    }

    state = state.copyWith(isGenerating: true, clearError: true, clearResult: true);

    try {
      final result = await _aiService.generateMealPlan(
        family: family,
        inventory: _inventory,
        days: state.settings.days,
        mealTypes: state.settings.selectedMealTypes,
        dishesPerMeal: state.settings.dishesPerMeal,
      );

      state = state.copyWith(isGenerating: false, result: result);
    } on AIServiceException catch (e) {
      state = state.copyWith(isGenerating: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: '生成失败：$e');
    }
  }

  Future<void> saveMenuPlan() async {
    final family = _currentFamily;
    if (state.result == null || family == null) return;

    final plan = MealPlanModel.create(
      familyId: family.id,
      startDate: DateTime.now(),
      days: state.settings.days,
    );

    // 将 AI 结果转换为 MealPlanModel，并保存菜谱
    for (var i = 0; i < state.result!.days.length && i < plan.days.length; i++) {
      final dayData = state.result!.days[i];
      final dayPlan = plan.days[i];

      dayPlan.meals.clear();
      for (final mealData in dayData.meals) {
        final recipeIds = <String>[];

        // 保存每个菜谱
        for (final recipeData in mealData.recipes) {
          final recipe = _convertToRecipeModel(recipeData, family.id);
          await _recipeRepository.saveRecipe(recipe);
          recipeIds.add(recipe.id);
        }

        dayPlan.meals.add(MealModel(
          type: _convertMealType(mealData.type),
          recipeIds: recipeIds,
          notes: mealData.recipes.map((r) => r['name'] as String).join('、'),
        ));
      }
    }

    plan.notes = state.result!.nutritionSummary;

    // 保存购物清单
    if (state.result!.shoppingList.isNotEmpty) {
      final shoppingList = _convertToShoppingList(state.result!, plan.id);
      await _shoppingListRepository.saveShoppingList(shoppingList);
      plan.shoppingListId = shoppingList.id;
    }

    await _repository.saveMealPlan(plan);
  }

  /// 将 AI 返回的菜谱数据转换为 RecipeModel
  RecipeModel _convertToRecipeModel(Map<String, dynamic> data, String familyId) {
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

    // 生成占位图 URL（基于菜名哈希）
    final recipeName = data['name'] as String;
    final imageHash = recipeName.hashCode.abs() % 1000;
    final imageUrl = 'https://picsum.photos/seed/$imageHash/400/300';

    return RecipeModel.create(
      familyId: familyId,
      name: recipeName,
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
      imageUrl: imageUrl,
    );
  }

  /// 将 AI 返回的购物清单数据转换为 ShoppingListModel
  ShoppingListModel _convertToShoppingList(MenuPlanResult result, String mealPlanId) {
    final items = result.shoppingList.map((item) => ShoppingItemModel.create(
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      category: item.category ?? '其他',
      notes: item.notes,
      source: ShoppingItemSource.menu,
    )).toList();

    return ShoppingListModel.create(
      familyId: _currentFamily!.id,
      mealPlanId: mealPlanId,
      items: items,
    );
  }

  String _convertMealType(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
      case '早餐':
        return MealTypes.breakfast;
      case 'lunch':
      case '午餐':
        return MealTypes.lunch;
      case 'dinner':
      case '晚餐':
        return MealTypes.dinner;
      case 'snack':
      case '加餐':
        return MealTypes.snack;
      default:
        return type;
    }
  }

  void clearResult() {
    state = state.copyWith(clearResult: true, clearError: true);
  }
}

/// 菜单生成 Provider
final menuGenerateProvider =
    StateNotifierProvider<MenuGenerateNotifier, MenuGenerateState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final currentFamily = ref.watch(currentFamilyProvider);
  final inventoryState = ref.watch(inventoryProvider);
  final repository = ref.watch(mealPlanRepositoryProvider);
  final recipeRepository = ref.watch(recipeRepositoryProvider);
  final shoppingListRepository = ref.watch(shoppingListRepositoryProvider);

  return MenuGenerateNotifier(
    aiService: aiService,
    currentFamily: currentFamily,
    inventory: inventoryState.ingredients,
    repository: repository,
    recipeRepository: recipeRepository,
    shoppingListRepository: shoppingListRepository,
  );
});

/// 菜单列表状态
class MenuListState {
  final List<MealPlanModel> plans;
  final bool isLoading;
  final String? error;

  const MenuListState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  MenuListState copyWith({
    List<MealPlanModel>? plans,
    bool? isLoading,
    String? error,
  }) {
    return MenuListState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取今日菜单
  MealPlanModel? get todayPlan {
    final today = DateTime.now();
    return plans.firstWhere(
      (plan) => _isDateInRange(today, plan.startDate, plan.endDate),
      orElse: () => plans.isNotEmpty ? plans.first : MealPlanModel.create(
        familyId: '',
        startDate: today,
        days: 1,
      ),
    );
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}

/// 菜单列表通知器
class MenuListNotifier extends StateNotifier<MenuListState> {
  final MealPlanRepository _repository;
  final String? _familyId;

  MenuListNotifier({
    required MealPlanRepository repository,
    required String? familyId,
  })  : _repository = repository,
        _familyId = familyId,
        super(const MenuListState()) {
    loadPlans();
  }

  Future<void> loadPlans() async {
    final familyId = _familyId;
    if (familyId == null) {
      state = state.copyWith(plans: []);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final plans = _repository.getMealPlansByFamily(familyId);
      // 按创建时间倒序
      plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(plans: plans, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deletePlan(String id) async {
    await _repository.deleteMealPlan(id);
    await loadPlans();
  }
}

/// 菜单列表 Provider
final menuListProvider =
    StateNotifierProvider<MenuListNotifier, MenuListState>((ref) {
  final repository = ref.watch(mealPlanRepositoryProvider);
  final currentFamily = ref.watch(currentFamilyProvider);

  return MenuListNotifier(
    repository: repository,
    familyId: currentFamily?.id,
  );
});
