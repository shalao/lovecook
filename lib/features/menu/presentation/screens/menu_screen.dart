import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../../recipe/data/repositories/recipe_repository.dart';
import '../../data/models/meal_plan_model.dart';
import '../../data/repositories/meal_plan_repository.dart';
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
        onPressed: () => context.push(AppRoutes.generateMenu),
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
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isToday ? '进行中' : '${plan.totalDays}天计划',
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? AppColors.primary : Colors.grey.shade600,
                            fontWeight: isToday ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateRange(plan.startDate, plan.endDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
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
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTodayMeals(plan),
                  ] else if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                    Text(
                      plan.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade400),
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

  Widget _buildTodayMeals(MealPlanModel plan) {
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
          color: Colors.grey.shade500,
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
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(meal.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                meal.notes ?? meal.label,
                style: const TextStyle(fontSize: 12),
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
                color: Colors.grey.shade300,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateRange(widget.plan.startDate, widget.plan.endDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
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
                  color: isToday ? AppColors.primary : Colors.grey.shade800,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
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
                color: Colors.grey.shade500,
              ),
            )
          else
            ...day.meals.map((meal) => _buildMealRow(context, day, meal)),
        ],
      ),
    );
  }

  Widget _buildMealRow(BuildContext context, DayPlanModel day, MealModel meal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meal.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (meal.notes != null && meal.notes!.isNotEmpty)
                  Text(
                    meal.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          // 替换按钮
          IconButton(
            icon: Icon(
              Icons.swap_horiz,
              size: 20,
              color: Colors.grey.shade500,
            ),
            onPressed: () => _showReplaceMealDialog(context, day, meal),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '替换菜品',
          ),
        ],
      ),
    );
  }

  void _showReplaceMealDialog(BuildContext context, DayPlanModel day, MealModel meal) {
    final allRecipes = ref.read(allRecipesProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('替换${meal.label}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: allRecipes.isEmpty
              ? Center(
                  child: Text(
                    '暂无可用菜谱\n请先生成菜单或添加菜谱',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: allRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = allRecipes[index];
                    final isCurrentRecipe = meal.recipeIds.contains(recipe.id);
                    return ListTile(
                      leading: recipe.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                recipe.imageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.restaurant_menu, size: 20),
                                ),
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.restaurant_menu,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                      title: Text(
                        recipe.name,
                        style: TextStyle(
                          fontWeight: isCurrentRecipe ? FontWeight.w600 : null,
                          color: isCurrentRecipe ? AppColors.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        '${recipe.totalTime}分钟 · ${recipe.servings}人份',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      trailing: isCurrentRecipe
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => _replaceMeal(context, day, meal, recipe),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _replaceMeal(
    BuildContext context,
    DayPlanModel day,
    MealModel meal,
    RecipeModel newRecipe,
  ) async {
    final repository = ref.read(mealPlanRepositoryProvider);

    await repository.updateMeal(
      widget.plan.id,
      day.date,
      meal.type,
      [newRecipe.id],
      notes: newRecipe.name,
    );

    // 刷新菜单列表
    ref.read(menuListProvider.notifier).loadPlans();

    if (context.mounted) {
      Navigator.pop(context); // 关闭选择对话框
      Navigator.pop(context); // 关闭详情弹窗

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将${meal.label}替换为"${newRecipe.name}"'),
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
