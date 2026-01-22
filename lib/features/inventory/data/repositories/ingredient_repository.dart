import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../models/ingredient_model.dart';

/// 食材同义词/别名映射
/// 格式：标准名称 -> [别名列表]
const Map<String, List<String>> ingredientAliases = {
  // 蔬菜
  '西红柿': ['番茄', '圣女果', '小番茄'],
  '番茄': ['西红柿', '圣女果', '小番茄'],
  '土豆': ['马铃薯', '洋芋', '地蛋'],
  '马铃薯': ['土豆', '洋芋', '地蛋'],
  '红薯': ['地瓜', '番薯', '甘薯'],
  '地瓜': ['红薯', '番薯', '甘薯'],
  '青椒': ['甜椒', '柿子椒', '菜椒'],
  '辣椒': ['小米椒', '朝天椒', '尖椒'],
  '茄子': ['矮瓜', '落苏'],
  '豆角': ['四季豆', '芸豆', '菜豆'],
  '四季豆': ['豆角', '芸豆', '菜豆'],
  '白菜': ['大白菜', '黄芽白', '结球白菜'],
  '大白菜': ['白菜', '黄芽白', '结球白菜'],
  '小白菜': ['青菜', '油菜', '上海青'],
  '油菜': ['小白菜', '青菜', '上海青'],
  '西兰花': ['绿花菜', '青花菜', '西蓝花'],
  '花菜': ['菜花', '花椰菜'],
  '菜花': ['花菜', '花椰菜'],
  '韭菜': ['韭黄', '起阳草'],
  '蒜苗': ['蒜薹', '蒜苔', '青蒜'],
  '蒜薹': ['蒜苗', '蒜苔', '青蒜'],
  '生菜': ['莴苣', '卷心莴苣'],
  '莴笋': ['莴苣笋', '青笋'],
  '芹菜': ['旱芹', '西芹'],
  '香菜': ['芫荽', '胡荽'],
  '芫荽': ['香菜', '胡荽'],
  '菠菜': ['波斯菜', '赤根菜'],
  '空心菜': ['蕹菜', '通菜', '藤菜'],
  '苋菜': ['汉菜', '红苋'],

  // 肉类
  '猪肉': ['猪瘦肉', '肉片', '肉丝'],
  '五花肉': ['三层肉', '肋条肉'],
  '里脊肉': ['猪里脊', '肉排'],
  '排骨': ['肋排', '猪排骨', '小排'],
  '鸡肉': ['鸡腿肉', '鸡胸肉', '鸡翅'],
  '鸡腿': ['琵琶腿', '鸡腿肉'],
  '鸡胸': ['鸡胸肉', '鸡脯肉'],
  '牛肉': ['牛腩', '牛腱', '牛里脊'],
  '牛腩': ['牛肉', '牛肋条'],
  '羊肉': ['羊腿肉', '羊排', '羊肉片'],

  // 海鲜
  '虾': ['基围虾', '对虾', '明虾', '大虾'],
  '大虾': ['虾', '基围虾', '对虾', '明虾'],
  '鱼': ['鲈鱼', '草鱼', '鲤鱼', '鲫鱼'],
  '带鱼': ['刀鱼', '牙带'],
  '蛤蜊': ['花蛤', '蛤仔', '蚬子'],
  '花蛤': ['蛤蜊', '蛤仔', '蚬子'],
  '螃蟹': ['大闸蟹', '梭子蟹', '青蟹'],

  // 蛋奶
  '鸡蛋': ['鸡子', '蛋', '土鸡蛋'],
  '蛋': ['鸡蛋', '鸡子', '土鸡蛋'],
  '牛奶': ['鲜奶', '纯牛奶'],

  // 豆制品
  '豆腐': ['老豆腐', '嫩豆腐', '水豆腐'],
  '豆腐皮': ['豆皮', '油豆皮', '千张'],
  '千张': ['豆腐皮', '豆皮', '百页'],
  '豆干': ['豆腐干', '白干'],

  // 调味料
  '酱油': ['生抽', '老抽', '味极鲜'],
  '生抽': ['酱油', '味极鲜'],
  '老抽': ['酱油', '红烧酱油'],
  '醋': ['米醋', '陈醋', '香醋', '白醋'],
  '米醋': ['醋', '陈醋', '香醋'],
  '料酒': ['黄酒', '绍酒', '烹调酒'],
  '黄酒': ['料酒', '绍酒'],
  '淀粉': ['生粉', '玉米淀粉', '土豆淀粉'],
  '生粉': ['淀粉', '玉米淀粉'],
  '白糖': ['砂糖', '绵白糖', '糖'],
  '糖': ['白糖', '砂糖', '绵白糖'],
  '食盐': ['盐', '精盐', '细盐'],
  '盐': ['食盐', '精盐', '细盐'],
  '味精': ['鸡精', '味素'],
  '鸡精': ['味精', '鸡粉'],
  '葱': ['大葱', '小葱', '香葱'],
  '大葱': ['葱', '青葱'],
  '小葱': ['葱', '香葱', '细葱'],
  '姜': ['生姜', '老姜', '嫩姜'],
  '生姜': ['姜', '老姜', '嫩姜'],
  '蒜': ['大蒜', '蒜头', '蒜瓣'],
  '大蒜': ['蒜', '蒜头', '蒜瓣'],

  // 主食
  '米': ['大米', '粳米', '籼米'],
  '大米': ['米', '粳米', '籼米'],
  '面粉': ['小麦粉', '中筋粉', '高筋粉', '低筋粉'],
  '小麦粉': ['面粉', '中筋粉'],
  '面条': ['挂面', '手擀面', '拉面'],
  '挂面': ['面条', '干面条'],
};

