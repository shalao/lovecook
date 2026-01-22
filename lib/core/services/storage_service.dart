import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/family/data/models/family_model.dart';
import '../../features/inventory/data/models/ingredient_model.dart';
import '../../features/recipe/data/models/recipe_model.dart';
import '../../features/menu/data/models/meal_plan_model.dart';
import '../../features/shopping/data/models/shopping_list_model.dart';
import '../../features/history/data/models/meal_history_model.dart';

/// Hive Box 名称
class HiveBoxes {
  static const String families = 'families';
  static const String ingredients = 'ingredients';
  static const String recipes = 'recipes';
  static const String mealPlans = 'meal_plans';
  static const String shoppingLists = 'shopping_lists';
  static const String mealHistory = 'meal_history';
  static const String settings = 'settings';
}

/// 存储服务
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  StorageService._();

  bool _initialized = false;

  /// 初始化 Hive
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化 Hive
    await Hive.initFlutter();

    // 注册适配器
    _registerAdapters();

    // 打开所有 boxes
    await _openBoxes();

    _initialized = true;
  }

  void _registerAdapters() {
    // Family 相关
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FamilyModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FamilyMemberModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MealSettingsModelAdapter());
    }

    // Ingredient 相关
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(IngredientModelAdapter());
    }

    // Recipe 相关
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(RecipeModelAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(RecipeIngredientModelAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(NutritionInfoModelAdapter());
    }

    // MealPlan 相关
    if (!Hive.isAdapterRegistered(30)) {
      Hive.registerAdapter(MealPlanModelAdapter());
    }
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(DayPlanModelAdapter());
    }
    if (!Hive.isAdapterRegistered(32)) {
      Hive.registerAdapter(MealModelAdapter());
    }

    // ShoppingList 相关
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(ShoppingListModelAdapter());
    }
    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter(ShoppingItemModelAdapter());
    }

    // MealHistory 相关
    if (!Hive.isAdapterRegistered(50)) {
      Hive.registerAdapter(MealHistoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(51)) {
      Hive.registerAdapter(MealHistoryRecipeModelAdapter());
    }
  }

  Future<void> _openBoxes() async {
    await Future.wait([
      Hive.openBox<FamilyModel>(HiveBoxes.families),
      Hive.openBox<IngredientModel>(HiveBoxes.ingredients),
      Hive.openBox<RecipeModel>(HiveBoxes.recipes),
      Hive.openBox<MealPlanModel>(HiveBoxes.mealPlans),
      Hive.openBox<ShoppingListModel>(HiveBoxes.shoppingLists),
      Hive.openBox<MealHistoryModel>(HiveBoxes.mealHistory),
      Hive.openBox(HiveBoxes.settings),
    ]);
  }

  // Box 访问器
  Box<FamilyModel> get familiesBox => Hive.box<FamilyModel>(HiveBoxes.families);
  Box<IngredientModel> get ingredientsBox => Hive.box<IngredientModel>(HiveBoxes.ingredients);
  Box<RecipeModel> get recipesBox => Hive.box<RecipeModel>(HiveBoxes.recipes);
  Box<MealPlanModel> get mealPlansBox => Hive.box<MealPlanModel>(HiveBoxes.mealPlans);
  Box<ShoppingListModel> get shoppingListsBox => Hive.box<ShoppingListModel>(HiveBoxes.shoppingLists);
  Box<MealHistoryModel> get mealHistoryBox => Hive.box<MealHistoryModel>(HiveBoxes.mealHistory);
  Box get settingsBox => Hive.box(HiveBoxes.settings);

  /// 清除所有数据
  Future<void> clearAllData() async {
    await familiesBox.clear();
    await ingredientsBox.clear();
    await recipesBox.clear();
    await mealPlansBox.clear();
    await shoppingListsBox.clear();
    await mealHistoryBox.clear();
    await settingsBox.clear();
  }

  /// 关闭所有 boxes
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}

/// 存储服务 Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

/// 初始化状态 Provider
final storageInitializedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  await storage.initialize();
  return true;
});
