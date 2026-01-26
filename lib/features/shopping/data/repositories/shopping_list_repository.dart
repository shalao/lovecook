import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/models/shopping_list_model.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../inventory/data/models/ingredient_model.dart';

/// 购物清单仓库
class ShoppingListRepository {
  final StorageService _storage;

  ShoppingListRepository(this._storage);

  /// 获取家庭的所有购物清单
  List<ShoppingListModel> getShoppingListsByFamily(String familyId) {
    return _storage.shoppingListsBox.values
        .where((s) => s.familyId == familyId)
        .toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  /// 根据 ID 获取购物清单
  ShoppingListModel? getShoppingListById(String id) {
    return _storage.shoppingListsBox.values.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('ShoppingList not found'),
    );
  }

  /// 保存购物清单
  Future<void> saveShoppingList(ShoppingListModel shoppingList) async {
    await _storage.shoppingListsBox.put(shoppingList.id, shoppingList);
  }

  /// 删除购物清单
  Future<void> deleteShoppingList(String id) async {
    await _storage.shoppingListsBox.delete(id);
  }

  /// 根据菜谱列表生成购物清单（基础版本，不带日期）
  ShoppingListModel generateFromRecipes({
    required String familyId,
    required List<RecipeModel> recipes,
    required List<IngredientModel> inventory,
    String? mealPlanId,
  }) {
    final items = <ShoppingItemModel>[];
    final inventoryMap = <String, double>{};

    // 建立库存映射
    for (final ing in inventory) {
      inventoryMap[ing.name.toLowerCase()] = ing.quantity;
    }

    // 计算所需食材
    final requiredMap = <String, _RequiredIngredient>{};

    for (final recipe in recipes) {
      for (final ing in recipe.ingredients) {
        if (ing.isOptional) continue;

        final key = '${ing.name.toLowerCase()}_${ing.unit}';
        if (requiredMap.containsKey(key)) {
          requiredMap[key]!.quantity += ing.quantity;
        } else {
          requiredMap[key] = _RequiredIngredient(
            name: ing.name,
            quantity: ing.quantity,
            unit: ing.unit,
          );
        }
      }
    }

    // 减去库存，生成购物项
    for (final req in requiredMap.values) {
      final inStock = inventoryMap[req.name.toLowerCase()] ?? 0;
      final needed = req.quantity - inStock;

      if (needed > 0) {
        items.add(ShoppingItemModel.create(
          category: _guessCategory(req.name),
          name: req.name,
          quantity: needed,
          unit: req.unit,
          source: ShoppingItemSource.menu,
        ));
      }
    }

    return ShoppingListModel.create(
      familyId: familyId,
      mealPlanId: mealPlanId,
      items: items,
    );
  }

  /// 根据带日期的菜谱列表生成购物清单（带时间分组和用量溯源）
  ShoppingListModel generateFromRecipesWithDates({
    required String familyId,
    required List<RecipeWithDateInfo> recipesWithDates,
    required List<IngredientModel> inventory,
    String? mealPlanId,
  }) {
    final items = <ShoppingItemModel>[];
    final inventoryMap = <String, double>{};

    // 建立库存映射
    for (final ing in inventory) {
      inventoryMap[ing.name.toLowerCase()] = ing.quantity;
    }

    // 计算所需食材（带用量追踪）
    final requiredMap = <String, _RequiredIngredientWithUsage>{};

    for (final recipeInfo in recipesWithDates) {
      final recipe = recipeInfo.recipe;
      for (final ing in recipe.ingredients) {
        if (ing.isOptional) continue;

        final key = '${ing.name.toLowerCase()}_${ing.unit}';
        final usage = IngredientUsage(
          recipeName: recipe.name,
          quantity: ing.quantity,
          unit: ing.unit,
          useDate: recipeInfo.date,
          mealType: recipeInfo.mealType,
        );

        if (requiredMap.containsKey(key)) {
          requiredMap[key]!.quantity += ing.quantity;
          requiredMap[key]!.usages.add(usage);
          // 更新最早需求日期
          if (recipeInfo.date.isBefore(requiredMap[key]!.earliestDate)) {
            requiredMap[key]!.earliestDate = recipeInfo.date;
          }
        } else {
          requiredMap[key] = _RequiredIngredientWithUsage(
            name: ing.name,
            quantity: ing.quantity,
            unit: ing.unit,
            earliestDate: recipeInfo.date,
            usages: [usage],
          );
        }
      }
    }

    // 减去库存，生成购物项
    for (final req in requiredMap.values) {
      final inStock = inventoryMap[req.name.toLowerCase()] ?? 0;
      final needed = req.quantity - inStock;

      if (needed > 0) {
        // 计算需要购买的日期（最早需求日期 - 1天，需提前准备）
        final needByDate = req.earliestDate.subtract(const Duration(days: 1));

        items.add(ShoppingItemModel.create(
          category: _guessCategory(req.name),
          name: req.name,
          quantity: needed,
          unit: req.unit,
          source: ShoppingItemSource.menu,
          needByDate: needByDate,
          usages: req.usages,
        ));
      }
    }

    // 按紧急度排序（最紧急的在前面）
    items.sort((a, b) {
      if (a.needByDate == null && b.needByDate == null) return 0;
      if (a.needByDate == null) return 1;
      if (b.needByDate == null) return -1;
      return a.needByDate!.compareTo(b.needByDate!);
    });

    return ShoppingListModel.create(
      familyId: familyId,
      mealPlanId: mealPlanId,
      items: items,
    );
  }

