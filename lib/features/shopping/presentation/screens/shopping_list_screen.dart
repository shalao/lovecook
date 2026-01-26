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
        // 底部入库按钮
        if (latestList.purchasedCount > 0)
          _buildAddToInventoryBar(context, ref, latestList),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 13),
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
                  color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    '$purchased / $total 项',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : null,
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
              backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey[200],
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

  /// 底部入库按钮栏
  Widget _buildAddToInventoryBar(
    BuildContext context,
    WidgetRef ref,
    ShoppingListModel list,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purchasedItems = list.items.where((item) => item.purchased).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 13),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${purchasedItems.length} 项已购食材可入库',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddToInventoryDialog(context, ref, purchasedItems, list),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_home, size: 18),
            label: const Text('入库'),
          ),
        ],
      ),
    );
  }

  /// 显示入库确认对话框（支持多选）
  void _showAddToInventoryDialog(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItemModel> purchasedItems,
    ShoppingListModel shoppingList,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddToInventoryDialog(
        purchasedItems: purchasedItems,
        shoppingList: shoppingList,
        onConfirm: (selectedItems) async {
          Navigator.pop(dialogContext);
          await _addToInventory(context, ref, selectedItems, shoppingList);
        },
      ),
    );
  }

  /// 将购物项添加到库存，并从购物清单移除
  Future<void> _addToInventory(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItemModel> items,
    ShoppingListModel shoppingList,
  ) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在添加到库存...'),
          ],
        ),
      ),
    );

    try {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      final shoppingRepo = ref.read(shoppingListRepositoryProvider);
      int successCount = 0;

      for (final item in items) {
        // 转换购物项为食材模型
        final ingredient = IngredientModel.create(
          familyId: familyId,
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          source: 'shopping',
          // 根据类别推荐保质期
          expiryDate: _getDefaultExpiryDate(item.category ?? '其他'),
        );

        await inventoryNotifier.addIngredient(ingredient);

        // 从购物清单移除已入库的项目
        await shoppingRepo.removeItem(shoppingList.id, item.id);
        successCount++;
      }

      // 刷新购物清单
      ref.invalidate(familyShoppingListsProvider(familyId));

      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功将 $successCount 项食材添加到库存'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 根据类别获取默认保质期
  DateTime? _getDefaultExpiryDate(String category) {
    final now = DateTime.now();
    switch (category) {
      case '蔬菜':
        return now.add(const Duration(days: 5));
      case '水果':
        return now.add(const Duration(days: 7));
      case '肉类':
      case '海鲜':
        return now.add(const Duration(days: 3));
      case '蛋奶':
        return now.add(const Duration(days: 14));
      case '豆制品':
        return now.add(const Duration(days: 5));
      case '主食':
        return now.add(const Duration(days: 30));
      case '调味料':
        return now.add(const Duration(days: 180));
      case '干货':
        return now.add(const Duration(days: 90));
      default:
        return now.add(const Duration(days: 7));
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (ingredients.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '家里还没有库存',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加食材',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                          bottom: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
                        ),
                ),
                child: ListTile(
                  title: Text(
                    item.name,
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : null,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.remainingQuantity.toStringAsFixed(item.remainingQuantity.truncateToDouble() == item.remainingQuantity ? 0 : 1)}${item.unit}',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
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

/// 购物清单分组模式
enum ShoppingListGroupMode {
  urgency, // 按紧急度分组
  category, // 按类别分组
}

class _ShoppingListContent extends StatefulWidget {
  final ShoppingListModel shoppingList;
  final Function(String) onTogglePurchased;

  const _ShoppingListContent({
    required this.shoppingList,
    required this.onTogglePurchased,
  });

  @override
  State<_ShoppingListContent> createState() => _ShoppingListContentState();
}

class _ShoppingListContentState extends State<_ShoppingListContent> {
  ShoppingListGroupMode _groupMode = ShoppingListGroupMode.urgency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 检查是否有紧急度信息
    final hasUrgencyInfo = widget.shoppingList.items.any((item) => item.needByDate != null);

    return Column(
      children: [
        // 分组模式切换（仅当有紧急度信息时显示）
        if (hasUrgencyInfo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '分组方式：',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<ShoppingListGroupMode>(
                  segments: const [
                    ButtonSegment(
                      value: ShoppingListGroupMode.urgency,
                      label: Text('按紧急度'),
                      icon: Icon(Icons.schedule, size: 16),
                    ),
                    ButtonSegment(
                      value: ShoppingListGroupMode.category,
                      label: Text('按类别'),
                      icon: Icon(Icons.category, size: 16),
                    ),
                  ],
                  selected: {_groupMode},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _groupMode = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

        // 列表内容
        Expanded(
          child: _groupMode == ShoppingListGroupMode.urgency && hasUrgencyInfo
              ? _buildUrgencyView()
              : _buildCategoryView(),
        ),
      ],
    );
  }

  /// 按紧急度分组视图
  Widget _buildUrgencyView() {
    final grouped = widget.shoppingList.groupedByUrgency;
    final urgencyOrder = ['urgent', 'soon', 'later'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: urgencyOrder.length,
      itemBuilder: (context, index) {
        final level = urgencyOrder[index];
        final items = grouped[level] ?? [];

        if (items.isEmpty) return const SizedBox.shrink();

        return _UrgencySection(
          urgencyLevel: level,
          items: items,
          onTogglePurchased: widget.onTogglePurchased,
        );
      },
    );
  }

  /// 按类别分组视图
  Widget _buildCategoryView() {
    final grouped = widget.shoppingList.groupedByCategory;
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
          onTogglePurchased: widget.onTogglePurchased,
        );
      },
    );
  }
}

/// 按紧急度分组的区块
class _UrgencySection extends StatelessWidget {
  final String urgencyLevel;
  final List<ShoppingItemModel> items;
  final Function(String) onTogglePurchased;

  const _UrgencySection({
    required this.urgencyLevel,
    required this.items,
    required this.onTogglePurchased,
  });

  @override
  Widget build(BuildContext context) {
    final colorValue = ShoppingListModel.getUrgencyColorValue(urgencyLevel);
    final color = Color(colorValue);
    final label = ShoppingListModel.getUrgencyLabel(urgencyLevel);

    // 紧急度图标
    IconData icon;
    switch (urgencyLevel) {
      case 'urgent':
        icon = Icons.warning_amber;
        break;
      case 'soon':
        icon = Icons.schedule;
        break;
      default:
        icon = Icons.check_circle_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}项',
                  style: TextStyle(fontSize: 12, color: color),
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

              return _ShoppingItemTile(
                item: item,
                isLast: isLast,
                onTogglePurchased: onTogglePurchased,
                showUsageDetails: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 购物项 Tile（支持展开用量明细）
class _ShoppingItemTile extends StatefulWidget {
  final ShoppingItemModel item;
  final bool isLast;
  final Function(String) onTogglePurchased;
  final bool showUsageDetails;

  const _ShoppingItemTile({
    required this.item,
    required this.isLast,
    required this.onTogglePurchased,
    this.showUsageDetails = false,
  });

  @override
  State<_ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<_ShoppingItemTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final hasUsages = widget.showUsageDetails && item.usages != null && item.usages!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: widget.isLast
            ? null
            : Border(
                bottom: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
              ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: GestureDetector(
              onTap: () => widget.onTogglePurchased(item.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.purchased ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: item.purchased ? Colors.green : (isDark ? AppColors.textTertiaryDark : Colors.grey[400]!),
                    width: 2,
                  ),
                ),
                child: item.purchased
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.purchased ? TextDecoration.lineThrough : null,
                      color: item.purchased
                          ? (isDark ? AppColors.textTertiaryDark : Colors.grey)
                          : (isDark ? AppColors.textPrimaryDark : null),
                    ),
                  ),
                ),
                // 显示需求日期（如果有）
                if (item.needByDate != null && !item.purchased)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Color(ShoppingListModel.getUrgencyColorValue(item.getUrgencyLevel())).withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.needByDate!.month}/${item.needByDate!.day}前',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(ShoppingListModel.getUrgencyColorValue(item.getUrgencyLevel())),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.quantityFormatted,
                  style: TextStyle(
                    color: item.purchased
                        ? (isDark ? AppColors.textTertiaryDark : Colors.grey)
                        : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 展开/收起按钮（仅当有用量明细时显示）
                if (hasUsages)
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            onTap: () => widget.onTogglePurchased(item.id),
          ),

          // 用量明细（展开状态）
          if (hasUsages && _isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用量明细：',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...item.usages!.map((usage) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 14,
                              color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                usage.fullDescription,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textTertiaryDark : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
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

              return _ShoppingItemTile(
                item: item,
                isLast: isLast,
                onTogglePurchased: onTogglePurchased,
                showUsageDetails: true,
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

/// 入库选择对话框（支持多选）
class _AddToInventoryDialog extends StatefulWidget {
  final List<ShoppingItemModel> purchasedItems;
  final ShoppingListModel shoppingList;
  final Function(List<ShoppingItemModel>) onConfirm;

  const _AddToInventoryDialog({
    required this.purchasedItems,
    required this.shoppingList,
    required this.onConfirm,
  });

  @override
  State<_AddToInventoryDialog> createState() => _AddToInventoryDialogState();
}

class _AddToInventoryDialogState extends State<_AddToInventoryDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // 默认全选
    _selectedIds = widget.purchasedItems.map((item) => item.id).toSet();
  }

  void _toggleItem(String itemId) {
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
      } else {
        _selectedIds.add(itemId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = widget.purchasedItems.map((item) => item.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = _selectedIds.length;
    final totalCount = widget.purchasedItems.length;
    final isAllSelected = selectedCount == totalCount;

    return AlertDialog(
      title: Row(
        children: [
          const Text('添加到家中库存'),
          const Spacer(),
          TextButton(
            onPressed: isAllSelected ? _deselectAll : _selectAll,
            child: Text(isAllSelected ? '取消全选' : '全选'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已选择 $selectedCount / $totalCount 项',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.purchasedItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.purchasedItems[index];
                  final isSelected = _selectedIds.contains(item.id);

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleItem(item.id),
                      activeColor: AppColors.primary,
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? AppColors.textPrimaryDark : null)
                            : (isDark ? AppColors.textTertiaryDark : Colors.grey),
                      ),
                    ),
                    trailing: Text(
                      item.quantityFormatted,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => _toggleItem(item.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: selectedCount > 0
              ? () {
                  final selectedItems = widget.purchasedItems
                      .where((item) => _selectedIds.contains(item.id))
                      .toList();
                  widget.onConfirm(selectedItems);
                }
              : null,
          child: Text('入库 ($selectedCount)'),
        ),
      ],
    );
  }
}
