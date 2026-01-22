import 'package:hive/hive.dart';

part 'family_model.g.dart';

@HiveType(typeId: 0)
class FamilyModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? avatarPath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  List<FamilyMemberModel> members;

  @HiveField(6)
  MealSettingsModel mealSettings;

  FamilyModel({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    required this.mealSettings,
  });

  factory FamilyModel.create({
    required String name,
    String? avatarPath,
    List<FamilyMemberModel>? members,
    MealSettingsModel? mealSettings,
  }) {
    final now = DateTime.now();
    return FamilyModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      avatarPath: avatarPath,
      createdAt: now,
      updatedAt: now,
      members: members ?? [],
      mealSettings: mealSettings ?? MealSettingsModel.defaultSettings(),
    );
  }
}

@HiveType(typeId: 1)
class FamilyMemberModel {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int? age;

  @HiveField(3)
  String? ageGroup; // 婴幼儿/儿童/青少年/成人/老年

  @HiveField(4)
  List<String> healthConditions; // 控糖/三高/减脂/孕期等

  @HiveField(5)
  List<String> allergies;

  @HiveField(6)
  List<String> dislikes;

  @HiveField(7)
  List<String> favorites;

  @HiveField(8)
  String? notes; // 备注（如：糖尿病需严格控糖、痛风避免高嘌呤食物等）

  FamilyMemberModel({
    required this.id,
    required this.name,
    this.age,
    this.ageGroup,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dislikes = const [],
    this.favorites = const [],
    this.notes,
  });

  factory FamilyMemberModel.create({
    required String name,
    int? age,
    String? ageGroup,
    String? notes,
  }) {
    return FamilyMemberModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      age: age,
      ageGroup: ageGroup,
      healthConditions: [],
      allergies: [],
      dislikes: [],
      favorites: [],
      notes: notes,
    );
  }

  /// 根据年龄自动判断年龄组
  static String getAgeGroup(int age) {
    if (age < 3) return '婴幼儿';
    if (age < 12) return '儿童';
    if (age < 18) return '青少年';
    if (age < 60) return '成人';
    return '老年';
  }
}

@HiveType(typeId: 2)
class MealSettingsModel {
  @HiveField(0)
  bool breakfast;

  @HiveField(1)
  bool lunch;

  @HiveField(2)
  bool dinner;

  @HiveField(3)
  bool snacks;

  @HiveField(4)
  int defaultPlanDays;

  MealSettingsModel({
    this.breakfast = true,
    this.lunch = true,
    this.dinner = true,
    this.snacks = false,
    this.defaultPlanDays = 7,
  });

  factory MealSettingsModel.defaultSettings() {
    return MealSettingsModel(
      breakfast: true,
      lunch: true,
      dinner: true,
      snacks: false,
      defaultPlanDays: 7,
    );
  }
}

/// 健康状况预设选项
class HealthConditions {
  static const List<String> options = [
    '控糖',
    '高血压',
    '高血脂',
    '脂肪肝',
    '减脂期',
    '增肌期',
    '儿童成长',
    '孕期',
    '哺乳期',
    '素食',
    '纯素',
    '低盐',
    '低脂',
    '高蛋白',
    '补钙',
    '补铁',
  ];
}

/// 年龄组选项
class AgeGroups {
  static const List<String> options = [
    '婴幼儿',
    '儿童',
    '青少年',
    '成人',
    '老年',
  ];
}
