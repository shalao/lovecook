import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../data/models/meal_plan_model.dart';
import '../../data/repositories/meal_plan_repository.dart';
import '../../../recommend/presentation/providers/recommend_provider.dart';
import '../providers/menu_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('菜单计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(menuListProvider.notifier).loadPlans(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.plans.isEmpty
              ? _buildEmptyState(context)
              : _buildMenuList(context, ref, state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.recommend),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成菜单'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无菜单计划',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮生成本周菜单',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, WidgetRef ref, MenuListState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.plans.length,
      itemBuilder: (context, index) {
        final plan = state.plans[index];
        final isToday = _isDateInRange(DateTime.now(), plan.startDate, plan.endDate);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showPlanDetail(context, plan),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1)
                              : (isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isToday ? '进行中' : '${plan.totalDays}天计划',
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday
                                ? (isDark ? AppColors.primaryDark : AppColors.primary)
                                : (isDark ? AppColors.textSecondaryDark : Colors.grey.shade600),
                            fontWeight: isToday ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateRange(plan.startDate, plan.endDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Today's meals preview
                  if (isToday && plan.days.isNotEmpty) ...[
                    Text(
                      '今日菜单',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTodayMeals(context, plan),
                  ] else if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                    Text(
                      plan.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '创建于 ${_formatDate(plan.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400),
                        onPressed: () => _confirmDelete(context, ref, plan.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodayMeals(BuildContext context, MealPlanModel plan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final todayPlan = plan.days.firstWhere(
      (day) => _isSameDay(day.date, today),
      orElse: () => plan.days.first,
    );

    if (todayPlan.meals.isEmpty) {
      return Text(
        '暂无安排',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: todayPlan.meals.map((meal) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(meal.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                meal.notes ?? meal.label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textPrimaryDark : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showPlanDetail(BuildContext context, MealPlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanDetailSheet(plan: plan),
    );
  }


  void _confirmDelete(BuildContext context, WidgetRef ref, String planId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除菜单'),
        content: const Text('确定要删除这个菜单计划吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(menuListProvider.notifier).deletePlan(planId);
              // 同步刷新推荐页数据
              ref.invalidate(recommendProvider);
            },
            child: Text(
              '删除',
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 菜单计划详情弹窗
class _PlanDetailSheet extends ConsumerStatefulWidget {
  final MealPlanModel plan;

  const _PlanDetailSheet({required this.plan});

  @override
  ConsumerState<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends ConsumerState<_PlanDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${widget.plan.totalDays}天菜单计划',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateRange(widget.plan.startDate, widget.plan.endDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Days list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.plan.days.length,
                itemBuilder: (context, index) {
                  final day = widget.plan.days[index];
                  return _buildDayDetail(context, day);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetail(BuildContext context, DayPlanModel day) {
    final isToday = _isSameDay(day.date, DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.05)
            : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                day.dateFormatted,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : (isDark ? AppColors.textPrimaryDark : Colors.grey.shade800),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '今天',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (day.meals.isEmpty)
            Text(
              '暂无安排',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
              ),
            )
          else
            ...day.meals.map((meal) => _buildMealRow(context, day, meal)),
        ],
      ),
    );
  }

  Widget _buildMealRow(BuildContext context, DayPlanModel day, MealModel meal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipeNames = meal.notes?.split('、') ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐次标题行
          Row(
            children: [
              Text(meal.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                meal.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : null,
                ),
              ),
              const Spacer(),
              // 删除整个餐次按钮
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
                ),
                onPressed: () => _confirmDeleteMeal(context, day, meal),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '删除此餐',
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 每道菜品
          ...List.generate(meal.recipeIds.length, (index) {
            final recipeName = index < recipeNames.length ? recipeNames[index] : '菜品${index + 1}';
            return _buildRecipeItem(context, day, meal, index, recipeName);
          }),
        ],
      ),
    );
  }

  /// 构建单道菜品项
  Widget _buildRecipeItem(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    int recipeIndex,
    String recipeName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 14,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              recipeName,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade700,
              ),
            ),
          ),
          // 换一个按钮 (AI 重新生成)
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
            ),
            onPressed: () => _replaceRecipeWithAI(context, day, meal, recipeIndex, recipeName),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            tooltip: '换一道菜',
          ),
          // 从列表选择按钮
          IconButton(
            icon: Icon(
              Icons.swap_horiz,
              size: 18,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
            ),
            onPressed: () => _showReplaceRecipeDialog(context, day, meal, recipeIndex),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            tooltip: '从菜谱选择',
          ),
          // 删除按钮
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
            ),
            onPressed: () => _confirmDeleteRecipe(context, day, meal, recipeIndex, recipeName),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            tooltip: '删除此菜',
          ),
        ],
      ),
    );
  }

  /// 确认删除整个餐次
  void _confirmDeleteMeal(BuildContext context, DayPlanModel day, MealModel meal) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除餐次'),
        content: Text('确定要删除 ${day.dateFormatted} 的${meal.label}吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final repository = ref.read(mealPlanRepositoryProvider);
              await repository.deleteMeals(
                familyId: widget.plan.familyId,
                date: day.date,
                mealTypes: [meal.type],
              );
              ref.read(menuListProvider.notifier).loadPlans();
              // 同步刷新推荐页数据
              ref.invalidate(recommendProvider);
              if (context.mounted) {
                Navigator.pop(context); // 关闭详情弹窗
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除${meal.label}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('删除', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }

  /// 确认删除单道菜
  void _confirmDeleteRecipe(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    int recipeIndex,
    String recipeName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除菜品'),
        content: Text('确定要删除"$recipeName"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final repository = ref.read(mealPlanRepositoryProvider);
              await repository.deleteRecipeFromMeal(
                familyId: widget.plan.familyId,
                date: day.date,
                mealType: meal.type,
                recipeIndex: recipeIndex,
              );
              ref.read(menuListProvider.notifier).loadPlans();
              // 同步刷新推荐页数据
              ref.invalidate(recommendProvider);
              if (context.mounted) {
                Navigator.pop(context); // 关闭详情弹窗
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除"$recipeName"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('删除', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }

  /// 使用 AI 重新生成替换菜品
  Future<void> _replaceRecipeWithAI(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    int recipeIndex,
    String currentRecipeName,
  ) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            const Text('AI 正在生成替换菜品...'),
          ],
        ),
      ),
    );

    try {
      final notifier = ref.read(menuGenerateProvider.notifier);
      await notifier.replaceRecipe(
        date: day.date,
        mealType: meal.type,
        recipeIndex: recipeIndex,
      );

      ref.read(menuListProvider.notifier).loadPlans();

      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        Navigator.pop(context); // 关闭详情弹窗
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('菜品已替换'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('替换失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示从菜谱列表选择替换的对话框
  void _showReplaceRecipeDialog(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    int recipeIndex,
  ) {
    final allRecipes = ref.read(allRecipesProvider);
    final currentRecipeId = recipeIndex < meal.recipeIds.length ? meal.recipeIds[recipeIndex] : '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogIsDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('选择替换菜品'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: allRecipes.isEmpty
                ? Center(
                    child: Text(
                      '暂无可用菜谱\n请先生成菜单或添加菜谱',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dialogIsDark ? AppColors.textSecondaryDark : Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = allRecipes[index];
                      final isCurrentRecipe = recipe.id == currentRecipeId;
                      return ListTile(
                        leading: recipe.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  recipe.imageUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 40,
                                    height: 40,
                                    color: dialogIsDark ? AppColors.inputBackgroundDark : Colors.grey.shade200,
                                    child: const Icon(Icons.restaurant_menu, size: 20),
                                  ),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (dialogIsDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu,
                                  size: 20,
                                  color: dialogIsDark ? AppColors.primaryDark : AppColors.primary,
                                ),
                              ),
                        title: Text(
                          recipe.name,
                          style: TextStyle(
                            fontWeight: isCurrentRecipe ? FontWeight.w600 : null,
                            color: isCurrentRecipe
                                ? (dialogIsDark ? AppColors.primaryDark : AppColors.primary)
                                : (dialogIsDark ? AppColors.textPrimaryDark : null),
                          ),
                        ),
                        subtitle: Text(
                          '${recipe.totalTime}分钟 · ${recipe.servings}人份',
                          style: TextStyle(fontSize: 12, color: dialogIsDark ? AppColors.textTertiaryDark : Colors.grey.shade500),
                        ),
                        trailing: isCurrentRecipe
                            ? Icon(Icons.check, color: dialogIsDark ? AppColors.primaryDark : AppColors.primary)
                            : null,
                        onTap: () => _replaceRecipeFromList(dialogContext, day, meal, recipeIndex, recipe),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 从列表选择替换菜品
  Future<void> _replaceRecipeFromList(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    int recipeIndex,
    RecipeModel newRecipe,
  ) async {
    final repository = ref.read(mealPlanRepositoryProvider);

    await repository.replaceRecipeInMeal(
      familyId: widget.plan.familyId,
      date: day.date,
      mealType: meal.type,
      recipeIndex: recipeIndex,
      newRecipeId: newRecipe.id,
      newRecipeName: newRecipe.name,
    );

    ref.read(menuListProvider.notifier).loadPlans();

    if (context.mounted) {
      Navigator.pop(context); // 关闭选择对话框
      Navigator.pop(context); // 关闭详情弹窗
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已替换为"${newRecipe.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }
}
