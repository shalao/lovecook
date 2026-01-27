import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../menu/data/repositories/meal_plan_repository.dart';
import '../../../recommend/presentation/providers/recommend_provider.dart';
import '../../data/models/recipe_model.dart';
import '../../data/repositories/recipe_repository.dart';

/// 完成烹饪对话框返回的结果
class _CompleteCookingResult {
  final String recipeName;
  final String mealType;
  final int deductedCount;
  final int notFoundCount;
  final bool deductInventory;

  _CompleteCookingResult({
    required this.recipeName,
    required this.mealType,
    required this.deductedCount,
    required this.notFoundCount,
    required this.deductInventory,
  });
}

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _isTogglingFavorite = false;

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeByIdProvider(widget.recipeId));

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('菜谱详情'),
        ),
        body: const Center(
          child: Text('菜谱不存在'),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCompleteCookingDialog(context, recipe),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('已吃'),
        backgroundColor: Colors.green,
      ),
      body: CustomScrollView(
        slivers: [
          // 头部
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.name,
                style: const TextStyle(
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.8),
                      Theme.of(context).primaryColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            actions: [
              // v1.2: 添加到菜单
              IconButton(
                icon: const Icon(Icons.add_chart),
                tooltip: '添加到菜单',
                onPressed: () {
                  _showAddToMenuDialog(context, recipe);
                },
              ),
              // 进入烹饪模式
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: '烹饪模式',
                onPressed: () {
                  context.push(AppRoutes.cookingMode, extra: recipe);
                },
              ),
              // 收藏
              IconButton(
                icon: _isTogglingFavorite
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        recipe.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        color: recipe.isFavorite ? Colors.amber : null,
                      ),
                onPressed: _isTogglingFavorite
                    ? null
                    : () async {
                        setState(() => _isTogglingFavorite = true);
                        try {
                          final currentFamily = ref.read(currentFamilyProvider);
                          // 等待收藏操作完成后再刷新
                          await ref.read(recipeRepositoryProvider).toggleFavorite(widget.recipeId);
                          ref.invalidate(recipeByIdProvider(widget.recipeId));
                          ref.invalidate(allRecipesProvider);
                          // 刷新收藏列表，确保收藏状态同步
                          ref.invalidate(favoriteRecipesProvider(currentFamily?.id));
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('收藏操作失败: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isTogglingFavorite = false);
                          }
                        }
                      },
              ),
            ],
          ),

          // 内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 简介
                  if (recipe.description != null) ...[
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Text(
                          recipe.description!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                              ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 信息卡片
                  _buildInfoCards(context, recipe),
                  const SizedBox(height: 24),

                  // 标签
                  if (recipe.tags.isNotEmpty) ...[
                    _buildTags(context, recipe),
                    const SizedBox(height: 24),
                  ],

                  // 食材
                  _buildSection(
                    context,
                    title: '食材清单',
                    icon: Icons.shopping_basket,
                    child: _buildIngredients(context, recipe),
                  ),
                  const SizedBox(height: 24),

                  // 步骤
                  _buildSection(
                    context,
                    title: '制作步骤',
                    icon: Icons.format_list_numbered,
                    child: _buildSteps(context, recipe),
                  ),
                  const SizedBox(height: 24),

                  // 技巧
                  if (recipe.tips != null && recipe.tips!.isNotEmpty) ...[
                    _buildSection(
                      context,
                      title: '烹饪技巧',
                      icon: Icons.lightbulb_outline,
                      child: _buildTips(context, recipe),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 营养信息
                  if (recipe.nutrition != null) ...[
                    _buildSection(
                      context,
                      title: '营养信息',
                      icon: Icons.pie_chart_outline,
                      child: _buildNutrition(context, recipe),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 健康声明
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.orange.withOpacity(0.4) : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDark ? Colors.orange[400] : Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '营养数据仅供参考，不代替医生建议',
                                style: TextStyle(
                                  color: isDark ? Colors.orange[300] : Colors.orange[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, RecipeModel recipe) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.timer_outlined,
            label: '准备时间',
            value: '${recipe.prepTime}分钟',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.local_fire_department_outlined,
            label: '烹饪时间',
            value: '${recipe.cookTime}分钟',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.people_outline,
            label: '份量',
            value: '${recipe.servings}人份',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? AppColors.textPrimaryDark : null,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context, RecipeModel recipe) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recipe.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildIngredients(BuildContext context, RecipeModel recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: recipe.ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          final isLast = index == recipe.ingredients.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.borderDark : Colors.grey[200]!,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        ingredient.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textPrimaryDark : null,
                        ),
                      ),
                      if (ingredient.isOptional)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.inputBackgroundDark : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '可选',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textSecondaryDark : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${ingredient.quantity}${ingredient.unit}',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSteps(BuildContext context, RecipeModel recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: recipe.steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    step,
                    style: TextStyle(
                      height: 1.5,
                      color: isDark ? AppColors.textPrimaryDark : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTips(BuildContext context, RecipeModel recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.amber.withOpacity(0.4) : Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates,
            color: isDark ? Colors.amber[400] : Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recipe.tips!,
              style: TextStyle(
                color: isDark ? Colors.amber[200] : Colors.amber[900],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrition(BuildContext context, RecipeModel recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nutrition = recipe.nutrition!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNutritionItem(
                  context,
                  '热量',
                  '${nutrition.calories?.toInt() ?? '-'}',
                  'kcal',
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
                  context,
                  '蛋白质',
                  '${nutrition.protein?.toInt() ?? '-'}',
                  'g',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
                  context,
                  '碳水',
                  '${nutrition.carbs?.toInt() ?? '-'}',
                  'g',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
                  context,
                  '脂肪',
                  '${nutrition.fat?.toInt() ?? '-'}',
                  'g',
                  Colors.purple,
                ),
              ),
            ],
          ),
          if (nutrition.summary != null) ...[
            const SizedBox(height: 12),
            Text(
              nutrition.summary!,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adjustedColor = isDark ? color.withOpacity(0.8) : color;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: adjustedColor,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: adjustedColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _showCompleteCookingDialog(
    BuildContext context,
    RecipeModel recipe,
  ) async {
    final result = await showDialog<_CompleteCookingResult>(
      context: context,
      builder: (dialogContext) => _CompleteCookingDialog(
        recipe: recipe,
        parentRef: ref,
      ),
    );

    if (result != null && context.mounted) {
      // 在父级 context 中显示 SnackBar
      String message = '已记录「${result.recipeName}」为${_getMealTypeName(result.mealType)}';
      if (result.deductInventory) {
        if (result.deductedCount > 0) {
          message += '，已扣减 ${result.deductedCount} 项食材';
        }
        if (result.notFoundCount > 0) {
          message += '，${result.notFoundCount} 项库存中未找到';
        }
      }

      final scaffoldMessenger = ScaffoldMessenger.of(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          // 设置一个很长的 duration，由手动定时器控制关闭
          // 嵌套 Scaffold 结构下内置定时器可能失效
          duration: const Duration(days: 1),
          action: SnackBarAction(
            label: '查看日历',
            textColor: Colors.white,
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
              context.push(AppRoutes.mealCalendar);
            },
          ),
        ),
      );

      // 手动定时器：4秒后关闭 SnackBar
      // 由于嵌套 Scaffold 结构，内置 duration 定时器不可靠
      Future.delayed(const Duration(seconds: 4), () {
        scaffoldMessenger.hideCurrentSnackBar();
      });
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
        return '甜点';
      default:
        return type;
    }
  }

  /// v1.2: 显示添加到菜单对话框
  void _showAddToMenuDialog(
    BuildContext context,
    RecipeModel recipe,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddToMenuSheet(
        recipe: recipe,
        parentRef: ref,
      ),
    );
  }
}

/// v1.2: 添加到菜单的底部弹窗
class _AddToMenuSheet extends ConsumerStatefulWidget {
  final RecipeModel recipe;
  final WidgetRef parentRef;

  const _AddToMenuSheet({
    required this.recipe,
    required this.parentRef,
  });

  @override
  ConsumerState<_AddToMenuSheet> createState() => _AddToMenuSheetState();
}

class _AddToMenuSheetState extends ConsumerState<_AddToMenuSheet> {
  late DateTime _selectedDate;
  String _selectedMealType = 'lunch';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // 根据当前时间自动选择餐次
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      _selectedMealType = 'breakfast';
    } else if (hour >= 10 && hour < 14) {
      _selectedMealType = 'lunch';
    } else {
      _selectedMealType = 'dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.add_chart,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '添加到菜单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // 菜谱名称
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.recipe.name,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 日期选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '选择日期',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildDateSelector(isDark),
          const SizedBox(height: 16),
          // 餐次选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '选择餐次',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildMealTypeSelector(isDark),
          const SizedBox(height: 24),
          // 确认按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addToMenu,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dates = List.generate(7, (i) => today.add(Duration(days: i)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: dates.map((date) {
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          String label;
          final diff = date.difference(today).inDays;
          if (diff == 0) {
            label = '今天';
          } else if (diff == 1) {
            label = '明天';
          } else if (diff == 2) {
            label = '后天';
          } else {
            label = '${date.month}/${date.day}';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDate = date),
              backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? AppColors.textPrimaryDark : Colors.black87),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealTypeSelector(bool isDark) {
    final mealTypes = [
      ('breakfast', '早餐', '🌅'),
      ('lunch', '午餐', '☀️'),
      ('dinner', '晚餐', '🌙'),
      ('snack', '加餐', '🍪'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: mealTypes.map((meal) {
          final isSelected = _selectedMealType == meal.$1;
          return ChoiceChip(
            label: Text('${meal.$3} ${meal.$2}'),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedMealType = meal.$1),
            backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
            selectedColor: Theme.of(context).primaryColor,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : (isDark ? AppColors.textPrimaryDark : Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _addToMenu() async {
    setState(() => _isLoading = true);

    try {
      final currentFamily = ref.read(currentFamilyProvider);
      if (currentFamily == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先创建家庭')),
          );
        }
        return;
      }

      // 添加到菜单
      final mealPlanRepository = ref.read(mealPlanRepositoryProvider);
      await mealPlanRepository.addRecipeToDate(
        familyId: currentFamily.id,
        date: _selectedDate,
        mealType: _selectedMealType,
        recipe: widget.recipe,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加到${_getMealTypeName(_selectedMealType)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      case 'snack':
        return '加餐';
      default:
        return type;
    }
  }
}

class _CompleteCookingDialog extends ConsumerStatefulWidget {
  final RecipeModel recipe;
  final WidgetRef parentRef;

  const _CompleteCookingDialog({
    required this.recipe,
    required this.parentRef,
  });

  @override
  ConsumerState<_CompleteCookingDialog> createState() => _CompleteCookingDialogState();
}

class _CompleteCookingDialogState extends ConsumerState<_CompleteCookingDialog> {
  bool _isLoading = false;
  String _selectedMealType = 'lunch';
  bool _deductInventory = true;

  @override
  void initState() {
    super.initState();
    // 根据当前时间自动选择餐次
    final hour = DateTime.now().hour;
    if (hour < 10) {
      _selectedMealType = 'breakfast';
    } else if (hour < 14) {
      _selectedMealType = 'lunch';
    } else if (hour < 20) {
      _selectedMealType = 'dinner';
    } else {
      _selectedMealType = 'snacks';
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
        return '甜点';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.restaurant, color: Colors.green),
          SizedBox(width: 8),
          Text('完成烹饪'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 餐次选择
            const Text(
              '这是哪一餐？',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
                return Wrap(
                  spacing: 8,
                  children: ['breakfast', 'lunch', 'dinner', 'snacks'].map((type) {
                    final isSelected = _selectedMealType == type;
                    return ChoiceChip(
                      label: Text(
                        _getMealTypeName(type),
                        style: TextStyle(
                          color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedMealType = type),
                      elevation: 0,
                      pressElevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
                      selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
                      side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // 是否扣减库存
            CheckboxListTile(
              value: _deductInventory,
              onChanged: (v) => setState(() => _deductInventory = v ?? true),
              title: const Text('扣减食材库存'),
              subtitle: const Text('取消勾选则仅记录用餐'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            if (_deductInventory) ...[
              const SizedBox(height: 8),
              Text(
                '将扣减以下食材：',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: recipe.ingredients.length,
                  itemBuilder: (context, index) {
                    final ing = recipe.ingredients[index];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        ing.isOptional ? Icons.remove_circle_outline : Icons.check_circle,
                        color: ing.isOptional ? Colors.grey : Colors.green,
                        size: 18,
                      ),
                      title: Text(
                        ing.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: ing.isOptional ? Colors.grey : null,
                          decoration: ing.isOptional ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      trailing: Text(
                        '${ing.quantity}${ing.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ing.isOptional ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(
                '* 可选食材不会扣减',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _completeCooking,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('已吃'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _completeCooking() async {
    setState(() => _isLoading = true);

    try {
      final currentFamily = ref.read(currentFamilyProvider);
      if (currentFamily == null) {
        throw Exception('未选择家庭');
      }

      int deductedCount = 0;
      int notFoundCount = 0;

      // 如果需要扣减库存
      if (_deductInventory) {
        final inventoryNotifier = ref.read(inventoryProvider.notifier);
        final inventoryState = ref.read(inventoryProvider);

        for (final ing in widget.recipe.ingredients) {
          // 跳过可选食材
          if (ing.isOptional) continue;

          // 在库存中查找食材
          final inventoryItem = inventoryState.ingredients.firstWhere(
            (item) => item.name.toLowerCase() == ing.name.toLowerCase(),
            orElse: () => IngredientModel(
              id: '',
              familyId: '',
              name: '',
              quantity: 0,
              unit: '',
              source: '',
              addedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          if (inventoryItem.id.isNotEmpty) {
            // 扣减库存
            await inventoryNotifier.deductQuantity(inventoryItem.id, ing.quantity);
            deductedCount++;
          } else {
            notFoundCount++;
          }
        }
      }

      // 记录到用餐历史
      await ref.read(historyProvider.notifier).addMealHistory(
        date: DateTime.now(),
        mealType: _selectedMealType,
        recipeId: widget.recipe.id,
        recipeName: widget.recipe.name,
      );

      // 从推荐菜单中移除已吃的菜谱
      // 注意：_selectedMealType 使用 'snacks'，但 MealModel 保存时使用 'snack'
      await ref.read(recommendProvider.notifier).removeEatenRecipe(
        recipeId: widget.recipe.id,
        date: DateTime.now(),
        mealType: _selectedMealType == 'snacks' ? 'snack' : _selectedMealType,
      );

      if (mounted) {
        // 返回结果给父级处理 SnackBar 显示
        Navigator.pop(
          context,
          _CompleteCookingResult(
            recipeName: widget.recipe.name,
            mealType: _selectedMealType,
            deductedCount: deductedCount,
            notFoundCount: notFoundCount,
            deductInventory: _deductInventory,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
