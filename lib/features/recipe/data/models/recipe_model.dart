import 'package:hive/hive.dart';

part 'recipe_model.g.dart';

@HiveType(typeId: 20)
class RecipeModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? familyId; // null 表示通用菜谱

  @HiveField(2)
  String name;

  @HiveField(3)
  String? description;

  @HiveField(4)
  List<String> tags; // 控糖友好/高蛋白/快手菜等

  @HiveField(5)
  int prepTime; // 分钟

  @HiveField(6)
  int cookTime; // 分钟

  @HiveField(7)
  int servings;

  @HiveField(8)
  List<RecipeIngredientModel> ingredients;

  @HiveField(9)
  List<String> steps;

  @HiveField(10)
  String? tips;

  @HiveField(11)
  NutritionInfoModel? nutrition;

  @HiveField(12)
  bool isFavorite;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  String? imageUrl;

  @HiveField(15)
  String? difficulty; // easy/medium/hard

  RecipeModel({
    required this.id,
    this.familyId,
    required this.name,
    this.description,
    this.tags = const [],
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 2,
    this.ingredients = const [],
    this.steps = const [],
    this.tips,
    this.nutrition,
    this.isFavorite = false,
    required this.createdAt,
    this.imageUrl,
    this.difficulty,
  });

  factory RecipeModel.create({
    String? familyId,
    required String name,
    String? description,
    List<String>? tags,
    int prepTime = 0,
    int cookTime = 0,
    int servings = 2,
    List<RecipeIngredientModel>? ingredients,
    List<String>? steps,
    String? tips,
    NutritionInfoModel? nutrition,
    String? imageUrl,
    String? difficulty,
  }) {
    return RecipeModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      familyId: familyId,
      name: name,
      description: description,
      tags: tags ?? [],
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      ingredients: ingredients ?? [],
      steps: steps ?? [],
      tips: tips,
      nutrition: nutrition,
      isFavorite: false,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      difficulty: difficulty ?? 'medium',
    );
  }

  /// 总时间（分钟）
  int get totalTime => prepTime + cookTime;

  /// 格式化时间显示
  String get totalTimeFormatted {
    final total = totalTime;
    if (total < 60) return '$total分钟';
    final hours = total ~/ 60;
    final mins = total % 60;
    if (mins == 0) return '$hours小时';
    return '$hours小时$mins分钟';
  }

  /// 切换收藏状态
  void toggleFavorite() {
    isFavorite = !isFavorite;
  }
}

@HiveType(typeId: 21)
class RecipeIngredientModel {
  @HiveField(0)
  String name;

  @HiveField(1)
  double quantity;

  @HiveField(2)
  String unit;

  @HiveField(3)
  bool isOptional;

  @HiveField(4)
  String? substitute;

  @HiveField(5)
  String? note;

  RecipeIngredientModel({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
    this.substitute,
    this.note,
  });

  /// 格式化显示
  String get formatted {
    final qty = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$name $qty$unit${isOptional ? '(可选)' : ''}';
  }
}

@HiveType(typeId: 22)
class NutritionInfoModel {
  @HiveField(0)
  double? calories; // 千卡

  @HiveField(1)
  double? protein; // 克

  @HiveField(2)
  double? carbs; // 克

  @HiveField(3)
  double? fat; // 克

  @HiveField(4)
  double? fiber; // 克

  @HiveField(5)
  double? sodium; // 毫克

  @HiveField(6)
  String? summary;

  NutritionInfoModel({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
    this.summary,
  });

  /// 格式化营养信息
  String get formatted {
    final parts = <String>[];
    if (calories != null) parts.add('热量: ${calories!.toInt()}千卡');
    if (protein != null) parts.add('蛋白质: ${protein!.toStringAsFixed(1)}g');
    if (carbs != null) parts.add('碳水: ${carbs!.toStringAsFixed(1)}g');
    if (fat != null) parts.add('脂肪: ${fat!.toStringAsFixed(1)}g');
    if (fiber != null) parts.add('膳食纤维: ${fiber!.toStringAsFixed(1)}g');
    return parts.join(' | ');
  }
}

/// 菜谱标签
class RecipeTags {
  static const List<String> healthTags = [
    '控糖友好',
    '低脂',
    '低盐',
    '高蛋白',
    '高纤维',
    '素食',
    '儿童友好',
    '孕妇友好',
    '老人友好',
  ];

  static const List<String> typeTags = [
    '快手菜',
    '家常菜',
    '下饭菜',
    '汤羹',
    '凉菜',
    '小炒',
    '炖煮',
    '蒸菜',
    '烧烤',
    '甜品',
  ];

  static const List<String> cuisineTags = [
    '川菜',
    '粤菜',
    '湘菜',
    '鲁菜',
    '苏菜',
    '浙菜',
    '闽菜',
    '徽菜',
    '西餐',
    '日料',
    '韩餐',
  ];
}

/// 难度级别
class DifficultyLevels {
  static const String easy = 'easy';
  static const String medium = 'medium';
  static const String hard = 'hard';

  static String getLabel(String level) {
    switch (level) {
      case easy:
        return '简单';
      case medium:
        return '中等';
      case hard:
        return '困难';
      default:
        return '未知';
    }
  }
}
