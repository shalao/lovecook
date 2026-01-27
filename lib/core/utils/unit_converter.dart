// 单位转换和等价判断工具
// 用于处理食材单位的标准化、等价判断和换算

/// 单位等价组定义
class UnitEquivalenceGroup {
  final String name;
  final String standardUnit;  // 标准单位
  final Map<String, double> conversionFactors;  // 单位 -> 转换为标准单位的系数

  const UnitEquivalenceGroup({
    required this.name,
    required this.standardUnit,
    required this.conversionFactors,
  });
}

/// 单位转换结果
class UnitConversionResult {
  final double quantity;
  final String unit;
  final bool wasConverted;

  const UnitConversionResult({
    required this.quantity,
    required this.unit,
    required this.wasConverted,
  });
}

/// 单位转换器
class UnitConverter {
  /// 单位等价组
  static const _equivalenceGroups = <UnitEquivalenceGroup>[
    // 计数单位 - 条状蔬菜（黄瓜、胡萝卜、茄子等）
    UnitEquivalenceGroup(
      name: 'count_elongated',
      standardUnit: '根',
      conversionFactors: {
        '根': 1.0,
        '个': 1.0,
        '条': 1.0,
      },
    ),
    // 计数单位 - 圆形/块状（土豆、苹果、洋葱等）
    UnitEquivalenceGroup(
      name: 'count_round',
      standardUnit: '个',
      conversionFactors: {
        '个': 1.0,
        '颗': 1.0,
        '只': 1.0,
      },
    ),
    // 计数单位 - 叶菜/把状（葱、香菜、韭菜等）
    UnitEquivalenceGroup(
      name: 'count_bunch',
      standardUnit: '把',
      conversionFactors: {
        '把': 1.0,
        '束': 1.0,
        '棵': 1.0,
      },
    ),
    // 计数单位 - 块状（豆腐、肉块等）
    UnitEquivalenceGroup(
      name: 'count_block',
      standardUnit: '块',
      conversionFactors: {
        '块': 1.0,
        '片': 1.0,
      },
    ),
    // 重量单位（以克为标准）
    UnitEquivalenceGroup(
      name: 'weight',
      standardUnit: '克',
      conversionFactors: {
        '克': 1.0,
        'g': 1.0,
        '千克': 1000.0,
        'kg': 1000.0,
        '斤': 500.0,
        '两': 50.0,
        '公斤': 1000.0,
      },
    ),
    // 体积单位（以毫升为标准）
    UnitEquivalenceGroup(
      name: 'volume',
      standardUnit: '毫升',
      conversionFactors: {
        '毫升': 1.0,
        'ml': 1.0,
        '升': 1000.0,
        'L': 1000.0,
        '杯': 250.0,      // 假设一杯约250ml
        '碗': 300.0,      // 假设一碗约300ml
      },
    ),
    // 调味料单位（以勺为标准）
    UnitEquivalenceGroup(
      name: 'seasoning',
      standardUnit: '勺',
      conversionFactors: {
        '勺': 1.0,
        '汤匙': 1.0,
        '大勺': 1.0,
        '茶匙': 0.33,
        '小勺': 0.33,
        '少许': 0.25,
        '适量': 1.0,
      },
    ),
    // 包装单位
    UnitEquivalenceGroup(
      name: 'package',
      standardUnit: '包',
      conversionFactors: {
        '包': 1.0,
        '袋': 1.0,
        '盒': 1.0,
        '瓶': 1.0,
        '罐': 1.0,
      },
    ),
  ];

  /// 食材特定单位映射
  /// 某些食材有特定的标准单位
  static const _ingredientStandardUnits = <String, String>{
    // 条状蔬菜
    '黄瓜': '根',
    '胡萝卜': '根',
    '茄子': '根',
    '丝瓜': '根',
    '苦瓜': '根',
    '莴笋': '根',
    '山药': '根',
    '玉米': '根',
    '香蕉': '根',
    '葱': '根',
    '大葱': '根',
    '蒜苗': '根',
    '蒜薹': '根',
    '芹菜': '根',
    // 叶菜
    '小葱': '把',
    '香葱': '把',
    '香菜': '把',
    '韭菜': '把',
    '菠菜': '把',
    '油麦菜': '把',
    '生菜': '把',
    '空心菜': '把',
    // 圆形蔬菜
    '土豆': '个',
    '马铃薯': '个',
    '洋葱': '个',
    '番茄': '个',
    '西红柿': '个',
    '青椒': '个',
    '辣椒': '个',
    '苹果': '个',
    '梨': '个',
    '橙子': '个',
    '柠檬': '个',
    '鸡蛋': '个',
    '蒜': '头',
    '大蒜': '头',
    '姜': '块',
    '生姜': '块',
    // 块状
    '豆腐': '块',
    // 颗粒状
    '蒜瓣': '瓣',
  };

