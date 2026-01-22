import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../family/data/repositories/family_repository.dart';
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
        icon: const Icon(Icons.check),
        label: const Text('完成烹饪'),
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
                onPressed: () {
                  ref.read(recipeRepositoryProvider).toggleFavorite(recipeId);
                  ref.invalidate(recipeByIdProvider(recipeId));
                  ref.invalidate(allRecipesProvider);
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
                    Text(
                      recipe.description!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '营养数据仅供参考，不代替医生建议',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
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
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        ingredient.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (ingredient.isOptional)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '可选',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${ingredient.quantity}${ingredient.unit}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSteps(BuildContext context, RecipeModel recipe) {
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
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(height: 1.5),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recipe.tips!,
              style: TextStyle(
                color: Colors.amber[900],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrition(BuildContext context, RecipeModel recipe) {
    final nutrition = recipe.nutrition!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNutritionItem(
                  '热量',
                  '${nutrition.calories?.toInt() ?? '-'}',
                  'kcal',
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
                  '蛋白质',
                  '${nutrition.protein?.toInt() ?? '-'}',
                  'g',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
                  '碳水',
                  '${nutrition.carbs?.toInt() ?? '-'}',
                  'g',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildNutritionItem(
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
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionItem(
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
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
            Text(
              '完成制作「${recipe.name}」后，将从库存扣减以下食材：',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: recipe.ingredients.length,
                itemBuilder: (context, index) {
                  final ing = recipe.ingredients[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      ing.isOptional ? Icons.remove_circle_outline : Icons.check_circle,
                      color: ing.isOptional ? Colors.grey : Colors.green,
                      size: 20,
                    ),
                    title: Text(
                      ing.name,
                      style: TextStyle(
                        color: ing.isOptional ? Colors.grey : null,
                        decoration: ing.isOptional ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Text(
                      '${ing.quantity}${ing.unit}',
                      style: TextStyle(
                        color: ing.isOptional ? Colors.grey : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '* 可选食材不会扣减',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _completeCooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('确认扣减'),
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

      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      final inventoryState = ref.read(inventoryProvider);

      int deductedCount = 0;
      int notFoundCount = 0;

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

      if (mounted) {
        Navigator.pop(context);

        String message = '烹饪完成！';
        if (deductedCount > 0) {
          message += '已扣减 $deductedCount 项食材';
        }
        if (notFoundCount > 0) {
          message += '，$notFoundCount 项食材库存中未找到';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
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