/// 食材库存仓库
class IngredientRepository {
  final StorageService _storage;

  IngredientRepository(this._storage);

  /// 获取家庭的所有食材
  List<IngredientModel> getIngredientsByFamily(String familyId) {
    return _storage.ingredientsBox.values
        .where((i) => i.familyId == familyId)
        .toList();
  }

  /// 根据 ID 获取食材
  IngredientModel? getIngredientById(String id) {
    return _storage.ingredientsBox.values.firstWhere(
      (i) => i.id == id,
      orElse: () => throw Exception('Ingredient not found'),
    );
  }

  /// 保存食材
  Future<void> saveIngredient(IngredientModel ingredient) async {
    await _storage.ingredientsBox.put(ingredient.id, ingredient);
  }

  /// 批量保存食材
  Future<void> saveIngredients(List<IngredientModel> ingredients) async {
    final map = <String, IngredientModel>{};
    for (final ing in ingredients) {
      map[ing.id] = ing;
    }
    await _storage.ingredientsBox.putAll(map);
  }

  /// 删除食材
  Future<void> deleteIngredient(String id) async {
    await _storage.ingredientsBox.delete(id);
  }

  /// 更新食材数量
  Future<void> updateQuantity(String id, double newQuantity) async {
    final ingredient = getIngredientById(id);
    if (ingredient != null) {
      ingredient.quantity = newQuantity;
      ingredient.updatedAt = DateTime.now();
      await ingredient.save();
    }
  }

  /// 扣减食材数量
  Future<void> deductQuantity(String id, double amount) async {
    final ingredient = getIngredientById(id);
    if (ingredient != null) {
      ingredient.quantity = (ingredient.quantity - amount).clamp(0.0, double.infinity);
      ingredient.updatedAt = DateTime.now();
      await ingredient.save();
    }
  }

  /// 获取临期食材
  List<IngredientModel> getExpiringIngredients(String familyId, {int daysThreshold = 3}) {
    final threshold = DateTime.now().add(Duration(days: daysThreshold));
    return _storage.ingredientsBox.values
        .where((i) =>
            i.familyId == familyId &&
            i.expiryDate != null &&
            i.expiryDate!.isBefore(threshold))
        .toList();
  }

  /// 获取已过期食材
  List<IngredientModel> getExpiredIngredients(String familyId) {
    final now = DateTime.now();
    return _storage.ingredientsBox.values
        .where((i) =>
            i.familyId == familyId &&
            i.expiryDate != null &&
            i.expiryDate!.isBefore(now))
        .toList();
  }

  /// 获取库存不足的食材
  List<IngredientModel> getLowStockIngredients(String familyId, {double threshold = 1.0}) {
    return _storage.ingredientsBox.values
        .where((i) => i.familyId == familyId && i.quantity <= threshold)
        .toList();
  }

  /// 按类别获取食材
  Map<String, List<IngredientModel>> getIngredientsByCategory(String familyId) {
    final ingredients = getIngredientsByFamily(familyId);
    final grouped = <String, List<IngredientModel>>{};
    for (final ing in ingredients) {
      final category = ing.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(ing);
    }
    return grouped;
  }

