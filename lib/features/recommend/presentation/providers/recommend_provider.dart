import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/ai_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../family/data/models/family_model.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../history/data/repositories/meal_history_repository.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../menu/data/models/meal_plan_model.dart';
import '../../../menu/data/repositories/meal_plan_repository.dart';
import '../../../menu/presentation/providers/menu_provider.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../shopping/data/models/shopping_list_model.dart';
import '../../../shopping/data/repositories/shopping_list_repository.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../data/models/recommend_settings.dart';

/// 推荐页视图模式
enum RecommendViewMode {
  /// 生成推荐模式（无已确认菜单时显示）
  generate,

  /// 已确认菜单模式（显示已保存的菜单）
  confirmed,
}

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

  // v1.2 新增：已确认菜单相关字段
  final RecommendViewMode viewMode;
  final MealPlanModel? confirmedPlan; // 已确认的菜单
  final List<DayPlan> confirmedDayPlans; // 已确认菜单转换后的 DayPlan
  final String currentMealType; // 当前餐次（根据时间自动判断）
  final DateTime selectedDate; // 当前选中的日期
  final int selectedDayIndex; // 当前选中的日期索引（更可靠的选择方式）

  RecommendState({
    this.breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐'),
    this.lunch = const MealRecommend(type: 'lunch', typeName: '午餐'),
    this.dinner = const MealRecommend(type: 'dinner', typeName: '晚餐'),
    this.snacks = const MealRecommend(type: 'snacks', typeName: '甜点'),
    this.dayPlans = const [],
    this.isInitialLoading = false,
    this.globalError,
    RecommendSettings? settings,
    // v1.2 新增字段默认值
    this.viewMode = RecommendViewMode.generate,
    this.confirmedPlan,
    this.confirmedDayPlans = const [],
    this.currentMealType = 'lunch',
    DateTime? selectedDate,
    this.selectedDayIndex = 0,
  })  : settings = settings ?? RecommendSettings(),
        selectedDate = selectedDate ?? DateTime.now();

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
    // v1.2 新增字段
    RecommendViewMode? viewMode,
    MealPlanModel? confirmedPlan,
    bool clearConfirmedPlan = false,
    List<DayPlan>? confirmedDayPlans,
    String? currentMealType,
    DateTime? selectedDate,
    int? selectedDayIndex,
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
      // v1.2 新增字段
      viewMode: viewMode ?? this.viewMode,
      confirmedPlan: clearConfirmedPlan ? null : (confirmedPlan ?? this.confirmedPlan),
      confirmedDayPlans: confirmedDayPlans ?? this.confirmedDayPlans,
      currentMealType: currentMealType ?? this.currentMealType,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
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

  /// v1.2: 是否处于已确认菜单模式
  bool get isConfirmedMode => viewMode == RecommendViewMode.confirmed;

  /// v1.2: 获取当前选中日期的 DayPlan（优先使用索引）
  DayPlan? get selectedDayPlan {
    if (confirmedDayPlans.isEmpty) return null;

    // 优先使用索引直接获取（更可靠）
    if (selectedDayIndex >= 0 && selectedDayIndex < confirmedDayPlans.length) {
      return confirmedDayPlans[selectedDayIndex];
    }

    // 降级：通过日期匹配
    final normalizedSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return confirmedDayPlans.cast<DayPlan?>().firstWhere(
          (d) =>
              d != null &&
              d.date.year == normalizedSelected.year &&
              d.date.month == normalizedSelected.month &&
              d.date.day == normalizedSelected.day,
          orElse: () => null,
        );
  }

  /// v1.2: 已确认菜单是否有今天或未来的内容
  bool get hasValidConfirmedPlan {
    if (confirmedDayPlans.isEmpty) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return confirmedDayPlans.any((d) =>
        d.date.isAfter(today.subtract(const Duration(days: 1))) &&
        d.hasAnyRecipes);
  }
}

/// 今日推荐通知器
class RecommendNotifier extends StateNotifier<RecommendState> {
  final Ref _ref;
  final AIService _aiService;
  final FamilyModel? _currentFamily;
  final List<IngredientModel> _inventory;
  final MealHistoryRepository _historyRepository;
  final RecipeRepository _recipeRepository;
  final MealPlanRepository _mealPlanRepository;
  final ShoppingListRepository _shoppingListRepository;
  final StorageService _storage;

