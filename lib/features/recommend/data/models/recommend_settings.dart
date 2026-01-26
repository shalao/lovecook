/// 推荐设置模型
class RecommendSettings {
  /// 生成天数 (1, 3, 5, 7)
  final int days;

  /// 是否包含早餐
  final bool breakfast;

  /// 是否包含午餐
  final bool lunch;

  /// 是否包含晚餐
  final bool dinner;

  /// 是否包含甜点/加餐
  final bool snacks;

  /// 每餐菜品数 (1-6)
  final int dishesPerMeal;

  /// 心情/口味输入
  final String? moodInput;

  /// 避免重复的天数 (3, 5, 7, 14, 30)
  final int avoidRecentDays;

  /// v1.2: 菜单开始日期（默认为今天）
  final DateTime startDate;

  RecommendSettings({
    this.days = 1,
    this.breakfast = true,
    this.lunch = true,
    this.dinner = true,
    this.snacks = false,
    this.dishesPerMeal = 2,
    this.moodInput,
    this.avoidRecentDays = 7,
    DateTime? startDate,
  }) : startDate = startDate ?? DateTime.now();

  /// 根据家庭人数获取默认菜品数
  static int getDefaultDishesPerMeal(int familyMemberCount) {
    if (familyMemberCount <= 2) return 2;
    if (familyMemberCount <= 4) return 3;
    if (familyMemberCount <= 6) return 4;
    return 5;
  }

  /// 创建带有默认菜品数的设置
  factory RecommendSettings.withFamilySize(int familyMemberCount, {DateTime? startDate}) {
    return RecommendSettings(
      dishesPerMeal: getDefaultDishesPerMeal(familyMemberCount),
      startDate: startDate,
    );
  }

  /// 获取选中的餐次列表
  List<String> get selectedMealTypes {
    final types = <String>[];
    if (breakfast) types.add('早餐');
    if (lunch) types.add('午餐');
    if (dinner) types.add('晚餐');
    if (snacks) types.add('加餐');
    return types;
  }

  /// 是否至少选择了一个餐次
  bool get hasSelectedMealType =>
      breakfast || lunch || dinner || snacks;

  /// 可选的天数列表
  static const List<int> availableDays = [1, 3, 5, 7];

  /// 可选的菜品数列表
  static const List<int> availableDishesPerMeal = [1, 2, 3, 4, 5, 6];

  /// 可选的避重天数列表
  static const List<int> availableAvoidRecentDays = [3, 5, 7, 14, 30];

  /// 快捷标签列表
  static const List<String> quickMoodTags = [
    '清淡',
    '重口味',
    '辣',
    '酸甜',
    '滋补',
    '快手菜',
    '解馋',
    '健康',
  ];

  RecommendSettings copyWith({
    int? days,
    bool? breakfast,
    bool? lunch,
    bool? dinner,
    bool? snacks,
    int? dishesPerMeal,
    String? moodInput,
    int? avoidRecentDays,
    bool clearMoodInput = false,
    DateTime? startDate,
  }) {
    return RecommendSettings(
      days: days ?? this.days,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snacks: snacks ?? this.snacks,
      dishesPerMeal: dishesPerMeal ?? this.dishesPerMeal,
      moodInput: clearMoodInput ? null : (moodInput ?? this.moodInput),
      avoidRecentDays: avoidRecentDays ?? this.avoidRecentDays,
      startDate: startDate ?? this.startDate,
    );
  }

  @override
  String toString() {
    return 'RecommendSettings(days: $days, meals: ${selectedMealTypes.join(", ")}, '
        'dishesPerMeal: $dishesPerMeal, moodInput: $moodInput, '
        'avoidRecentDays: $avoidRecentDays)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecommendSettings &&
        other.days == days &&
        other.breakfast == breakfast &&
        other.lunch == lunch &&
        other.dinner == dinner &&
        other.snacks == snacks &&
        other.dishesPerMeal == dishesPerMeal &&
        other.moodInput == moodInput &&
        other.avoidRecentDays == avoidRecentDays &&
        other.startDate.year == startDate.year &&
        other.startDate.month == startDate.month &&
        other.startDate.day == startDate.day;
  }

  @override
  int get hashCode {
    return Object.hash(
      days,
      breakfast,
      lunch,
      dinner,
      snacks,
      dishesPerMeal,
      moodInput,
      avoidRecentDays,
      startDate.year,
      startDate.month,
      startDate.day,
    );
  }
}