  /// 搜索食材（支持同义词匹配）
  List<IngredientModel> searchIngredients(String familyId, String query) {
    final lowercaseQuery = query.toLowerCase();

    // 获取所有可能的同义词
    final synonyms = _getIngredientSynonyms(query);

    return _storage.ingredientsBox.values
        .where((i) {
          if (i.familyId != familyId) return false;

          final nameLower = i.name.toLowerCase();
          final categoryLower = i.category?.toLowerCase() ?? '';

          // 直接匹配
          if (nameLower.contains(lowercaseQuery) || categoryLower.contains(lowercaseQuery)) {
            return true;
          }

          // 同义词匹配
          for (final synonym in synonyms) {
            if (nameLower.contains(synonym.toLowerCase())) {
              return true;
            }
          }

          return false;
        })
        .toList();
  }

  /// 根据名称查找食材（支持同义词匹配）
  IngredientModel? findByName(String familyId, String name) {
    final lowercaseName = name.toLowerCase().trim();
    final ingredients = getIngredientsByFamily(familyId);

    // 精确匹配
    for (final ing in ingredients) {
      if (ing.name.toLowerCase().trim() == lowercaseName) {
        return ing;
      }
    }

    // 同义词匹配
    final synonyms = _getIngredientSynonyms(name);
    for (final synonym in synonyms) {
      for (final ing in ingredients) {
        if (ing.name.toLowerCase().trim() == synonym.toLowerCase().trim()) {
          return ing;
        }
      }
    }

    // 模糊匹配（包含关系）
    for (final ing in ingredients) {
      if (ing.name.toLowerCase().contains(lowercaseName) ||
          lowercaseName.contains(ing.name.toLowerCase())) {
        return ing;
      }
    }

    return null;
  }

  /// 获取食材的所有同义词
  List<String> _getIngredientSynonyms(String name) {
    final lowercaseName = name.toLowerCase().trim();
    final result = <String>[];

    // 查找直接定义的同义词
    for (final entry in ingredientAliases.entries) {
      final key = entry.key.toLowerCase();
      final aliases = entry.value;

      if (key == lowercaseName || key.contains(lowercaseName) || lowercaseName.contains(key)) {
        result.addAll(aliases);
      }

      for (final alias in aliases) {
        if (alias.toLowerCase() == lowercaseName ||
            alias.toLowerCase().contains(lowercaseName) ||
            lowercaseName.contains(alias.toLowerCase())) {
          result.add(entry.key);
          result.addAll(aliases.where((a) => a.toLowerCase() != lowercaseName));
        }
      }
    }

    return result.toSet().toList(); // 去重
  }

  /// 智能匹配食材并返回匹配结果
  /// 返回: {原始名称: 匹配到的库存食材}
  Map<String, IngredientModel?> smartMatchIngredients(
    String familyId,
    List<String> ingredientNames,
  ) {
    final result = <String, IngredientModel?>{};
    for (final name in ingredientNames) {
      result[name] = findByName(familyId, name);
    }
    return result;
  }

  /// 合并重复食材
  Future<void> mergeIngredients(String familyId) async {
    final ingredients = getIngredientsByFamily(familyId);
    final merged = <String, IngredientModel>{};
    final toDelete = <String>[];

    for (final ing in ingredients) {
      final key = '${ing.name}_${ing.unit}';
      if (merged.containsKey(key)) {
        merged[key]!.quantity += ing.quantity;
        toDelete.add(ing.id);
      } else {
        merged[key] = ing;
      }
    }

    // 删除重复项
    for (final id in toDelete) {
      await deleteIngredient(id);
    }

    // 保存合并后的数据
    for (final ing in merged.values) {
      await ing.save();
    }
  }

  /// 清除家庭所有食材
  Future<void> clearFamilyIngredients(String familyId) async {
    final ingredients = getIngredientsByFamily(familyId);
    for (final ing in ingredients) {
      await deleteIngredient(ing.id);
    }
  }
}

/// Ingredient Repository Provider
final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return IngredientRepository(storage);
});

/// 家庭库存 Provider
final familyIngredientsProvider = Provider.family<List<IngredientModel>, String>((ref, familyId) {
  final repo = ref.watch(ingredientRepositoryProvider);
  return repo.getIngredientsByFamily(familyId);
});

/// 临期食材 Provider
final expiringIngredientsProvider = Provider.family<List<IngredientModel>, String>((ref, familyId) {
  final repo = ref.watch(ingredientRepositoryProvider);
  return repo.getExpiringIngredients(familyId);
});

/// 库存不足食材 Provider
final lowStockIngredientsProvider = Provider.family<List<IngredientModel>, String>((ref, familyId) {
  final repo = ref.watch(ingredientRepositoryProvider);
  return repo.getLowStockIngredients(familyId);
});
