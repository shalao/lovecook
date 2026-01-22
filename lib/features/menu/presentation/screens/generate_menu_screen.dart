import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../providers/menu_provider.dart';

class GenerateMenuScreen extends ConsumerWidget {
  const GenerateMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuGenerateProvider);
    final currentFamily = ref.watch(currentFamilyProvider);
    final aiConfig = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生成菜单'),
      ),
      body: state.isGenerating
          ? _buildGeneratingView(context)
          : state.result != null
              ? _buildResultView(context, ref, state)
              : _buildSettingsView(context, ref, state, currentFamily, aiConfig),
    );
  }

  Widget _buildGeneratingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            '正在生成菜单...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'AI 正在根据您的家庭情况和库存食材\n精心规划营养均衡的菜单',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView(
    BuildContext context,
    WidgetRef ref,
    MenuGenerateState state,
    dynamic currentFamily,
    AIConfig aiConfig,
  ) {
    final notifier = ref.read(menuGenerateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提示信息
          if (currentFamily == null)
            _buildWarningCard(
              context,
              icon: Icons.family_restroom,
              title: '请先创建家庭',
              message: '需要设置家庭成员信息才能生成个性化菜单',
              action: '去创建',
              onAction: () => context.go('/family'),
            ),
          if (currentFamily != null && !aiConfig.isConfigured)
            _buildWarningCard(
              context,
              icon: Icons.key,
              title: 'API 密钥未配置',
              message: '请在设置中配置 OpenAI API 密钥',
              action: '去设置',
              onAction: () => context.go('/settings'),
            ),
          if (state.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),

          // 天数选择
          Text(
            '选择天数',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [1, 3, 5, 7].map((days) {
              final isSelected = state.settings.days == days;
              return ChoiceChip(
                label: Text('$days 天'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) notifier.setDays(days);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : null,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // 每餐菜品数量
          Text(
            '每餐菜品数量',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [1, 2, 3].map((count) {
              final isSelected = state.settings.dishesPerMeal == count;
              return ChoiceChip(
                label: Text('$count 道菜'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) notifier.setDishesPerMeal(count);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : null,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // 餐次选择
          Text(
            '选择餐次',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          _MealToggle(
            label: '早餐',
            subtitle: '一日之计在于晨',
            icon: Icons.wb_sunny_outlined,
            value: state.settings.breakfast,
            onChanged: notifier.setBreakfast,
          ),
          _MealToggle(
            label: '午餐',
            subtitle: '补充能量',
            icon: Icons.wb_twilight,
            value: state.settings.lunch,
            onChanged: notifier.setLunch,
          ),
          _MealToggle(
            label: '晚餐',
            subtitle: '享受美食时光',
            icon: Icons.nights_stay_outlined,
            value: state.settings.dinner,
            onChanged: notifier.setDinner,
          ),
          _MealToggle(
            label: '加餐/点心',
            subtitle: '适量补充',
            icon: Icons.cookie_outlined,
            value: state.settings.snacks,
            onChanged: notifier.setSnacks,
          ),

          const SizedBox(height: 32),

          // 生成按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: currentFamily != null && aiConfig.isConfigured
                  ? () => notifier.generateMenu()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '开始生成',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              '菜单将根据家庭成员健康需求和库存食材智能生成',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String action,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(
    BuildContext context,
    WidgetRef ref,
    MenuGenerateState state,
  ) {
    final result = state.result!;
    final notifier = ref.read(menuGenerateProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: result.days.length + 1, // +1 for shopping list
            itemBuilder: (context, index) {
              if (index < result.days.length) {
                final day = result.days[index];
                return _buildDayCard(context, day);
              } else {
                // Shopping list
                return _buildShoppingListCard(context, result);
              }
            },
          ),
        ),
        // Bottom actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.clearResult(),
                  child: const Text('重新生成'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await notifier.saveMenuPlan();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('菜单已保存'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      context.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存菜单'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, DayPlanData day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    day.date,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...day.meals.map((meal) => _buildMealSection(context, meal)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(BuildContext context, MealData meal) {
    final mealIcon = _getMealIcon(meal.type);
    final mealLabel = _getMealLabel(meal.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mealIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                mealLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...meal.recipes.map((recipe) => _buildRecipeItem(context, recipe)),
        ],
      ),
    );
  }

  Widget _buildRecipeItem(BuildContext context, Map<String, dynamic> recipe) {
    final name = recipe['name'] as String? ?? '';
    final description = recipe['description'] as String? ?? '';
    final prepTime = recipe['prepTime'] as int? ?? 0;
    final cookTime = recipe['cookTime'] as int? ?? 0;
    final ingredients = recipe['ingredients'] as List? ?? [];
    final steps = recipe['steps'] as List? ?? [];
    final tips = recipe['tips'] as String? ?? '';
    final tags = recipe['tags'] as List? ?? [];

    return _ExpandableRecipeCard(
      name: name,
      description: description,
      prepTime: prepTime,
      cookTime: cookTime,
      ingredients: ingredients,
      steps: steps,
      tips: tips,
      tags: tags,
    );
  }

  Widget _buildShoppingListCard(BuildContext context, MenuPlanResult result) {
    if (result.shoppingList.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '购物清单',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...result.shoppingList.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.name),
                      ),
                      Text(
                        '${item.quantity}${item.unit}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )),
            if (result.nutritionSummary != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.nutritionSummary!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
      case '早餐':
        return '🌅';
      case 'lunch':
      case '午餐':
        return '☀️';
      case 'dinner':
      case '晚餐':
        return '🌙';
      case 'snack':
      case '加餐':
        return '🍪';
      default:
        return '🍽️';
    }
  }

  String _getMealLabel(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
      case '早餐':
        return '早餐';
      case 'lunch':
      case '午餐':
        return '午餐';
      case 'dinner':
      case '晚餐':
        return '晚餐';
      case 'snack':
      case '加餐':
        return '加餐';
      default:
        return type;
    }
  }
}

class _MealToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MealToggle({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withValues(alpha: 0.05) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: value ? AppColors.primary : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// 可展开的菜谱卡片
class _ExpandableRecipeCard extends StatefulWidget {
  final String name;
  final String description;
  final int prepTime;
  final int cookTime;
  final List ingredients;
  final List steps;
  final String tips;
  final List tags;

  const _ExpandableRecipeCard({
    required this.name,
    required this.description,
    required this.prepTime,
    required this.cookTime,
    required this.ingredients,
    required this.steps,
    required this.tips,
    required this.tags,
  });

  @override
  State<_ExpandableRecipeCard> createState() => _ExpandableRecipeCardState();
}

class _ExpandableRecipeCardState extends State<_ExpandableRecipeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: _isExpanded
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行（可点击展开）
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (widget.prepTime > 0 || widget.cookTime > 0) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.prepTime + widget.cookTime}分钟',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.ingredients.isNotEmpty || widget.steps.isNotEmpty)
                        Text(
                          _isExpanded ? '收起详情' : '查看详情',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 展开的详情内容
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签
                  if (widget.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 食材列表
                  if (widget.ingredients.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '食材',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.ingredients.map((ing) {
                        final name = ing['name'] ?? '';
                        final quantity = ing['quantity'] ?? '';
                        final unit = ing['unit'] ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$name $quantity$unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 制作步骤
                  if (widget.steps.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '制作步骤',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.steps.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  // 烹饪技巧
                  if (widget.tips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '小贴士',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.tips,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
