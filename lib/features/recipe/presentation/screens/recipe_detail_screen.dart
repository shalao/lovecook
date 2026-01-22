import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../data/models/recipe_model.dart';
import '../../data/repositories/recipe_repository.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeByIdProvider(recipeId));

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
        onPressed: () => _showCompleteCookingDialog(context, ref, recipe),
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
                icon: Icon(
                  recipe.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  color: recipe.isFavorite ? Colors.amber : null,
                ),
                onPressed: () async {
                  final currentFamily = ref.read(currentFamilyProvider);
                  // 等待收藏操作完成后再刷新
                  await ref.read(recipeRepositoryProvider).toggleFavorite(recipeId);
                  ref.invalidate(recipeByIdProvider(recipeId));
                  ref.invalidate(allRecipesProvider);
                  // 刷新收藏列表，确保收藏状态同步
                  ref.invalidate(favoriteRecipesProvider(currentFamily?.id));
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

  void _showCompleteCookingDialog(
    BuildContext context,
    WidgetRef ref,
    RecipeModel recipe,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _CompleteCookingDialog(
        recipe: recipe,
        parentRef: ref,
      ),
    );
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

      if (mounted) {
        // 在关闭对话框前获取引用，避免 context 失效
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final router = GoRouter.of(context);

        Navigator.pop(context);

        String message = '已记录「${widget.recipe.name}」为${_getMealTypeName(_selectedMealType)}';
        if (_deductInventory) {
          if (deductedCount > 0) {
            message += '，已扣减 $deductedCount 项食材';
          }
          if (notFoundCount > 0) {
            message += '，$notFoundCount 项库存中未找到';
          }
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '查看日历',
              textColor: Colors.white,
              onPressed: () {
                scaffoldMessenger.hideCurrentSnackBar();
                router.push(AppRoutes.mealCalendar);
              },
            ),
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
