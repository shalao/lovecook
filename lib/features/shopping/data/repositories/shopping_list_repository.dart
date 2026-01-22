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

  /// 根据菜谱列表生成购物清单
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
