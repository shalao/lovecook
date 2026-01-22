import 'package:hive/hive.dart';

part 'shopping_list_model.g.dart';

@HiveType(typeId: 40)
class ShoppingListModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String familyId;

  @HiveField(2)
  String? mealPlanId; // 关联的菜单计划

  @HiveField(3)
  List<ShoppingItemModel> items;

  @HiveField(4)
  DateTime generatedAt;

  @HiveField(5)
  String? notes;

  ShoppingListModel({
    required this.id,
    required this.familyId,
    this.mealPlanId,
    required this.items,
    required this.generatedAt,
    this.notes,
  });

  factory ShoppingListModel.create({
    required String familyId,
    String? mealPlanId,
    List<ShoppingItemModel>? items,
  }) {
    return ShoppingListModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      familyId: familyId,
      mealPlanId: mealPlanId,
      items: items ?? [],
      generatedAt: DateTime.now(),
    );
  }

  /// 总项目数
  int get totalItems => items.length;

  /// 已购项目数
  int get purchasedCount => items.where((item) => item.purchased).length;

  /// 完成进度 (0.0 - 1.0)
  double get progress => totalItems > 0 ? purchasedCount / totalItems : 0;

  /// 按类别分组
  Map<String, List<ShoppingItemModel>> get groupedByCategory {
    final grouped = <String, List<ShoppingItemModel>>{};
    for (final item in items) {
      final category = item.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(item);
    }
    return grouped;
  }

  /// 添加项目
  void addItem(ShoppingItemModel item) {
    // 检查是否已存在同名同单位的项目
    final existing = items.indexWhere(
      (i) => i.name == item.name && i.unit == item.unit,
    );
    if (existing >= 0) {
      items[existing].quantity += item.quantity;
    } else {
      items.add(item);
    }
  }

  /// 移除项目
  void removeItem(String itemId) {
    items.removeWhere((item) => item.id == itemId);
  }

  /// 生成文本版购物清单
  String toTextFormat() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 家庭购物清单');
    buffer.writeln('生成时间: ${_formatDate(generatedAt)}');
    buffer.writeln('');

    final grouped = groupedByCategory;
    for (final category in grouped.keys) {
      buffer.writeln('【$category】');
      for (final item in grouped[category]!) {
        final status = item.purchased ? '✅' : '⬜';
        buffer.writeln('$status ${item.name} ${item.quantityFormatted}${item.notes != null ? " (${item.notes})" : ""}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

@HiveType(typeId: 41)
class ShoppingItemModel {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? category;

  @HiveField(2)
  String name;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  String unit;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  bool purchased;

  @HiveField(7)
  String? source; // menu/restock/manual

  ShoppingItemModel({
    required this.id,
    this.category,
    required this.name,
    required this.quantity,
    required this.unit,
    this.notes,
    this.purchased = false,
    this.source,
  });

  factory ShoppingItemModel.create({
    String? category,
    required String name,
    required double quantity,
    required String unit,
    String? notes,
    String? source,
  }) {
    return ShoppingItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      name: name,
      quantity: quantity,
      unit: unit,
      notes: notes,
      purchased: false,
      source: source ?? 'manual',
    );
  }

  /// 格式化数量显示
  String get quantityFormatted {
    final qty = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$qty$unit';
  }

  /// 切换购买状态
  void togglePurchased() {
    purchased = !purchased;
  }

  /// 复制项目
  ShoppingItemModel copyWith({
    String? id,
    String? category,
    String? name,
    double? quantity,
    String? unit,
    String? notes,
    bool? purchased,
    String? source,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      purchased: purchased ?? this.purchased,
      source: source ?? this.source,
    );
  }
}

/// 购物清单项目来源
class ShoppingItemSource {
  static const String menu = 'menu'; // 来自菜单计划
  static const String restock = 'restock'; // 补货提醒
  static const String manual = 'manual'; // 手动添加

  static String getLabel(String source) {
    switch (source) {
      case menu:
        return '菜单';
      case restock:
        return '补货';
      case manual:
        return '手动';
      default:
        return source;
    }
  }
}
