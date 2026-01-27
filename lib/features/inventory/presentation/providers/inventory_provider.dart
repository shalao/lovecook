import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/ingredient_model.dart';
import '../../data/repositories/ingredient_repository.dart';
import '../../../family/data/repositories/family_repository.dart';

/// 库存状态
class InventoryState {
  final List<IngredientModel> ingredients;
  final List<IngredientModel> expiringIngredients;
  final List<IngredientModel> lowStockIngredients;
  final bool isLoading;
  final String? error;
  final String? searchQuery;
  final String? selectedCategory;

  const InventoryState({
    this.ingredients = const [],
    this.expiringIngredients = const [],
    this.lowStockIngredients = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
    this.selectedCategory,
  });

  InventoryState copyWith({
    List<IngredientModel>? ingredients,
    List<IngredientModel>? expiringIngredients,
    List<IngredientModel>? lowStockIngredients,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCategory,
  }) {
    return InventoryState(
      ingredients: ingredients ?? this.ingredients,
      expiringIngredients: expiringIngredients ?? this.expiringIngredients,
      lowStockIngredients: lowStockIngredients ?? this.lowStockIngredients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  /// 按类别分组的食材
  Map<String, List<IngredientModel>> get groupedByCategory {
    // 不过滤零库存，但在每个分类内按数量排序（有库存的在前）
    final filtered = selectedCategory == null
        ? ingredients
        : ingredients.where((i) => i.category == selectedCategory).toList();

    final searched = searchQuery == null || searchQuery!.isEmpty
        ? filtered
        : filtered
            .where((i) =>
                i.name.toLowerCase().contains(searchQuery!.toLowerCase()))
            .toList();

    final grouped = <String, List<IngredientModel>>{};
    for (final ing in searched) {
      final category = ing.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(ing);
    }

    // 每个分类内按数量排序：有库存的在前，零库存的在后
    for (final category in grouped.keys) {
      grouped[category]!.sort((a, b) {
        // 有库存的排在前面
        if (a.quantity > 0 && b.quantity <= 0) return -1;
        if (a.quantity <= 0 && b.quantity > 0) return 1;
        // 同类内按名称排序
        return a.name.compareTo(b.name);
      });
    }

    return grouped;
  }

  /// 所有类别
  List<String> get allCategories {
    final categories = ingredients.map((i) => i.category ?? '其他').toSet().toList();
    categories.sort();
    return categories;
  }
}

/// 库存状态通知器
class InventoryNotifier extends StateNotifier<InventoryState> {
  final IngredientRepository _repository;
  final String? _familyId;

  InventoryNotifier(this._repository, this._familyId) : super(const InventoryState()) {
    if (_familyId != null) {
      loadIngredients();
    }
  }

  /// 加载食材
  Future<void> loadIngredients() async {
    if (_familyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final ingredients = _repository.getIngredientsByFamily(_familyId!);
      final expiring = _repository.getExpiringIngredients(_familyId!);
      final lowStock = _repository.getLowStockIngredients(_familyId!);

      state = state.copyWith(
        ingredients: ingredients,
        expiringIngredients: expiring,
        lowStockIngredients: lowStock,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 添加食材
  Future<void> addIngredient(IngredientModel ingredient) async {
    await _repository.saveIngredient(ingredient);
    await loadIngredients();
  }

  /// 批量添加食材
  Future<void> addIngredients(List<IngredientModel> ingredients) async {
    await _repository.saveIngredients(ingredients);
    await loadIngredients();
  }

  /// 更新食材
  Future<void> updateIngredient(IngredientModel ingredient) async {
    await _repository.saveIngredient(ingredient);
    await loadIngredients();
  }

  /// 删除食材
  Future<void> deleteIngredient(String id) async {
    await _repository.deleteIngredient(id);
    await loadIngredients();
  }

  /// 更新数量
  Future<void> updateQuantity(String id, double quantity) async {
    await _repository.updateQuantity(id, quantity);
    await loadIngredients();
  }

  /// 扣减数量
  Future<void> deductQuantity(String id, double amount) async {
    await _repository.deductQuantity(id, amount);
    await loadIngredients();
  }

  /// 设置搜索关键词
  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  /// 设置选中类别
  void setSelectedCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// 合并重复食材
  Future<void> mergeIngredients() async {
    if (_familyId == null) return;
    await _repository.mergeIngredients(_familyId!);
    await loadIngredients();
  }

  /// 清除所有食材
  Future<void> clearAll() async {
    if (_familyId == null) return;
    await _repository.clearFamilyIngredients(_familyId!);
    await loadIngredients();
  }
}

/// 库存 Provider
final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repository = ref.watch(ingredientRepositoryProvider);
  final currentFamily = ref.watch(currentFamilyProvider);
  return InventoryNotifier(repository, currentFamily?.id);
});

/// 添加食材表单状态
class AddIngredientFormState {
  final String name;
  final String? category;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final String? storageAdvice;
  final bool isSubmitting;
  final String? error;

  const AddIngredientFormState({
    this.name = '',
    this.category,
    this.quantity = 1.0,
    this.unit = '个',
    this.expiryDate,
    this.storageAdvice,
    this.isSubmitting = false,
    this.error,
  });

  AddIngredientFormState copyWith({
    String? name,
    String? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? storageAdvice,
    bool? isSubmitting,
    String? error,
  }) {
    return AddIngredientFormState(
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      storageAdvice: storageAdvice ?? this.storageAdvice,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  bool get isValid => name.isNotEmpty && quantity > 0;
}

/// 添加食材表单通知器
class AddIngredientFormNotifier extends StateNotifier<AddIngredientFormState> {
  AddIngredientFormNotifier() : super(const AddIngredientFormState());

  void setName(String name) => state = state.copyWith(name: name);
  void setCategory(String? category) => state = state.copyWith(category: category);
  void setQuantity(double quantity) => state = state.copyWith(quantity: quantity);
  void setUnit(String unit) => state = state.copyWith(unit: unit);
  void setExpiryDate(DateTime? date) => state = state.copyWith(expiryDate: date);
  void setStorageAdvice(String? advice) => state = state.copyWith(storageAdvice: advice);

  void reset() => state = const AddIngredientFormState();

  IngredientModel toIngredient(String familyId) {
    return IngredientModel.create(
      familyId: familyId,
      name: state.name,
      category: state.category,
      quantity: state.quantity,
      unit: state.unit,
      expiryDate: state.expiryDate,
      storageAdvice: state.storageAdvice,
      source: 'manual',
    );
  }
}

/// 添加食材表单 Provider
final addIngredientFormProvider =
    StateNotifierProvider.autoDispose<AddIngredientFormNotifier, AddIngredientFormState>((ref) {
  return AddIngredientFormNotifier();
});

/// 食材类别列表
const ingredientCategories = [
  '蔬菜',
  '水果',
  '肉类',
  '海鲜',
  '蛋奶',
  '豆制品',
  '主食',
  '调味料',
  '干货',
  '饮品',
  '零食',
  '其他',
];

/// 常用单位列表
const ingredientUnits = [
  '个',
  '根',
  '颗',
  '克',
  '千克',
  '斤',
  '两',
  '毫升',
  '升',
  '瓶',
  '袋',
  '盒',
  '包',
  '只',
  '条',
  '片',
  '把',
  '份',
];