  /// 添加手动项目
  Future<void> addItem(String shoppingListId, ShoppingItemModel item) async {
    final list = getShoppingListById(shoppingListId);
    if (list != null) {
      list.addItem(item);
      await list.save();
    }
  }

  /// 移除项目
  Future<void> removeItem(String shoppingListId, String itemId) async {
    final list = getShoppingListById(shoppingListId);
    if (list != null) {
      list.removeItem(itemId);
      await list.save();
    }
  }

  /// 切换购买状态
  Future<void> toggleItemPurchased(String shoppingListId, String itemId) async {
    final list = getShoppingListById(shoppingListId);
    if (list != null) {
      final item = list.items.firstWhere((i) => i.id == itemId);
      item.togglePurchased();
      await list.save();
    }
  }

  /// 标记所有为已购买
  Future<void> markAllPurchased(String shoppingListId) async {
    final list = getShoppingListById(shoppingListId);
    if (list != null) {
      for (final item in list.items) {
        item.purchased = true;
      }
      await list.save();
    }
  }

  /// 重置所有购买状态
  Future<void> resetAllPurchased(String shoppingListId) async {
    final list = getShoppingListById(shoppingListId);
    if (list != null) {
      for (final item in list.items) {
        item.purchased = false;
      }
      await list.save();
    }
  }

  /// 获取最新购物清单
  ShoppingListModel? getLatestShoppingList(String familyId) {
    final lists = getShoppingListsByFamily(familyId);
    return lists.isNotEmpty ? lists.first : null;
  }

  /// 根据购物清单 ID 查找并更新
  ShoppingListModel? getShoppingListByMealPlanId(String mealPlanId) {
    try {
      return _storage.shoppingListsBox.values.firstWhere(
        (s) => s.mealPlanId == mealPlanId,
      );
    } catch (_) {
      return null;
    }
  }

  /// 更新购物清单内容（当菜谱变化时调用，不带日期）
  Future<void> updateShoppingListItems({
    required String shoppingListId,
    required List<RecipeModel> recipes,
    required List<IngredientModel> inventory,
  }) async {
    final list = getShoppingListById(shoppingListId);
    if (list == null) return;

    // 计算新的购物清单项目
    final inventoryMap = <String, double>{};
    for (final ing in inventory) {
      inventoryMap[ing.name.toLowerCase()] = ing.quantity;
    }

    final requiredMap = <String, _RequiredIngredient>{};
    for (final recipe in recipes) {
      for (final ing in recipe.ingredients) {
        if (ing.isOptional) continue;

        final key = '${ing.name.toLowerCase()}_${ing.unit}';
        if (requiredMap.containsKey(key)) {
          requiredMap[key]!.quantity += ing.quantity;
        } else {
          requiredMap[key] = _RequiredIngredient(
            name: ing.name,
            quantity: ing.quantity,
            unit: ing.unit,
          );
        }
      }
    }

    // 生成新的购物项（保留已购买状态）
    final oldPurchasedItems = <String, bool>{};
    for (final item in list.items) {
      oldPurchasedItems['${item.name}_${item.unit}'] = item.purchased;
    }

    final newItems = <ShoppingItemModel>[];
    for (final req in requiredMap.values) {
      final inStock = inventoryMap[req.name.toLowerCase()] ?? 0;
      final needed = req.quantity - inStock;

      if (needed > 0) {
        final key = '${req.name}_${req.unit}';
        newItems.add(ShoppingItemModel.create(
          category: _guessCategory(req.name),
          name: req.name,
          quantity: needed,
          unit: req.unit,
          source: ShoppingItemSource.menu,
        )..purchased = oldPurchasedItems[key] ?? false);
      }
    }

    // 更新购物清单
    list.items.clear();
    list.items.addAll(newItems);
    await list.save();
  }

