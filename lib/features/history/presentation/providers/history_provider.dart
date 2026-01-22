import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/data/repositories/family_repository.dart';
import '../../data/models/meal_history_model.dart';
import '../../data/repositories/meal_history_repository.dart';

/// 历史记录状态
class HistoryState {
  final List<MealHistoryModel> historyList;
  final DateTime selectedDate;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.historyList = const [],
    required this.selectedDate,
    this.isLoading = false,
    this.error,
  });

  HistoryState copyWith({
    List<MealHistoryModel>? historyList,
    DateTime? selectedDate,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HistoryState(
      historyList: historyList ?? this.historyList,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 获取选中日期的历史记录
  List<MealHistoryModel> get selectedDateHistory {
    return historyList.where((h) =>
        h.date.year == selectedDate.year &&
        h.date.month == selectedDate.month &&
        h.date.day == selectedDate.day).toList()
      ..sort((a, b) => _mealTypeOrder(a.mealType).compareTo(_mealTypeOrder(b.mealType)));
  }

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

/// 历史记录状态管理器
class HistoryNotifier extends StateNotifier<HistoryState> {
  final MealHistoryRepository _repository;
  final String? _familyId;

  HistoryNotifier({
    required MealHistoryRepository repository,
    required String? familyId,
  })  : _repository = repository,
        _familyId = familyId,
        super(HistoryState(selectedDate: DateTime.now())) {
    _loadHistory();
  }

  void _loadHistory() {
    if (_familyId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final history = _repository.getHistoryByFamily(_familyId!);
      state = state.copyWith(
        historyList: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载历史记录失败: $e',
      );
    }
  }

  /// 刷新历史记录
  void refresh() {
    _loadHistory();
  }

  /// 选择日期
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  /// 添加用餐记录
  Future<void> addMealHistory({
    required DateTime date,
    required String mealType,
    required String recipeId,
    required String recipeName,
  }) async {
    if (_familyId == null) return;

    try {
      await _repository.addMealHistory(
        familyId: _familyId!,
        date: date,
        mealType: mealType,
        recipeId: recipeId,
        recipeName: recipeName,
      );
      _loadHistory();
    } catch (e) {
      state = state.copyWith(error: '添加记录失败: $e');
    }
  }

  /// 更新菜品评价
  Future<void> updateRating({
    required String historyId,
    required String recipeId,
    required int? rating,
    String? comment,
  }) async {
    try {
      await _repository.updateRecipeRating(
        historyId: historyId,
        recipeId: recipeId,
        rating: rating,
        comment: comment,
      );
      _loadHistory();
    } catch (e) {
      state = state.copyWith(error: '更新评价失败: $e');
    }
  }

  /// 删除历史记录
  Future<void> deleteHistory(String id) async {
    try {
      await _repository.deleteHistory(id);
      _loadHistory();
    } catch (e) {
      state = state.copyWith(error: '删除失败: $e');
    }
  }

  /// 从历史记录中移除菜品
  Future<void> removeRecipeFromHistory({
    required String historyId,
    required String recipeId,
  }) async {
    try {
      await _repository.removeRecipeFromHistory(
        historyId: historyId,
        recipeId: recipeId,
      );
      _loadHistory();
    } catch (e) {
      state = state.copyWith(error: '移除失败: $e');
    }
  }

  /// 获取有历史记录的日期列表
  List<DateTime> getDatesWithHistory({int? year, int? month}) {
    if (_familyId == null) return [];
    return _repository.getDatesWithHistory(_familyId!, year: year, month: month);
  }

  /// 获取最近N天吃过的菜品名称
  List<String> getRecentRecipeNames(int days) {
    if (_familyId == null) return [];
    return _repository.getRecentRecipeNames(_familyId!, days);
  }

  /// 获取喜欢的菜品
  List<String> getLikedRecipes() {
    if (_familyId == null) return [];
    return _repository.getLikedRecipes(_familyId!);
  }

  /// 获取不喜欢的菜品
  List<String> getDislikedRecipes() {
    if (_familyId == null) return [];
    return _repository.getDislikedRecipes(_familyId!);
  }
}

/// 历史记录 Provider
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final repository = ref.watch(mealHistoryRepositoryProvider);
  final currentFamily = ref.watch(currentFamilyProvider);

  return HistoryNotifier(
    repository: repository,
    familyId: currentFamily?.id,
  );
});

/// 选中日期 Provider
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 某个月有历史记录的日期 Provider
final datesWithHistoryProvider =
    Provider.family<List<DateTime>, DateTime>((ref, month) {
  final notifier = ref.watch(historyProvider.notifier);
  return notifier.getDatesWithHistory(year: month.year, month: month.month);
});