  /// 判断两个单位是否等价
  static bool areUnitsEquivalent(String unit1, String unit2) {
    if (unit1 == unit2) return true;

    // 查找两个单位是否在同一个等价组中
    for (final group in _equivalenceGroups) {
      final hasUnit1 = group.conversionFactors.containsKey(unit1);
      final hasUnit2 = group.conversionFactors.containsKey(unit2);
      if (hasUnit1 && hasUnit2) {
        return true;
      }
    }
    return false;
  }

  /// 获取单位所属的等价组
  static UnitEquivalenceGroup? getEquivalenceGroup(String unit) {
    for (final group in _equivalenceGroups) {
      if (group.conversionFactors.containsKey(unit)) {
        return group;
      }
    }
    return null;
  }

  /// 将数量从一个单位转换为另一个单位
  /// 返回 null 如果无法转换
  static UnitConversionResult? convert({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    if (fromUnit == toUnit) {
      return UnitConversionResult(
        quantity: quantity,
        unit: toUnit,
        wasConverted: false,
      );
    }

    // 查找等价组
    final group = getEquivalenceGroup(fromUnit);
    if (group == null || !group.conversionFactors.containsKey(toUnit)) {
      return null;
    }

    // 转换
    final fromFactor = group.conversionFactors[fromUnit]!;
    final toFactor = group.conversionFactors[toUnit]!;
    final convertedQuantity = quantity * fromFactor / toFactor;

    return UnitConversionResult(
      quantity: convertedQuantity,
      unit: toUnit,
      wasConverted: true,
    );
  }

  /// 将数量转换为标准单位
  static UnitConversionResult convertToStandard({
    required double quantity,
    required String unit,
    String? ingredientName,
  }) {
    // 如果指定了食材名，优先使用食材特定的标准单位
    if (ingredientName != null) {
      final standardUnit = _ingredientStandardUnits[ingredientName];
      if (standardUnit != null && areUnitsEquivalent(unit, standardUnit)) {
        final result = convert(
          quantity: quantity,
          fromUnit: unit,
          toUnit: standardUnit,
        );
        if (result != null) return result;
      }
    }

    // 否则使用等价组的标准单位
    final group = getEquivalenceGroup(unit);
    if (group == null) {
      return UnitConversionResult(
        quantity: quantity,
        unit: unit,
        wasConverted: false,
      );
    }

    final result = convert(
      quantity: quantity,
      fromUnit: unit,
      toUnit: group.standardUnit,
    );
    return result ?? UnitConversionResult(
      quantity: quantity,
      unit: unit,
      wasConverted: false,
    );
  }

  /// 获取食材的推荐标准单位
  static String? getStandardUnit(String ingredientName) {
    return _ingredientStandardUnits[ingredientName];
  }

  /// 判断是否可以合并两个食材项（名称相同或同义，单位等价）
  static bool canMerge({
    required String name1,
    required String unit1,
    required String name2,
    required String unit2,
  }) {
    // 名称必须相同（同义词匹配应在外部处理）
    if (name1 != name2) return false;

    // 单位相同或等价
    return areUnitsEquivalent(unit1, unit2);
  }

  /// 合并两个数量（将第二个转换为第一个的单位后相加）
  static ({double quantity, String unit})? mergeQuantities({
    required double quantity1,
    required String unit1,
    required double quantity2,
    required String unit2,
    String? ingredientName,
  }) {
    if (unit1 == unit2) {
      return (quantity: quantity1 + quantity2, unit: unit1);
    }

    // 尝试将 unit2 转换为 unit1
    final converted = convert(
      quantity: quantity2,
      fromUnit: unit2,
      toUnit: unit1,
    );

    if (converted != null) {
      return (quantity: quantity1 + converted.quantity, unit: unit1);
    }

    // 如果无法直接转换，尝试都转换为标准单位
    final standard1 = convertToStandard(
      quantity: quantity1,
      unit: unit1,
      ingredientName: ingredientName,
    );
    final standard2 = convertToStandard(
      quantity: quantity2,
      unit: unit2,
      ingredientName: ingredientName,
    );

    if (standard1.unit == standard2.unit) {
      return (
        quantity: standard1.quantity + standard2.quantity,
        unit: standard1.unit,
      );
    }

    // 无法合并
    return null;
  }

  /// 格式化数量显示
  static String formatQuantity(double quantity, String unit) {
    // 如果是整数，不显示小数点
    if (quantity == quantity.toInt()) {
      return '${quantity.toInt()}$unit';
    }
    // 否则保留一位小数
    return '${quantity.toStringAsFixed(1)}$unit';
  }

  /// 获取所有支持的单位列表
  static List<String> getAllUnits() {
    final units = <String>{};
    for (final group in _equivalenceGroups) {
      units.addAll(group.conversionFactors.keys);
    }
    return units.toList()..sort();
  }

  /// 获取指定等价组的所有单位
  static List<String> getUnitsInGroup(String groupName) {
    for (final group in _equivalenceGroups) {
      if (group.name == groupName) {
        return group.conversionFactors.keys.toList();
      }
    }
    return [];
  }
}