  /// 更新购物清单内容（带日期和用量追踪）
  Future<void> updateShoppingListItemsWithDates({
    required String shoppingListId,
    required List<RecipeWithDateInfo> recipesWithDates,
    required List<IngredientModel> inventory,
  }) async {
    final list = getShoppingListById(shoppingListId);
    if (list == null) return;

    // 计算新的购物清单项目
    final inventoryMap = <String, double>{};
    for (final ing in inventory) {
      inventoryMap[ing.name.toLowerCase()] = ing.quantity;
    }

    final requiredMap = <String, _RequiredIngredientWithUsage>{};
    for (final recipeInfo in recipesWithDates) {
      final recipe = recipeInfo.recipe;
      for (final ing in recipe.ingredients) {
        if (ing.isOptional) continue;

        final key = '${ing.name.toLowerCase()}_${ing.unit}';
        final usage = IngredientUsage(
          recipeName: recipe.name,
          quantity: ing.quantity,
          unit: ing.unit,
          useDate: recipeInfo.date,
          mealType: recipeInfo.mealType,
        );

        if (requiredMap.containsKey(key)) {
          requiredMap[key]!.quantity += ing.quantity;
          requiredMap[key]!.usages.add(usage);
          if (recipeInfo.date.isBefore(requiredMap[key]!.earliestDate)) {
            requiredMap[key]!.earliestDate = recipeInfo.date;
          }
        } else {
          requiredMap[key] = _RequiredIngredientWithUsage(
            name: ing.name,
            quantity: ing.quantity,
            unit: ing.unit,
            earliestDate: recipeInfo.date,
            usages: [usage],
          );
        }
      }
    }

    // 生成新的购物项（保留已购买状态）
    final oldPurchasedItems = <String, bool>{};
    for (final item in list.items) {
      oldPurchasedItems['${item.name}_${item.unit}'] = item.purchased;
    }

    final newItems = <ShoppingItemModel>[];
    for (final req in requiredMap.values) {
      final inStock = inventoryMap[req.name.toLowerCase()] ?? 0;
      final needed = req.quantity - inStock;

      if (needed > 0) {
        final key = '${req.name}_${req.unit}';
        final needByDate = req.earliestDate.subtract(const Duration(days: 1));

        newItems.add(ShoppingItemModel.create(
          category: _guessCategory(req.name),
          name: req.name,
          quantity: needed,
          unit: req.unit,
          source: ShoppingItemSource.menu,
          needByDate: needByDate,
          usages: req.usages,
        )..purchased = oldPurchasedItems[key] ?? false);
      }
    }

    // 按紧急度排序
    newItems.sort((a, b) {
      if (a.needByDate == null && b.needByDate == null) return 0;
      if (a.needByDate == null) return 1;
      if (b.needByDate == null) return -1;
      return a.needByDate!.compareTo(b.needByDate!);
    });

    // 更新购物清单
    list.items.clear();
    list.items.addAll(newItems);
    await list.save();
  }

  /// 根据食材名称猜测类别
  String _guessCategory(String name) {
    final categories = {
      '蔬菜': ['菜', '萝卜', '白菜', '青菜', '芹菜', '生菜', '菠菜', '茄子', '番茄', '西红柿', '黄瓜', '土豆', '洋葱'],
      '肉类': ['肉', '鸡', '鸭', '鱼', '虾', '牛', '猪', '羊', '排骨', '五花'],
      '蛋奶': ['蛋', '奶', '牛奶', '鸡蛋', '酸奶', '芝士', '奶酪'],
      '水果': ['果', '苹果', '香蕉', '橙子', '葡萄', '西瓜', '草莓', '梨'],
      '豆制品': ['豆腐', '豆干', '豆皮', '豆浆'],
      '调味料': ['盐', '糖', '酱油', '醋', '油', '料酒', '味精', '鸡精', '胡椒', '辣椒', '葱', '姜', '蒜'],
      '主食': ['米', '面', '面条', '面粉', '大米', '糯米'],
      '干货': ['木耳', '香菇', '干', '粉丝', '粉条'],
    };

    for (final entry in categories.entries) {
      for (final keyword in entry.value) {
        if (name.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return '其他';
  }
}

/// 辅助类：所需食材
class _RequiredIngredient {
  final String name;
  double quantity;
  final String unit;

  _RequiredIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}

/// 辅助类：带用量追踪的所需食材
class _RequiredIngredientWithUsage {
  final String name;
  double quantity;
  final String unit;
  DateTime earliestDate;
  final List<IngredientUsage> usages;

  _RequiredIngredientWithUsage({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.earliestDate,
    required this.usages,
  });
}

/// 带日期信息的菜谱
class RecipeWithDateInfo {
  final RecipeModel recipe;
  final DateTime date;
  final String mealType; // breakfast/lunch/dinner

  RecipeWithDateInfo({
    required this.recipe,
    required this.date,
    required this.mealType,
  });
}

/// ShoppingList Repository Provider
final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ShoppingListRepository(storage);
});

/// 家庭购物清单 Provider
final familyShoppingListsProvider = Provider.family<List<ShoppingListModel>, String>((ref, familyId) {
  final repo = ref.watch(shoppingListRepositoryProvider);
  return repo.getShoppingListsByFamily(familyId);
});

/// 最新购物清单 Provider
final latestShoppingListProvider = Provider.family<ShoppingListModel?, String>((ref, familyId) {
  final repo = ref.watch(shoppingListRepositoryProvider);
  return repo.getLatestShoppingList(familyId);
});