  RecommendNotifier({
    required Ref ref,
    required AIService aiService,
    required FamilyModel? currentFamily,
    required List<IngredientModel> inventory,
    required MealHistoryRepository historyRepository,
    required RecipeRepository recipeRepository,
    required MealPlanRepository mealPlanRepository,
    required ShoppingListRepository shoppingListRepository,
    required StorageService storage,
  })  : _ref = ref,
        _aiService = aiService,
        _currentFamily = currentFamily,
        _inventory = inventory,
        _historyRepository = historyRepository,
        _recipeRepository = recipeRepository,
        _mealPlanRepository = mealPlanRepository,
        _shoppingListRepository = shoppingListRepository,
        _storage = storage,
        super(RecommendState(
          settings: currentFamily != null
              ? RecommendSettings.withFamilySize(currentFamily.members.length)
              : RecommendSettings(),
          currentMealType: _getCurrentMealTypeStatic(),
          selectedDate: DateTime.now(),
        )) {
    // 初始化时加载已确认的菜单
    _initializeConfirmedPlan();
  }

  /// 静态方法：根据当前时间判断餐次
  static String _getCurrentMealTypeStatic() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 14) return 'lunch';
    if (hour >= 14 && hour < 21) return 'dinner';
    return 'dinner'; // 深夜默认显示晚餐
  }

  /// 初始化：加载已确认的菜单
  Future<void> _initializeConfirmedPlan() async {
    if (_currentFamily == null) return;

    try {
      // 从 MealPlanRepository 获取当前家庭的菜单
      // 首先尝试获取当前有效菜单，如果没有则获取最新的菜单
      MealPlanModel? plan = _mealPlanRepository.getCurrentMealPlan(_currentFamily.id);
      if (plan == null) {
        final plans = _mealPlanRepository.getMealPlansByFamily(_currentFamily.id);
        if (plans.isNotEmpty) {
          plan = plans.first; // 已按创建时间排序，取最新的
        }
      }

      if (plan != null && _hasTodayOrFutureMeals(plan)) {
        // 有有效菜单，转换为 DayPlan 列表
        final confirmedDayPlans = _convertMealPlanToDayPlans(plan);

        if (confirmedDayPlans.isNotEmpty) {
          // 找到今天对应的索引，如果没有则默认第一个
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int initialIndex = confirmedDayPlans.indexWhere((d) =>
              d.date.year == today.year &&
              d.date.month == today.month &&
              d.date.day == today.day);
          if (initialIndex < 0) initialIndex = 0;

          state = state.copyWith(
            viewMode: RecommendViewMode.confirmed,
            confirmedPlan: plan,
            confirmedDayPlans: confirmedDayPlans,
            currentMealType: _getCurrentMealTypeStatic(),
            selectedDate: confirmedDayPlans[initialIndex].date,
            selectedDayIndex: initialIndex,
          );
          return;
        }
      }

      // 无有效菜单，保持生成模式
      state = state.copyWith(
        viewMode: RecommendViewMode.generate,
      );
    } catch (e, stack) {
      logger.error('RecommendNotifier', '初始化', '加载已确认菜单失败', error: e, stackTrace: stack);
      state = state.copyWith(viewMode: RecommendViewMode.generate);
    }
  }

  /// 检查菜单是否包含今天或未来的餐次
  bool _hasTodayOrFutureMeals(MealPlanModel plan) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return plan.days.any((day) {
      final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
      return !dayDate.isBefore(today) && day.meals.isNotEmpty;
    });
  }

  /// 将 MealPlanModel 转换为 DayPlan 列表
  /// 只返回包含有效菜谱的 DayPlan
  List<DayPlan> _convertMealPlanToDayPlans(MealPlanModel plan) {
    final dayPlans = <DayPlan>[];

    for (int i = 0; i < plan.days.length; i++) {
      final dayModel = plan.days[i];

      MealRecommend breakfast = const MealRecommend(type: 'breakfast', typeName: '早餐');
      MealRecommend lunch = const MealRecommend(type: 'lunch', typeName: '午餐');
      MealRecommend dinner = const MealRecommend(type: 'dinner', typeName: '晚餐');
      MealRecommend snacks = const MealRecommend(type: 'snacks', typeName: '甜点');

      for (final meal in dayModel.meals) {
        // 从 recipeIds 获取菜谱详情
        final recipes = <RecipeModel>[];
        for (final recipeId in meal.recipeIds) {
          final recipe = _recipeRepository.getRecipeById(recipeId);
          if (recipe != null) {
            recipes.add(recipe);
          }
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

      final dayPlan = DayPlan(
        dayIndex: i,
        date: dayModel.date,
        breakfast: breakfast,
        lunch: lunch,
        dinner: dinner,
        snacks: snacks,
      );

      // 只添加有菜谱的 DayPlan
      if (dayPlan.hasAnyRecipes) {
        dayPlans.add(dayPlan);
      }
    }

    // 确保按日期排序
    dayPlans.sort((a, b) => a.date.compareTo(b.date));

    return dayPlans;
  }

  /// 切换到生成模式
  void switchToGenerateMode() {
    state = state.copyWith(viewMode: RecommendViewMode.generate);
  }

  /// 切换到已确认模式（如果有有效菜单）
  void switchToConfirmedMode() {
    if (state.hasValidConfirmedPlan) {
      state = state.copyWith(viewMode: RecommendViewMode.confirmed);
    }
  }

  /// 更新选中的日期和索引
  void selectDate(DateTime date, {int? index}) {
    // 如果没有提供索引，尝试根据日期找到索引
    int newIndex = index ?? -1;
    if (newIndex < 0) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      newIndex = state.confirmedDayPlans.indexWhere((d) =>
          d.date.year == normalizedDate.year &&
          d.date.month == normalizedDate.month &&
          d.date.day == normalizedDate.day);
    }

    state = state.copyWith(selectedDate: date, selectedDayIndex: newIndex >= 0 ? newIndex : state.selectedDayIndex);
  }

  /// 刷新已确认菜单（重新从数据库加载）
  Future<void> refreshConfirmedPlan() async {
    await _initializeConfirmedPlan();
  }

  /// 从推荐菜单中移除已吃的菜谱
  /// [recipeId] - 菜谱ID
  /// [date] - 可选，限定日期
  /// [mealType] - 可选，限定餐次（breakfast/lunch/dinner/snack）
  Future<bool> removeEatenRecipe({
    required String recipeId,
    DateTime? date,
    String? mealType,
  }) async {
    if (_currentFamily == null) return false;

    final removed = await _mealPlanRepository.removeRecipeFromPlan(
      familyId: _currentFamily!.id,
      recipeId: recipeId,
      date: date,
      mealType: mealType,
    );

    if (removed) {
      // 刷新已确认菜单显示
      await refreshConfirmedPlan();
    }

    return removed;
  }

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

  /// v1.2: 更新菜单开始日期
  void updateStartDate(DateTime date) {
    state = state.copyWith(
      settings: state.settings.copyWith(startDate: date),
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
      // v1.2: 使用设置中的 startDate，而非今天
      final startDate = DateTime(
        settings.startDate.year,
        settings.startDate.month,
        settings.startDate.day,
      );

      if (result.days.isNotEmpty) {
        for (int i = 0; i < result.days.length; i++) {
          final dayData = result.days[i];
          final date = startDate.add(Duration(days: i));

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
      logger.error('RecommendNotifier', '生成推荐', '生成推荐失败', error: e, stackTrace: stackTrace);
      state = state.copyWith(isInitialLoading: false, globalError: '生成推荐失败，请检查网络后重试');
    }
  }

  /// 刷新单个餐次
  Future<void> refreshMeal(String mealType) async {
    if (_currentFamily == null) {
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
    // 只考虑数量大于0的食材为"有库存"
    final availableInventory = _inventory
        .where((i) => i.quantity > 0)
        .map((i) => i.name.toLowerCase())
        .toSet();
    return recipe.ingredients
        .where((ing) => !ing.isOptional)
        .where((ing) => !availableInventory.contains(ing.name.toLowerCase()))
        .map((ing) => ing.name)
        .toList();
  }

  /// 检查是否食材齐全
  bool hasAllIngredients(RecipeModel recipe) {
    return getMissingIngredients(recipe).isEmpty;
  }

  /// 保存当前推荐到菜单历史
  Future<bool> saveToHistory() async {
    const page = 'RecommendProvider';
    const action = '保存到历史';

    logger.info(page, action, '开始保存', data: {
      'hasFamily': _currentFamily != null,
      'dayPlansCount': state.dayPlans.length,
    });

    if (_currentFamily == null || state.dayPlans.isEmpty) {
      logger.warning(page, action, '无法保存：缺少必要数据', data: {
        'hasFamily': _currentFamily != null,
        'dayPlansCount': state.dayPlans.length,
      });
      return false;
    }

    try {
      // v1.2.2: 转换 DayPlan 到 DayPlanModel 用于合并
      final newDayPlanModels = <DayPlanModel>[];
      for (final dayPlan in state.dayPlans) {
        final meals = <MealModel>[];

        if (dayPlan.breakfast.recipes.isNotEmpty) {
          meals.add(MealModel(
            type: 'breakfast',
            recipeIds: dayPlan.breakfast.recipes.map((r) => r.id).toList(),
            notes: dayPlan.breakfast.recipes.map((r) => r.name).join('、'),
          ));
        }
        if (dayPlan.lunch.recipes.isNotEmpty) {
          meals.add(MealModel(
            type: 'lunch',
            recipeIds: dayPlan.lunch.recipes.map((r) => r.id).toList(),
            notes: dayPlan.lunch.recipes.map((r) => r.name).join('、'),
          ));
        }
        if (dayPlan.dinner.recipes.isNotEmpty) {
          meals.add(MealModel(
            type: 'dinner',
            recipeIds: dayPlan.dinner.recipes.map((r) => r.id).toList(),
            notes: dayPlan.dinner.recipes.map((r) => r.name).join('、'),
          ));
        }
        if (dayPlan.snacks.recipes.isNotEmpty) {
          meals.add(MealModel(
            type: 'snack',
            recipeIds: dayPlan.snacks.recipes.map((r) => r.id).toList(),
            notes: dayPlan.snacks.recipes.map((r) => r.name).join('、'),
          ));
        }

        newDayPlanModels.add(DayPlanModel(
          date: dayPlan.date,
          meals: meals,
        ));
      }

      // v1.2.2: 使用 mergeMenuPlan 合并到现有菜单，而不是创建新菜单
      // 这样多次生成的菜单会合并显示（如：先生成早餐+甜点，再生成午餐，结果会合并）
      final mergedPlan = await _mealPlanRepository.mergeMenuPlan(
        familyId: _currentFamily!.id,
        newDays: newDayPlanModels,
        replaceExisting: true, // 覆盖同日期同餐次的数据
        notes: _buildNutritionSummary(),
      );

      logger.info(page, action, '菜单已合并保存到数据库', data: {
        'planId': mergedPlan.id,
        'daysCount': mergedPlan.days.length,
      });

      // v1.2.2: 保存后重新加载合并后的完整数据
      await refreshConfirmedPlan();

      // v1.2: 保存成功后自动切换到已确认模式
      // confirmedPlan 和 confirmedDayPlans 已在 refreshConfirmedPlan() 中更新
      final startDate = state.dayPlans.first.date;
      state = state.copyWith(
        viewMode: RecommendViewMode.confirmed,
        currentMealType: _getCurrentMealTypeStatic(),
        selectedDate: startDate, // 使用菜单的开始日期
      );

      logger.info(page, action, '已切换到确认模式', data: {
        'viewMode': state.viewMode.toString(),
        'confirmedDayPlansCount': state.confirmedDayPlans.length,
        'selectedDate': state.selectedDate.toString(),
      });

      // 通知其他 Provider 刷新
      _ref.invalidate(mealPlanRepositoryProvider);
      _ref.invalidate(menuListProvider);

      return true;
    } catch (e, stack) {
      // 保存失败，保持当前状态
      logger.error(page, action, '保存菜单历史失败', error: e, stackTrace: stack);
      return false;
    }
  }

  /// v1.2: 从已确认菜单生成购物清单
  /// 返回生成的购物清单 ID，如果失败返回 null
  /// 如果已有关联清单则更新，否则创建新的
  /// v1.2.1: 带日期和用量溯源信息
  Future<String?> generateShoppingListFromConfirmedMenu() async {
    const page = 'RecommendProvider';
    const action = '生成购物清单';

    logger.info(page, action, '开始生成购物清单');

    if (_currentFamily == null) {
      logger.warning(page, action, '当前家庭为空，无法生成购物清单');
      return null;
    }

    // 优先使用 confirmedDayPlans，如果为空则回退到 dayPlans
    final dayPlansToUse = state.confirmedDayPlans.isNotEmpty
        ? state.confirmedDayPlans
        : state.dayPlans;

    if (dayPlansToUse.isEmpty) {
      logger.warning(page, action, '没有可用的日计划', data: {
        'viewMode': state.viewMode.toString(),
        'confirmedPlanId': state.confirmedPlan?.id,
        'confirmedDayPlansCount': state.confirmedDayPlans.length,
        'dayPlansCount': state.dayPlans.length,
      });
      return null;
    }

    logger.info(page, action, '使用日计划生成购物清单', data: {
      'source': state.confirmedDayPlans.isNotEmpty ? 'confirmedDayPlans' : 'dayPlans',
      'count': dayPlansToUse.length,
    });

    try {
      // 收集所有菜谱，并附带日期和餐次信息
      final recipesWithDates = <RecipeWithDateInfo>[];
      for (final dayPlan in dayPlansToUse) {
        // 早餐
        for (final recipe in dayPlan.breakfast.recipes) {
          recipesWithDates.add(RecipeWithDateInfo(
            recipe: recipe,
            date: dayPlan.date,
            mealType: 'breakfast',
          ));
        }
        // 午餐
        for (final recipe in dayPlan.lunch.recipes) {
          recipesWithDates.add(RecipeWithDateInfo(
            recipe: recipe,
            date: dayPlan.date,
            mealType: 'lunch',
          ));
        }
        // 晚餐
        for (final recipe in dayPlan.dinner.recipes) {
          recipesWithDates.add(RecipeWithDateInfo(
            recipe: recipe,
            date: dayPlan.date,
            mealType: 'dinner',
          ));
        }
        // 加餐/甜点
        for (final recipe in dayPlan.snacks.recipes) {
          recipesWithDates.add(RecipeWithDateInfo(
            recipe: recipe,
            date: dayPlan.date,
            mealType: 'snacks',
          ));
        }
      }

      if (recipesWithDates.isEmpty) {
        logger.warning(page, action, '没有找到任何菜谱', data: {
          'confirmedDayPlansCount': state.confirmedDayPlans.length,
        });
        return null;
      }

      logger.info(page, action, '找到菜谱', data: {
        'recipesCount': recipesWithDates.length,
        'inventoryCount': _inventory.length,
      });

      final mealPlanId = state.confirmedPlan?.id;

      // 检查是否已有关联的购物清单
      ShoppingListModel? existingList;
      if (mealPlanId != null) {
        existingList =
            _shoppingListRepository.getShoppingListByMealPlanId(mealPlanId);
      }

      if (existingList != null) {
        // 更新已有购物清单（带日期信息）
        logger.info(page, action, '更新已有购物清单', data: {
          'existingListId': existingList.id,
        });
        await _shoppingListRepository.updateShoppingListItemsWithDates(
          shoppingListId: existingList.id,
          recipesWithDates: recipesWithDates,
          inventory: _inventory,
        );
        _ref.invalidate(shoppingListRepositoryProvider);
        _ref.invalidate(familyShoppingListsProvider(_currentFamily.id));
        logger.info(page, action, '购物清单更新成功', data: {
          'shoppingListId': existingList.id,
        });
        return existingList.id;
      } else {
        // 创建新的购物清单（带日期和用量溯源）
        logger.info(page, action, '创建新的购物清单');
        final shoppingList = _shoppingListRepository.generateFromRecipesWithDates(
          familyId: _currentFamily.id,
          recipesWithDates: recipesWithDates,
          inventory: _inventory,
          mealPlanId: mealPlanId,
        );

        await _shoppingListRepository.saveShoppingList(shoppingList);
        _ref.invalidate(shoppingListRepositoryProvider);
        _ref.invalidate(familyShoppingListsProvider(_currentFamily.id));
        logger.info(page, action, '购物清单生成成功', data: {
          'shoppingListId': shoppingList.id,
          'itemsCount': shoppingList.items.length,
        });
        return shoppingList.id;
      }
    } catch (e, stack) {
      logger.error(page, action, '生成购物清单时发生异常',
          error: e, stackTrace: stack);
      return null;
    }
  }

  String? _buildNutritionSummary() {
    final totalRecipes = state.dayPlans.fold<int>(
      0,
      (sum, day) =>
          sum +
          day.breakfast.recipes.length +
          day.lunch.recipes.length +
          day.dinner.recipes.length +
          day.snacks.recipes.length,
    );
    return '${state.dayPlans.length}天计划，共$totalRecipes道菜';
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
  final mealPlanRepository = ref.watch(mealPlanRepositoryProvider);
  final shoppingListRepository = ref.watch(shoppingListRepositoryProvider);
  final storage = ref.watch(storageServiceProvider);

  return RecommendNotifier(
    ref: ref,
    aiService: aiService,
    currentFamily: currentFamily,
    // 只传递数量大于0的食材，避免零库存食材被误认为"已有"
    inventory: inventoryState.ingredients.where((i) => i.quantity > 0).toList(),
    historyRepository: historyRepository,
    recipeRepository: recipeRepository,
    mealPlanRepository: mealPlanRepository,
    shoppingListRepository: shoppingListRepository,
    storage: storage,
  );
});
