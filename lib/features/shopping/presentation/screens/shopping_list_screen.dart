import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../inventory/data/models/ingredient_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../data/models/shopping_list_model.dart';
import '../../data/repositories/shopping_list_repository.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFamily = ref.watch(currentFamilyProvider);

    if (currentFamily == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('购物'),
        ),
        body: const _EmptyState(
          icon: Icons.family_restroom,
          title: '请先创建家庭',
          subtitle: '创建家庭后即可使用购物功能',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('购物'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '购物清单'),
            Tab(text: '家中库存'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ShoppingListTab(familyId: currentFamily.id),
          _InventoryTab(familyId: currentFamily.id),
        ],
      ),
    );
  }
}

/// 购物清单 Tab
class _ShoppingListTab extends ConsumerWidget {
  final String familyId;

  const _ShoppingListTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoppingLists = ref.watch(familyShoppingListsProvider(familyId));

    if (shoppingLists.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: '暂无购物清单',
        subtitle: '生成菜单后会自动生成购物清单',
      );
    }

    final latestList = shoppingLists.first;

    return Column(
      children: [
        _buildProgressBar(context, ref, latestList),
        Expanded(
          child: _ShoppingListContent(
            shoppingList: latestList,
            onTogglePurchased: (itemId) {
              ref.read(shoppingListRepositoryProvider).toggleItemPurchased(
                    latestList.id,
                    itemId,
                  );
              ref.invalidate(familyShoppingListsProvider(familyId));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    WidgetRef ref,
    ShoppingListModel list,
  ) {
    final progress = list.progress;
    final purchased = list.purchasedCount;
    final total = list.totalItems;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '购物进度',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    '$purchased / $total 项',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 复制按钮
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(context, list),
                    tooltip: '复制清单',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, ShoppingListModel list) {
    final text = list.toTextFormat();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('购物清单已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 家中库存 Tab
class _InventoryTab extends ConsumerWidget {
  final String familyId;

  const _InventoryTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryProvider);
    final ingredients = inventoryState.ingredients;

    if (ingredients.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '家里还没有库存',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加食材',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.addIngredient),
            icon: const Icon(Icons.add),
            label: const Text('添加食材'),
          ),
        ],
      );
    }

    // 按类别分组
    final grouped = <String, List<IngredientModel>>{};
    for (final ing in ingredients) {
      final category = ing.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(ing);
    }

    return Column(
      children: [
        // 头部信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.home,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                '家里还有 ${ingredients.length} 种食材',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.addIngredient),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ),

        // 库存列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final category = grouped.keys.elementAt(index);
              final items = grouped[category]!;

              return _InventoryCategory(
                category: category,
                items: items,
                onDelete: (id) {
                  ref.read(inventoryProvider.notifier).deleteIngredient(id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryCategory extends StatelessWidget {
  final String category;
  final List<IngredientModel> items;
  final Function(String) onDelete;

  const _InventoryCategory({
    required this.category,
    required this.items,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                ),
                child: ListTile(
                  title: Text(item.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.remainingQuantity.toStringAsFixed(item.remainingQuantity.truncateToDouble() == item.remainingQuantity ? 0 : 1)}${item.unit}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                        onPressed: () => _confirmDelete(context, item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, IngredientModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${item.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete(item.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '蔬菜':
        return Icons.grass;
      case '水果':
        return Icons.apple;
      case '肉类':
        return Icons.set_meal;
      case '海鲜':
        return Icons.waves;
      case '蛋奶':
        return Icons.egg;
      case '豆制品':
        return Icons.grain;
      case '主食':
        return Icons.rice_bowl;
      case '调味料':
        return Icons.water_drop;
      case '干货':
        return Icons.inventory_2;
      default:
        return Icons.shopping_basket;
    }
  }
}

class _ShoppingListContent extends StatelessWidget {
  final ShoppingListModel shoppingList;
  final Function(String) onTogglePurchased;

  const _ShoppingListContent({
    required this.shoppingList,
    required this.onTogglePurchased,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = shoppingList.groupedByCategory;
    final categories = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = grouped[category]!;

        return _CategorySection(
          category: category,
          items: items,
          onTogglePurchased: onTogglePurchased,
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<ShoppingItemModel> items;
  final Function(String) onTogglePurchased;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onTogglePurchased,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                ),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () => onTogglePurchased(item.id),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.purchased ? Colors.green : Colors.transparent,
                        border: Border.all(
                          color: item.purchased ? Colors.green : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: item.purchased
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.purchased ? TextDecoration.lineThrough : null,
                      color: item.purchased ? Colors.grey : null,
                    ),
                  ),
                  trailing: Text(
                    item.quantityFormatted,
                    style: TextStyle(
                      color: item.purchased ? Colors.grey : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => onTogglePurchased(item.id),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '蔬菜':
        return Icons.grass;
      case '水果':
        return Icons.apple;
      case '肉类':
        return Icons.set_meal;
      case '海鲜':
        return Icons.waves;
      case '蛋奶':
        return Icons.egg;
      case '豆制品':
        return Icons.grain;
      case '主食':
        return Icons.rice_bowl;
      case '调味料':
        return Icons.water_drop;
      case '干货':
        return Icons.inventory_2;
      default:
        return Icons.shopping_basket;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
