import 'package:hive/hive.dart';

part 'ingredient_model.g.dart';

@HiveType(typeId: 10)
class IngredientModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String familyId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String? category; // 蔬菜/肉类/蛋奶/调味料等

  @HiveField(4)
  double quantity;

  @HiveField(5)
  String unit;

  @HiveField(6)
  String? freshness; // fresh/normal/expiring/expired

  @HiveField(7)
  DateTime? expiryDate;

  @HiveField(8)
  String? storageAdvice;

  @HiveField(9)
  String source; // photo/voice/manual

  @HiveField(10)
  DateTime addedAt;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  double? usedQuantity;

  IngredientModel({
    required this.id,
    required this.familyId,
    required this.name,
    this.category,
    required this.quantity,
    required this.unit,
    this.freshness,
    this.expiryDate,
    this.storageAdvice,
    required this.source,
    required this.addedAt,
    required this.updatedAt,
    this.usedQuantity,
  });

  factory IngredientModel.create({
    required String familyId,
    required String name,
    String? category,
    required double quantity,
    required String unit,
    String? freshness,
    DateTime? expiryDate,
    String? storageAdvice,
    required String source,
  }) {
    final now = DateTime.now();
    return IngredientModel(
      id: now.millisecondsSinceEpoch.toString(),
      familyId: familyId,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      freshness: freshness ?? 'fresh',
      expiryDate: expiryDate,
      storageAdvice: storageAdvice,
      source: source,
      addedAt: now,
      updatedAt: now,
      usedQuantity: 0,
    );
  }

  /// 剩余数量
  double get remainingQuantity => quantity - (usedQuantity ?? 0);

  /// 是否已用完
  bool get isEmpty => remainingQuantity <= 0;

  /// 是否需要补货
  bool get needsRestock => remainingQuantity <= quantity * 0.2;

  /// 更新新鲜度状态
  String calculateFreshness() {
    if (expiryDate == null) return freshness ?? 'normal';

    final now = DateTime.now();
    final daysUntilExpiry = expiryDate!.difference(now).inDays;

    if (daysUntilExpiry < 0) return 'expired';
    if (daysUntilExpiry <= 2) return 'expiring';
    if (daysUntilExpiry <= 7) return 'normal';
    return 'fresh';
  }

  /// 使用食材
  void use(double amount) {
    usedQuantity = (usedQuantity ?? 0) + amount;
    updatedAt = DateTime.now();
  }

  /// 补充食材
  void restock(double amount) {
    quantity += amount;
    updatedAt = DateTime.now();
  }

  /// 是否临期（3天内）
  bool get isExpiring {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate!.difference(now).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
  }

  /// 是否已过期
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  /// 格式化数量显示
  String get quantityFormatted {
    final qty = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$qty$unit';
  }

  /// 格式化保质期显示
  String get expiryFormatted {
    if (expiryDate == null) return '未设置';
    return '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}';
  }

  /// 复制并修改
  IngredientModel copyWith({
    String? id,
    String? familyId,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    String? freshness,
    DateTime? expiryDate,
    String? storageAdvice,
    String? source,
    DateTime? addedAt,
    DateTime? updatedAt,
    double? usedQuantity,
  }) {
    return IngredientModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      freshness: freshness ?? this.freshness,
      expiryDate: expiryDate ?? this.expiryDate,
      storageAdvice: storageAdvice ?? this.storageAdvice,
      source: source ?? this.source,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usedQuantity: usedQuantity ?? this.usedQuantity,
    );
  }
}

/// 食材类别
class IngredientCategories {
  static const List<String> options = [
    '蔬菜',
    '水果',
    '肉类',
    '海鲜',
    '蛋奶',
    '豆制品',
    '主食',
    '调味料',
    '干货',
    '饮品',
    '零食',
    '其他',
  ];

  /// 获取类别图标
  static String getIcon(String category) {
    switch (category) {
      case '蔬菜':
        return '🥬';
      case '水果':
        return '🍎';
      case '肉类':
        return '🥩';
      case '海鲜':
        return '🐟';
      case '蛋奶':
        return '🥚';
      case '豆制品':
        return '🫘';
      case '主食':
        return '🍚';
      case '调味料':
        return '🧂';
      case '干货':
        return '🥜';
      case '饮品':
        return '🥤';
      case '零食':
        return '🍪';
      default:
        return '📦';
    }
  }
}

/// 常用单位
class IngredientUnits {
  static const List<String> options = [
    '个',
    '根',
    '颗',
    '块',
    '片',
    '把',
    '包',
    '盒',
    '瓶',
    '袋',
    '克',
    '千克',
    '斤',
    '两',
    '毫升',
    '升',
  ];
}

/// 新鲜度状态
class FreshnessStatus {
  static const String fresh = 'fresh';
  static const String normal = 'normal';
  static const String expiring = 'expiring';
  static const String expired = 'expired';

  static String getLabel(String status) {
    switch (status) {
      case fresh:
        return '新鲜';
      case normal:
        return '正常';
      case expiring:
        return '临期';
      case expired:
        return '已过期';
      default:
        return '未知';
    }
  }

  static String getIcon(String status) {
    switch (status) {
      case fresh:
        return '✅';
      case normal:
        return '🟡';
      case expiring:
        return '⚠️';
      case expired:
        return '❌';
      default:
        return '❓';
    }
  }
}
