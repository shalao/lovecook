import 'package:hive/hive.dart';

part 'meal_plan_model.g.dart';

@HiveType(typeId: 30)
class MealPlanModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String familyId;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  DateTime endDate;

  @HiveField(4)
  List<DayPlanModel> days;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  String? shoppingListId;

  MealPlanModel({
    required this.id,
    required this.familyId,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.createdAt,
    this.notes,
    this.shoppingListId,
  });

  factory MealPlanModel.create({
    required String familyId,
    required DateTime startDate,
    required int days,
  }) {
    final endDate = startDate.add(Duration(days: days - 1));
    final dayPlans = List.generate(
      days,
      (index) => DayPlanModel(
        date: startDate.add(Duration(days: index)),
        meals: [],
      ),
    );

    return MealPlanModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      familyId: familyId,
      startDate: startDate,
      endDate: endDate,
      days: dayPlans,
      createdAt: DateTime.now(),
    );
  }

  /// 计划天数
  int get totalDays => days.length;

  /// 获取某一天的计划
  DayPlanModel? getDayPlan(DateTime date) {
    return days.firstWhere(
      (day) => _isSameDay(day.date, date),
      orElse: () => DayPlanModel(date: date, meals: []),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

@HiveType(typeId: 31)
class DayPlanModel {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  List<MealModel> meals;

  DayPlanModel({
    required this.date,
    required this.meals,
  });

  /// 获取某一餐的菜品
  MealModel? getMeal(String mealType) {
    return meals.firstWhere(
      (meal) => meal.type == mealType,
      orElse: () => MealModel(type: mealType, recipeIds: []),
    );
  }

  /// 格式化日期显示
  String get dateFormatted {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}月${date.day}日 $weekday';
  }
}

@HiveType(typeId: 32)
class MealModel {
  @HiveField(0)
  String type; // breakfast/lunch/dinner/snack

  @HiveField(1)
  List<String> recipeIds;

  @HiveField(2)
  String? notes;

  MealModel({
    required this.type,
    required this.recipeIds,
    this.notes,
  });

  /// 餐次标签
  String get label {
    switch (type) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐';
      default:
        return type;
    }
  }

  /// 餐次图标
  String get icon {
    switch (type) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      case 'snack':
        return '🍪';
      default:
        return '🍽️';
    }
  }
}

/// 餐次类型
class MealTypes {
  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String snack = 'snack';

  static const List<String> all = [breakfast, lunch, dinner, snack];
  static const List<String> main = [breakfast, lunch, dinner];

  static String getLabel(String type) {
    switch (type) {
      case breakfast:
        return '早餐';
      case lunch:
        return '午餐';
      case dinner:
        return '晚餐';
      case snack:
        return '加餐';
      default:
        return type;
    }
  }
}
