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

  /// 按紧急度分组
  /// 返回 Map: 'urgent' -> 今天需要买, 'soon' -> 3天内需要买, 'later' -> 可以晚点买
  Map<String, List<ShoppingItemModel>> get groupedByUrgency {
    final grouped = <String, List<ShoppingItemModel>>{
      'urgent': [],
      'soon': [],
      'later': [],
    };
    for (final item in items) {
      final level = item.getUrgencyLevel();
      grouped[level]!.add(item);
    }
    // 按需求日期排序
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.needByDate == null && b.needByDate == null) return 0;
        if (a.needByDate == null) return 1;
        if (b.needByDate == null) return -1;
        return a.needByDate!.compareTo(b.needByDate!);
      });
    }
    return grouped;
  }

  /// 获取紧急度标签
  static String getUrgencyLabel(String level) {
    switch (level) {
      case 'urgent':
        return '今天需要买';
      case 'soon':
        return '3天内需要买';
      case 'later':
        return '可以晚点买';
      default:
        return level;
    }
  }

  /// 获取紧急度图标颜色 (返回颜色值 int)
  static int getUrgencyColorValue(String level) {
    switch (level) {
      case 'urgent':
        return 0xFFF44336; // Colors.red
      case 'soon':
        return 0xFFFF9800; // Colors.orange
      case 'later':
        return 0xFF4CAF50; // Colors.green
      default:
        return 0xFF9E9E9E; // Colors.grey
    }
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

  @HiveField(8)
  DateTime? needByDate; // 最晚需要购买日期

  @HiveField(9)
  List<IngredientUsage>? usages; // 用量明细列表

  ShoppingItemModel({
    required this.id,
    this.category,
    required this.name,
    required this.quantity,
    required this.unit,
    this.notes,
    this.purchased = false,
    this.source,
    this.needByDate,
    this.usages,
  });

  factory ShoppingItemModel.create({
    String? category,
    required String name,
    required double quantity,
    required String unit,
    String? notes,
    String? source,
    DateTime? needByDate,
    List<IngredientUsage>? usages,
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
      needByDate: needByDate,
      usages: usages,
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
    DateTime? needByDate,
    List<IngredientUsage>? usages,
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
      needByDate: needByDate ?? this.needByDate,
      usages: usages ?? this.usages,
    );
  }

  /// 添加用量记录
  void addUsage(IngredientUsage usage) {
    usages ??= [];
    usages!.add(usage);
  }

  /// 获取紧急度分类
  /// 返回: 'urgent' (今天), 'soon' (3天内), 'later' (可以晚点买)
  String getUrgencyLevel() {
    if (needByDate == null) return 'later';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final needDate = DateTime(needByDate!.year, needByDate!.month, needByDate!.day);
    final daysUntilNeeded = needDate.difference(today).inDays;

    if (daysUntilNeeded <= 0) return 'urgent';
    if (daysUntilNeeded <= 3) return 'soon';
    return 'later';
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

/// 食材用量明细 - 记录每个食材的使用来源
@HiveType(typeId: 42)
class IngredientUsage {
  @HiveField(0)
  String recipeName; // 菜名，如 "糖醋排骨"

  @HiveField(1)
  double quantity; // 用量，如 500

  @HiveField(2)
  String unit; // 单位，如 "g"

  @HiveField(3)
  DateTime useDate; // 使用日期

  @HiveField(4)
  String mealType; // 餐次，如 "午餐"

  IngredientUsage({
    required this.recipeName,
    required this.quantity,
    required this.unit,
    required this.useDate,
    required this.mealType,
  });

  /// 格式化数量显示
  String get quantityFormatted {
    final qty = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$qty$unit';
  }

  /// 格式化日期显示
  String get useDateFormatted {
    return '${useDate.month}/${useDate.day}';
  }

  /// 获取餐次标签
  String get mealTypeLabel {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      default:
        return mealType;
    }
  }

  /// 完整描述，如 "糖醋排骨: 500g (1/29 午餐)"
  String get fullDescription {
    return '$recipeName: $quantityFormatted ($useDateFormatted $mealTypeLabel)';
  }
}
