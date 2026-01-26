import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../data/models/recommend_settings.dart';
import '../providers/mood_chat_provider.dart';
import '../providers/recommend_provider.dart';

class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen> {
  final TextEditingController _moodController = TextEditingController();
  bool _showSettings = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendProvider);

    // 监听状态变化，显示成功/失败提示
    ref.listen<RecommendState>(recommendProvider, (previous, next) {
      // 从加载中变为加载完成
      if (previous?.isInitialLoading == true && next.isInitialLoading == false) {
        if (next.globalError != null) {
          // 显示错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.globalError!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (next.hasAnyRecommendation) {
          // 显示成功
          final dayCount = next.dayPlans.length;
          final totalRecipes = next.dayPlans.fold<int>(
            0,
            (sum, day) =>
                sum +
                day.breakfast.recipes.length +
                day.lunch.recipes.length +
                day.dinner.recipes.length +
                day.snacks.recipes.length,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已生成 $dayCount 天菜单，共 $totalRecipes 道菜'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          // 刷新全部菜谱列表，确保新生成的菜谱同步显示
          ref.invalidate(allRecipesProvider);
          // 自动保存到菜单历史
          ref.read(recommendProvider.notifier).saveToHistory();
          // 生成成功后收起设置面板
          setState(() => _showSettings = false);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(state.isConfirmedMode ? '今日菜单' : '今天吃什么'),
        actions: [
          // 已确认模式：显示生成更多按钮
          if (state.isConfirmedMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                ref.read(recommendProvider.notifier).switchToGenerateMode();
              },
              tooltip: '生成更多',
            ),
          // 生成模式：显示设置和刷新按钮
          if (!state.isConfirmedMode) ...[
            if (state.hasAnyRecommendation)
              IconButton(
                icon: Icon(_showSettings ? Icons.expand_less : Icons.settings),
                onPressed: () => setState(() => _showSettings = !_showSettings),
                tooltip: _showSettings ? '收起设置' : '显示设置',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: state.isAnyLoading
                  ? null
                  : () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
              tooltip: '重新生成',
            ),
          ],
          // 已确认模式：显示返回已确认菜单的按钮（如果有有效菜单且当前在生成模式）
          if (!state.isConfirmedMode && state.hasValidConfirmedPlan)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {
                ref.read(recommendProvider.notifier).switchToConfirmedMode();
              },
              tooltip: '返回菜单',
            ),
        ],
      ),
      body: state.isConfirmedMode
          ? _buildConfirmedView(state)
          : _buildGenerateView(state),
    );
  }

  /// 已确认菜单视图
  Widget _buildConfirmedView(RecommendState state) {
    final selectedDayPlan = state.selectedDayPlan;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 日期导航
        _buildDateNavigator(state),

        // 菜单内容
        Expanded(
          child: selectedDayPlan == null
              ? _buildNoMenuPlaceholder()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日期标题
                      _buildConfirmedDateHeader(selectedDayPlan),
                      const SizedBox(height: 16),

                      // 各餐次
                      if (selectedDayPlan.breakfast.recipes.isNotEmpty)
                        _buildConfirmedMealSection(
                          selectedDayPlan.breakfast,
                          state.currentMealType == 'breakfast',
                        ),
                      if (selectedDayPlan.lunch.recipes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildConfirmedMealSection(
                          selectedDayPlan.lunch,
                          state.currentMealType == 'lunch',
                        ),
                      ],
                      if (selectedDayPlan.dinner.recipes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildConfirmedMealSection(
                          selectedDayPlan.dinner,
                          state.currentMealType == 'dinner',
                        ),
                      ],
                      if (selectedDayPlan.snacks.recipes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildConfirmedMealSection(
                          selectedDayPlan.snacks,
                          state.currentMealType == 'snacks',
                        ),
                      ],

                      // 如果当天没有任何菜品
                      if (!selectedDayPlan.hasAnyRecipes)
                        _buildEmptyDayPlaceholder(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),

        // 底部操作栏
        _buildConfirmedBottomBar(state),
      ],
    );
  }

  /// 日期导航器
  Widget _buildDateNavigator(RecommendState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 获取有效的日期范围
    final dayPlans = state.confirmedDayPlans;
    if (dayPlans.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : Colors.grey[200]!,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: dayPlans.length,
        itemBuilder: (context, index) {
          final dayPlan = dayPlans[index];
          final isSelected = state.selectedDate.year == dayPlan.date.year &&
              state.selectedDate.month == dayPlan.date.month &&
              state.selectedDate.day == dayPlan.date.day;
          final isToday = dayPlan.date.year == today.year &&
              dayPlan.date.month == today.month &&
              dayPlan.date.day == today.day;

          return GestureDetector(
            onTap: () {
              ref.read(recommendProvider.notifier).selectDate(dayPlan.date);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : (isDark ? AppColors.inputBackgroundDark : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? AppColors.borderDark : Colors.grey[300]!),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayPlan.dayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.textPrimaryDark : Colors.black87),
                    ),
                  ),
                  Text(
                    '${dayPlan.date.month}/${dayPlan.date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: isSelected
                          ? Colors.white70
                          : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 已确认模式的日期标题
  Widget _buildConfirmedDateHeader(DayPlan dayPlan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            dayPlan.dayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          dayPlan.dateLabel,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 已确认模式的餐次区块
  Widget _buildConfirmedMealSection(MealRecommend meal, bool isCurrentMeal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isCurrentMeal
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentMeal
              ? Theme.of(context).primaryColor
              : (isDark ? AppColors.borderDark : Colors.grey[200]!),
          width: isCurrentMeal ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐次标题
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _getMealIcon(meal.type),
                const SizedBox(width: 8),
                Text(
                  meal.typeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
                if (isCurrentMeal) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 菜品列表
          ...meal.recipes.asMap().entries.map((entry) {
            final index = entry.key;
            final recipe = entry.value;
            return _buildConfirmedRecipeItem(recipe, isCurrentMeal, index == meal.recipes.length - 1);
          }),
        ],
      ),
    );
  }

  /// 已确认模式的菜品项
  Widget _buildConfirmedRecipeItem(RecipeModel recipe, bool isCurrentMeal, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(recommendProvider.notifier);
    final hasAllIngredients = notifier.hasAllIngredients(recipe);
    final missingIngredients = notifier.getMissingIngredients(recipe);
    final totalTime = recipe.prepTime + recipe.cookTime;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : Colors.grey[100]!,
                ),
              ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: _getColorForRecipe(recipe),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          recipe.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : Colors.black87,
          ),
        ),
        subtitle: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                ),
                const SizedBox(width: 2),
                Text(
                  '$totalTime分钟',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (hasAllIngredients)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green[600]),
                  const SizedBox(width: 2),
                  Text(
                    '食材齐全',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                ],
              )
            else
              Text(
                '缺${missingIngredients.length}样',
                style: TextStyle(fontSize: 12, color: Colors.orange[600]),
              ),
          ],
        ),
        trailing: isCurrentMeal
            ? ElevatedButton(
                onPressed: () {
                  context.push('${AppRoutes.recipes}/${recipe.id}');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('开始做'),
              )
            : IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
                ),
                onPressed: () {
                  context.push('${AppRoutes.recipes}/${recipe.id}');
                },
              ),
        onTap: () {
          context.push('${AppRoutes.recipes}/${recipe.id}');
        },
      ),
    );
  }

  /// 已确认模式底部操作栏
  Widget _buildConfirmedBottomBar(RecommendState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(AppRoutes.menu);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('调整菜单'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                // 生成购物清单
                final shoppingListId = await ref
                    .read(recommendProvider.notifier)
                    .generateShoppingListFromConfirmedMenu();

                if (!mounted) return;

                if (shoppingListId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已生成购物清单'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // 跳转到购物清单页面
                context.push(AppRoutes.shopping);
              },
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('生成清单'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(recommendProvider.notifier).switchToGenerateMode();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('生成更多'),
            ),
          ),
        ],
      ),
    );
  }

  /// 无菜单占位符
  Widget _buildNoMenuPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无菜单',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮生成今日菜单',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 空日期占位符
  Widget _buildEmptyDayPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '该天暂无菜单安排',
          style: TextStyle(
            color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  /// 根据菜谱名生成颜色
  Color _getColorForRecipe(RecipeModel recipe) {
    final hash = recipe.name.hashCode;
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF607D8B),
    ];
    return colors[hash.abs() % colors.length];
  }

  /// 生成推荐视图（原有逻辑）
  Widget _buildGenerateView(RecommendState state) {
    if (state.isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在为你生成推荐...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 问候语
          _buildGreeting(),
          const SizedBox(height: 16),

          // 设置面板
          if (_showSettings || !state.hasAnyRecommendation) ...[
            _buildSettingsPanel(state),
            const SizedBox(height: 16),

            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isAnyLoading
                    ? null
                    : () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
                icon: const Icon(Icons.auto_awesome),
                label: Text(state.hasAnyRecommendation ? '重新生成' : '生成推荐'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 错误提示
          if (state.globalError != null)
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.red.withOpacity(0.4) : Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: isDark ? Colors.red[400] : Colors.red[400], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.globalError!,
                          style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // 推荐结果
          if (state.hasAnyRecommendation) ...[
            // 显示生成结果统计
            _buildResultSummary(state),
            // 保存到历史按钮
            _buildSaveButton(state),
            const SizedBox(height: 16),

            // 多天显示 - 当请求的天数 > 1 或实际返回天数 > 1 时使用多天视图
            if (state.settings.days > 1 || state.dayPlans.length > 1)
              ..._buildMultiDayView(state)
            else
              ..._buildSingleDayView(state),
          ],
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String greeting;
    IconData icon;

    if (hour < 6) {
      greeting = '夜深了';
      icon = Icons.nights_stay;
    } else if (hour < 11) {
      greeting = '早上好';
      icon = Icons.wb_sunny_outlined;
    } else if (hour < 14) {
      greeting = '中午好';
      icon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = '下午好';
      icon = Icons.wb_cloudy;
    } else {
      greeting = '晚上好';
      icon = Icons.nights_stay;
    }

    return Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Text(
          '$greeting，想吃点什么？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(RecommendState state) {
    final settings = state.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 天数选择
          _buildSectionTitle('📅 天数'),
          const SizedBox(height: 8),
          _buildDaysSelector(settings),
          const SizedBox(height: 16),

          // v1.2: 开始日期选择
          _buildSectionTitle('🗓️ 开始日期'),
          const SizedBox(height: 8),
          _buildStartDateSelector(settings),
          const SizedBox(height: 16),

          // 餐次选择
          _buildSectionTitle('🍽️ 餐次'),
          const SizedBox(height: 8),
          _buildMealTypeSelector(settings),
          const SizedBox(height: 16),

          // 每餐菜品数
          _buildSectionTitle('🥢 每餐菜品数'),
          const SizedBox(height: 8),
          _buildDishesSelector(settings),
          const SizedBox(height: 16),

          // 心情/口味输入
          _buildSectionTitle('💭 今天的心情/想法（可选）'),
          const SizedBox(height: 8),
          _buildMoodInput(settings),
          const SizedBox(height: 12),

          // 快捷标签
          _buildQuickTags(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : Colors.black87,
      ),
    );
  }

  Widget _buildDaysSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Wrap(
      spacing: 8,
      children: RecommendSettings.availableDays.map((day) {
        final isSelected = settings.days == day;
        return ChoiceChip(
          label: Text(
            '$day天',
            style: TextStyle(
              color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              height: 1.2,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => ref.read(recommendProvider.notifier).updateDays(day),
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
          selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
          side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelPadding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.comfortable,
        );
      }).toList(),
    );
  }

  /// v1.2: 开始日期选择器
  Widget _buildStartDateSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      settings.startDate.year,
      settings.startDate.month,
      settings.startDate.day,
    );

    // 判断日期标签
    String dateLabel;
    if (startDate.isAtSameMomentAs(today)) {
      dateLabel = '今天';
    } else if (startDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      dateLabel = '明天';
    } else if (startDate.isAtSameMomentAs(today.add(const Duration(days: 2)))) {
      dateLabel = '后天';
    } else {
      dateLabel = '${startDate.month}月${startDate.day}日';
    }

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: settings.startDate,
          firstDate: today,
          lastDate: today.add(const Duration(days: 30)),
          helpText: '选择菜单开始日期',
          cancelText: '取消',
          confirmText: '确定',
        );
        if (date != null) {
          ref.read(recommendProvider.notifier).updateStartDate(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.inputBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.borderDark : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                    ),
                  ),
                  Text(
                    '${startDate.year}年${startDate.month}月${startDate.day}日',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    Widget buildMealChip(String emoji, String label, bool selected, Function(bool) onSelected) {
      return FilterChip(
        avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
        label: Text(
          label,
          style: TextStyle(
            color: selected ? (isDark ? Colors.white : AppColors.primary) : textColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
        selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
        side: isDark ? BorderSide(color: selected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
        checkmarkColor: isDark ? Colors.white : AppColors.primary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelPadding: const EdgeInsets.only(left: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.comfortable,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildMealChip('🌅', '早餐', settings.breakfast, (v) => ref.read(recommendProvider.notifier).updateMealType(breakfast: v)),
        buildMealChip('☀️', '午餐', settings.lunch, (v) => ref.read(recommendProvider.notifier).updateMealType(lunch: v)),
        buildMealChip('🌙', '晚餐', settings.dinner, (v) => ref.read(recommendProvider.notifier).updateMealType(dinner: v)),
        buildMealChip('🍰', '甜点', settings.snacks, (v) => ref.read(recommendProvider.notifier).updateMealType(snacks: v)),
      ],
    );
  }

  Widget _buildDishesSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: RecommendSettings.availableDishesPerMeal.map((dishes) {
            final isSelected = settings.dishesPerMeal == dishes;
            return ChoiceChip(
              label: Text(
                '$dishes道',
                style: TextStyle(
                  color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => ref.read(recommendProvider.notifier).updateDishesPerMeal(dishes),
              elevation: 0,
              pressElevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
              selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
              side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelPadding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.comfortable,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '根据家庭人数自动推荐',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodInput(RecommendSettings settings) {
    // 同步输入框内容
    if (_moodController.text != (settings.moodInput ?? '')) {
      _moodController.text = settings.moodInput ?? '';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : Colors.grey[300]!;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _moodController,
            decoration: InputDecoration(
              hintText: '例如：想吃点清淡的...',
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: settings.moodInput?.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _moodController.clear();
                        ref.read(recommendProvider.notifier).clearMoodInput();
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(recommendProvider.notifier).updateMoodInput(value);
            },
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // 实时语音按钮
        IconButton(
          icon: const Icon(Icons.surround_sound),
          onPressed: () {
            // 跳转到聊天页面并启用实时语音模式
            ref.read(moodChatProvider.notifier).setVoiceMode(VoiceInputMode.realtime);
            context.push(AppRoutes.moodChat);
          },
          tooltip: '实时语音对话',
          style: IconButton.styleFrom(
            backgroundColor: inputBgColor,
            foregroundColor: isDark ? AppColors.textPrimaryDark : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 聊聊按钮
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () {
            context.push(AppRoutes.moodChat);
          },
          tooltip: '和AI聊聊',
          style: IconButton.styleFrom(
            backgroundColor: inputBgColor,
            foregroundColor: isDark ? AppColors.textPrimaryDark : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecommendSettings.quickMoodTags.map((tag) {
        return ActionChip(
          label: Text(
            tag,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          onPressed: () {
            ref.read(recommendProvider.notifier).addMoodTag(tag);
          },
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
          side: isDark ? BorderSide(color: AppColors.borderDark) : BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelPadding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.comfortable,
        );
      }).toList(),
    );
  }

  /// 构建结果统计
  Widget _buildResultSummary(RecommendState state) {
    final dayCount = state.dayPlans.length;
    final requestedDays = state.settings.days;
    final totalRecipes = state.dayPlans.fold<int>(
      0,
      (sum, day) =>
          sum +
          day.breakfast.recipes.length +
          day.lunch.recipes.length +
          day.dinner.recipes.length +
          day.snacks.recipes.length,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dayCount >= requestedDays
                  ? '已生成 $dayCount 天菜单，共 $totalRecipes 道菜'
                  : '已生成 $dayCount/$requestedDays 天菜单，共 $totalRecipes 道菜',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (dayCount < requestedDays)
            Tooltip(
              message: '部分天数生成失败，可尝试重新生成',
              child: Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建保存到历史按钮
  Widget _buildSaveButton(RecommendState state) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: OutlinedButton.icon(
        onPressed: state.hasAnyRecommendation
            ? () async {
                final success = await ref.read(recommendProvider.notifier).saveToHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '菜单已保存到历史' : '保存失败'),
                      backgroundColor: success ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            : null,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('保存到历史'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
    );
  }

  /// 构建单天视图
  List<Widget> _buildSingleDayView(RecommendState state) {
    final dayPlan = state.dayPlans.isNotEmpty ? state.dayPlans.first : null;
    final breakfast = dayPlan?.breakfast ?? state.breakfast;
    final lunch = dayPlan?.lunch ?? state.lunch;
    final dinner = dayPlan?.dinner ?? state.dinner;
    final snacks = dayPlan?.snacks ?? state.snacks;

    return [
      // 早餐
      if (state.settings.breakfast && breakfast.recipes.isNotEmpty)
        _buildMealSection(breakfast),

      // 午餐
      if (state.settings.lunch && lunch.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(lunch),
      ],

      // 晚餐
      if (state.settings.dinner && dinner.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(dinner),
      ],

      // 甜点/加餐
      if (state.settings.snacks && snacks.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(snacks),
      ],
    ];
  }

  /// 构建多天视图
  List<Widget> _buildMultiDayView(RecommendState state) {
    final widgets = <Widget>[];
    final requestedDays = state.settings.days;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 遍历请求的天数，而不仅仅是返回的天数
    for (int i = 0; i < requestedDays; i++) {
      // 尝试获取对应天的数据
      final dayPlan = i < state.dayPlans.length ? state.dayPlans[i] : null;
      final date = today.add(Duration(days: i));

      if (i > 0) {
        widgets.add(const SizedBox(height: 24));
      }

      // 计算天数标签
      String dayLabel;
      if (i == 0) {
        dayLabel = '今天';
      } else if (i == 1) {
        dayLabel = '明天';
      } else if (i == 2) {
        dayLabel = '后天';
      } else {
        dayLabel = '第${i + 1}天';
      }
      final dateLabel = '${date.month}月${date.day}日';

      // 日期标题
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dayPlan != null
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                ),
              ),
              if (dayPlan == null) ...[
                const Spacer(),
                Text(
                  '未生成',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.orange[400] : Colors.orange[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      // 如果没有该天的数据，显示提示
      if (dayPlan == null) {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.orange.withOpacity(0.4) : Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: isDark ? Colors.orange[400] : Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '该天菜单未能生成，请尝试重新生成',
                    style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 当天的餐次
      bool hasAnyMeal = false;

      if (state.settings.breakfast && dayPlan.breakfast.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.breakfast, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.lunch && dayPlan.lunch.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.lunch, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.dinner && dayPlan.dinner.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.dinner, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.snacks && dayPlan.snacks.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.snacks, showRefresh: false));
        hasAnyMeal = true;
      }

      // 如果该天没有任何餐次数据
      if (!hasAnyMeal) {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '该天暂无推荐菜品',
                style: TextStyle(color: isDark ? AppColors.textTertiaryDark : Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildMealSection(MealRecommend meal, {bool showRefresh = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            _getMealIcon(meal.type),
            const SizedBox(width: 8),
            Text(
              meal.typeName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : null,
              ),
            ),
            const Spacer(),
            if (showRefresh) ...[
              if (meal.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () =>
                      ref.read(recommendProvider.notifier).refreshMeal(meal.type),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('换一换'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // 菜品列表
        if (meal.error != null)
          _buildErrorCard(meal.error!)
        else if (meal.recipes.isEmpty)
          _buildEmptyCard()
        else
          _buildRecipeCards(meal.recipes),
      ],
    );
  }

  Widget _getMealIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'breakfast':
        icon = Icons.wb_sunny_outlined;
        color = Colors.orange;
        break;
      case 'lunch':
        icon = Icons.wb_sunny;
        color = Colors.amber;
        break;
      case 'dinner':
        icon = Icons.nights_stay_outlined;
        color = Colors.indigo;
        break;
      case 'snacks':
        icon = Icons.cake_outlined;
        color = Colors.pink;
        break;
      default:
        icon = Icons.restaurant;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildErrorCard(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.red.withOpacity(0.4) : Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: isDark ? Colors.red[400] : Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '暂无推荐',
          style: TextStyle(color: isDark ? AppColors.textTertiaryDark : Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildRecipeCards(List<RecipeModel> recipes) {
    // 使用列表布局替代网格，更清晰
    return Column(
      children: recipes.map((recipe) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RecipeCard(recipe: recipe),
      )).toList(),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final RecipeModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recommendProvider.notifier);
    final hasAllIngredients = notifier.hasAllIngredients(recipe);
    final missingIngredients = notifier.getMissingIngredients(recipe);
    final totalTime = recipe.prepTime + recipe.cookTime;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('${AppRoutes.recipes}/${recipe.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧色块标识
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: _getColorForRecipe(recipe),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 菜名
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.textPrimaryDark : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 时间和标签
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$totalTime分钟',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                        ),
                      ),
                      if (recipe.difficulty != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recipe.difficulty!,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 右侧状态
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasAllIngredients)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: isDark ? Colors.green[400] : Colors.green[600]),
                        const SizedBox(width: 2),
                        Text(
                          '齐全',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.green[300] : Colors.green[700]),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '缺${missingIngredients.length}样',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.orange[300] : Colors.orange[700]),
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 20, color: isDark ? AppColors.textTertiaryDark : Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForRecipe(RecipeModel recipe) {
    final hash = recipe.name.hashCode;
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF607D8B),
    ];
    return colors[hash.abs() % colors.length];
  }
}
