import 'package:hive/hive.dart';

part 'meal_history_model.g.dart';

/// 用餐历史记录模型
@HiveType(typeId: 50)
class MealHistoryModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String familyId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String mealType; // breakfast, lunch, dinner, snacks

  @HiveField(4)
  List<MealHistoryRecipeModel> recipes;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  MealHistoryModel({
    required this.id,
    required this.familyId,
    required this.date,
    required this.mealType,
    required this.recipes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealHistoryModel.create({
    required String familyId,
    required DateTime date,
    required String mealType,
    required List<MealHistoryRecipeModel> recipes,
    String? notes,
  }) {
    final now = DateTime.now();
    return MealHistoryModel(
      id: now.millisecondsSinceEpoch.toString(),
      familyId: familyId,
      date: DateTime(date.year, date.month, date.day), // 只保留日期部分
      mealType: mealType,
      recipes: recipes,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 获取餐次显示名称
  String get mealTypeName {
    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snacks':
        return '甜点';
      default:
        return mealType;
    }
  }

  /// 获取评价汇总
  Map<int, int> get ratingCounts {
    final counts = <int, int>{};
    for (final recipe in recipes) {
      if (recipe.rating != null) {
        counts[recipe.rating!] = (counts[recipe.rating!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// 是否有未评价的菜品
  bool get hasUnratedRecipes =>
      recipes.any((r) => r.rating == null);

  MealHistoryModel copyWith({
    String? id,
    String? familyId,
    DateTime? date,
    String? mealType,
    List<MealHistoryRecipeModel>? recipes,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNotes = false,
  }) {
    return MealHistoryModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      recipes: recipes ?? this.recipes,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// 用餐历史中的菜品记录
@HiveType(typeId: 51)
class MealHistoryRecipeModel {
  @HiveField(0)
  String recipeId;

  @HiveField(1)
  String recipeName;

  @HiveField(2)
  int? rating; // 1-5 评分，null 表示未评价

  @HiveField(3)
  String? comment;

  MealHistoryRecipeModel({
    required this.recipeId,
    required this.recipeName,
    this.rating,
    this.comment,
  });

  factory MealHistoryRecipeModel.fromRecipe({
    required String recipeId,
    required String recipeName,
  }) {
    return MealHistoryRecipeModel(
      recipeId: recipeId,
      recipeName: recipeName,
    );
  }

  MealHistoryRecipeModel copyWith({
    String? recipeId,
    String? recipeName,
    int? rating,
    String? comment,
    bool clearRating = false,
    bool clearComment = false,
  }) {
    return MealHistoryRecipeModel(
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      rating: clearRating ? null : (rating ?? this.rating),
      comment: clearComment ? null : (comment ?? this.comment),
    );
  }

  /// 评价标签
  String? get ratingLabel {
    switch (rating) {
      case 1:
        return '不喜欢';
      case 2:
        return '一般般';
      case 3:
        return '还可以';
      case 4:
        return '很好吃';
      case 5:
        return '超级棒';
      default:
        return null;
    }
  }

  /// 评价图标
  String? get ratingEmoji {
    switch (rating) {
      case 1:
        return '😞';
      case 2:
        return '😐';
      case 3:
        return '🙂';
      case 4:
        return '😊';
      case 5:
        return '😍';
      default:
        return null;
    }
  }
}

/// 评分选项
class RatingOptions {
  static const List<Map<String, dynamic>> options = [
    {'value': 1, 'label': '不喜欢', 'emoji': '😞'},
    {'value': 2, 'label': '一般般', 'emoji': '😐'},
    {'value': 3, 'label': '还可以', 'emoji': '🙂'},
    {'value': 4, 'label': '很好吃', 'emoji': '😊'},
    {'value': 5, 'label': '超级棒', 'emoji': '😍'},
  ];
}
