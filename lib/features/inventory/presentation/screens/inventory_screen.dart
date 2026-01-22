import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/ingredient_model.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('食材库存'),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge_type),
            tooltip: '合并重复',
            onPressed: () => _showMergeDialog(context, notifier),
          ),
          IconButton(
            icon: const Icon(Icons.family_restroom),
            onPressed: () => context.push(AppRoutes.family),
            tooltip: '家庭管理',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(state, notifier),
          // 类别筛选
          if (state.allCategories.isNotEmpty)
            _buildCategoryFilter(state, notifier),
          // 提醒卡片
          if (state.expiringIngredients.isNotEmpty ||
              state.lowStockIngredients.isNotEmpty)
            _buildAlertCards(state),
          // 库存列表
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.ingredients.isEmpty
                    ? _buildEmptyState()
                    : _buildIngredientsList(state, notifier),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addIngredient),
        icon: const Icon(Icons.add),
        label: const Text('添加食材'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchBar(InventoryState state, InventoryNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索食材...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setSearchQuery(null);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: notifier.setSearchQuery,
      ),
    );
  }

  Widget _buildCategoryFilter(InventoryState state, InventoryNotifier notifier) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: state.selectedCategory == null,
            onSelected: () => notifier.setSelectedCategory(null),
          ),
          const SizedBox(width: 8),
          ...state.allCategories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: category,
                  isSelected: state.selectedCategory == category,
                  onSelected: () => notifier.setSelectedCategory(category),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildAlertCards(InventoryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (state.expiringIngredients.isNotEmpty)
            Expanded(
              child: _AlertCard(
                icon: Icons.warning_amber,
                color: Colors.orange,
                title: '临期食材',
                count: state.expiringIngredients.length,
                onTap: () => _showExpiringDialog(context, state.expiringIngredients),
              ),
            ),
          if (state.expiringIngredients.isNotEmpty &&
              state.lowStockIngredients.isNotEmpty)
            const SizedBox(width: 12),
          if (state.lowStockIngredients.isNotEmpty)
            Expanded(
              child: _AlertCard(
                icon: Icons.inventory_2_outlined,
                color: Colors.red,
                title: '库存不足',
                count: state.lowStockIngredients.length,
                onTap: () => _showLowStockDialog(context, state.lowStockIngredients),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有添加食材',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加食材',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(InventoryState state, InventoryNotifier notifier) {
    final grouped = state.groupedByCategory;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final category = grouped.keys.elementAt(index);
        final ingredients = grouped[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...ingredients.map((ing) => _IngredientTile(
                  ingredient: ing,
                  onTap: () => _showIngredientDetail(context, ing, notifier),
                  onDelete: () => _confirmDelete(context, ing, notifier),
                )),
          ],
        );
      },
    );
  }

  void _showMergeDialog(BuildContext context, InventoryNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并重复食材'),
        content: const Text('将相同名称和单位的食材数量合并。此操作不可撤销，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.mergeIngredients();
            },
            child: const Text('合并'),
          ),
        ],
      ),
    );
  }

  void _showExpiringDialog(BuildContext context, List<IngredientModel> ingredients) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _IngredientListSheet(
        title: '临期食材',
        ingredients: ingredients,
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, List<IngredientModel> ingredients) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _IngredientListSheet(
        title: '库存不足',
        ingredients: ingredients,
      ),
    );
  }

  void _showIngredientDetail(
    BuildContext context,
    IngredientModel ingredient,
    InventoryNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IngredientDetailSheet(
        ingredient: ingredient,
        onQuantityChanged: (quantity) {
          notifier.updateQuantity(ingredient.id, quantity);
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    IngredientModel ingredient,
    InventoryNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除食材'),
        content: Text('确定要删除"${ingredient.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              notifier.deleteIngredient(ingredient.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 提醒卡片
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _AlertCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$count 项',
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: color.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 食材列表项
class _IngredientTile extends StatelessWidget {
  final IngredientModel ingredient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _IngredientTile({
    required this.ingredient,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpiring = ingredient.isExpiring;
    final isExpired = ingredient.isExpired;

    return Dismissible(
      key: Key(ingredient.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpired
              ? Colors.red.shade100
              : isExpiring
                  ? Colors.orange.shade100
                  : AppColors.primary.withOpacity(0.1),
          child: Text(
            ingredient.name.substring(0, 1),
            style: TextStyle(
              color: isExpired
                  ? Colors.red
                  : isExpiring
                      ? Colors.orange
                      : AppColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(ingredient.name),
            if (isExpired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已过期',
                  style: TextStyle(fontSize: 10, color: Colors.red),
                ),
              )
            else if (isExpiring)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '临期',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${ingredient.quantityFormatted}${ingredient.expiryDate != null ? " · ${ingredient.expiryFormatted}" : ""}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// 食材列表底部弹窗
class _IngredientListSheet extends StatelessWidget {
  final String title;
  final List<IngredientModel> ingredients;

  const _IngredientListSheet({
    required this.title,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...ingredients.map((ing) => ListTile(
                leading: CircleAvatar(
                  child: Text(ing.name.substring(0, 1)),
                ),
                title: Text(ing.name),
                subtitle: Text(ing.quantityFormatted),
              )),
        ],
      ),
    );
  }
}

/// 食材详情底部弹窗
class _IngredientDetailSheet extends StatefulWidget {
  final IngredientModel ingredient;
  final ValueChanged<double> onQuantityChanged;

  const _IngredientDetailSheet({
    required this.ingredient,
    required this.onQuantityChanged,
  });

  @override
  State<_IngredientDetailSheet> createState() => _IngredientDetailSheetState();
}

class _IngredientDetailSheetState extends State<_IngredientDetailSheet> {
  late double _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.ingredient.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  widget.ingredient.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ingredient.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.ingredient.category != null)
                      Text(
                        widget.ingredient.category!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 数量调整
          Row(
            children: [
              const Text('数量', style: TextStyle(fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _quantity > 0
                    ? () => setState(() => _quantity = (_quantity - 1).clamp(0, double.infinity))
                    : null,
              ),
              SizedBox(
                width: 60,
                child: Text(
                  _quantity == _quantity.toInt()
                      ? _quantity.toInt().toString()
                      : _quantity.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _quantity += 1),
              ),
              Text(widget.ingredient.unit),
            ],
          ),
          const SizedBox(height: 16),
          // 详细信息
          if (widget.ingredient.expiryDate != null)
            _DetailRow(
              label: '保质期至',
              value: widget.ingredient.expiryFormatted,
            ),
          if (widget.ingredient.storageAdvice != null)
            _DetailRow(
              label: '存储建议',
              value: widget.ingredient.storageAdvice!,
            ),
          _DetailRow(
            label: '添加时间',
            value: _formatDate(widget.ingredient.addedAt),
          ),
          const SizedBox(height: 24),
          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onQuantityChanged(_quantity);
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 详情行
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }
}
