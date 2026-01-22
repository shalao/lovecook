import 'package:flutter_test/flutter_test.dart';
import 'package:love_cook/features/recommend/data/models/recommend_settings.dart';

void main() {
  group('RecommendSettings', () {
    group('默认值', () {
      test('默认值正确', () {
        const settings = RecommendSettings();

        expect(settings.days, 1);
        expect(settings.breakfast, true);
        expect(settings.lunch, true);
        expect(settings.dinner, true);
        expect(settings.snacks, false);
        expect(settings.dishesPerMeal, 2);
        expect(settings.moodInput, null);
        expect(settings.avoidRecentDays, 7);
      });
    });

    group('getDefaultDishesPerMeal', () {
      test('1-2人家庭返回2道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(1), 2);
        expect(RecommendSettings.getDefaultDishesPerMeal(2), 2);
      });

      test('3-4人家庭返回3道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(3), 3);
        expect(RecommendSettings.getDefaultDishesPerMeal(4), 3);
      });

      test('5-6人家庭返回4道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(5), 4);
        expect(RecommendSettings.getDefaultDishesPerMeal(6), 4);
      });

      test('7人以上家庭返回5道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(7), 5);
        expect(RecommendSettings.getDefaultDishesPerMeal(10), 5);
        expect(RecommendSettings.getDefaultDishesPerMeal(100), 5);
      });

      test('边界值0人返回2道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(0), 2);
      });

      test('负数返回2道', () {
        expect(RecommendSettings.getDefaultDishesPerMeal(-1), 2);
      });
    });

    group('withFamilySize 工厂构造', () {
      test('根据家庭人数创建设置', () {
        final settings = RecommendSettings.withFamilySize(4);

        expect(settings.dishesPerMeal, 3);
        // 其他值应为默认值
        expect(settings.days, 1);
        expect(settings.breakfast, true);
      });
    });

    group('selectedMealTypes', () {
      test('默认返回早餐、午餐、晚餐', () {
        const settings = RecommendSettings();

        expect(settings.selectedMealTypes, ['早餐', '午餐', '晚餐']);
      });

      test('只选择早餐', () {
        const settings = RecommendSettings(
          breakfast: true,
          lunch: false,
          dinner: false,
          snacks: false,
        );

        expect(settings.selectedMealTypes, ['早餐']);
      });

      test('只选择午餐和晚餐', () {
        const settings = RecommendSettings(
          breakfast: false,
          lunch: true,
          dinner: true,
          snacks: false,
        );

        expect(settings.selectedMealTypes, ['午餐', '晚餐']);
      });

      test('全部选中', () {
        const settings = RecommendSettings(
          breakfast: true,
          lunch: true,
          dinner: true,
          snacks: true,
        );

        expect(settings.selectedMealTypes, ['早餐', '午餐', '晚餐', '加餐']);
      });

      test('全部不选中返回空列表', () {
        const settings = RecommendSettings(
          breakfast: false,
          lunch: false,
          dinner: false,
          snacks: false,
        );

        expect(settings.selectedMealTypes, isEmpty);
      });
    });

    group('hasSelectedMealType', () {
      test('默认有选中餐次', () {
        const settings = RecommendSettings();

        expect(settings.hasSelectedMealType, true);
      });

      test('只选择一个餐次返回true', () {
        const settings = RecommendSettings(
          breakfast: false,
          lunch: false,
          dinner: false,
          snacks: true,
        );

        expect(settings.hasSelectedMealType, true);
      });

      test('全部不选中返回false', () {
        const settings = RecommendSettings(
          breakfast: false,
          lunch: false,
          dinner: false,
          snacks: false,
        );

        expect(settings.hasSelectedMealType, false);
      });
    });

    group('静态常量', () {
      test('availableDays 包含正确值', () {
        expect(RecommendSettings.availableDays, [1, 3, 5, 7]);
      });

      test('availableDishesPerMeal 包含正确值', () {
        expect(RecommendSettings.availableDishesPerMeal, [1, 2, 3, 4, 5, 6]);
      });

      test('availableAvoidRecentDays 包含正确值', () {
        expect(RecommendSettings.availableAvoidRecentDays, [3, 5, 7, 14, 30]);
      });

      test('quickMoodTags 包含预设标签', () {
        expect(RecommendSettings.quickMoodTags, isNotEmpty);
        expect(RecommendSettings.quickMoodTags, contains('清淡'));
        expect(RecommendSettings.quickMoodTags, contains('辣'));
        expect(RecommendSettings.quickMoodTags, contains('快手菜'));
      });
    });

    group('copyWith', () {
      test('修改单个属性', () {
        const original = RecommendSettings();
        final copied = original.copyWith(days: 3);

        expect(copied.days, 3);
        expect(copied.breakfast, true);
        expect(copied.lunch, true);
        expect(copied.dinner, true);
      });

      test('修改多个属性', () {
        const original = RecommendSettings();
        final copied = original.copyWith(
          days: 7,
          breakfast: false,
          dishesPerMeal: 4,
          moodInput: '想吃辣的',
        );

        expect(copied.days, 7);
        expect(copied.breakfast, false);
        expect(copied.dishesPerMeal, 4);
        expect(copied.moodInput, '想吃辣的');
        // 未修改的保持原值
        expect(copied.lunch, true);
        expect(copied.dinner, true);
      });

      test('clearMoodInput 清除心情输入', () {
        const original = RecommendSettings(moodInput: '想吃清淡的');
        final copied = original.copyWith(clearMoodInput: true);

        expect(copied.moodInput, null);
      });

      test('clearMoodInput 优先于 moodInput', () {
        const original = RecommendSettings(moodInput: '原始');
        final copied = original.copyWith(
          moodInput: '新的',
          clearMoodInput: true,
        );

        expect(copied.moodInput, null);
      });

      test('不传参数返回相同值的新实例', () {
        const original = RecommendSettings(
          days: 3,
          breakfast: false,
          moodInput: '测试',
        );
        final copied = original.copyWith();

        expect(copied, equals(original));
        expect(identical(copied, original), false);
      });
    });

    group('toString', () {
      test('返回可读字符串', () {
        const settings = RecommendSettings(
          days: 3,
          breakfast: true,
          lunch: true,
          dinner: false,
          snacks: false,
          dishesPerMeal: 3,
          moodInput: '清淡',
          avoidRecentDays: 7,
        );

        final str = settings.toString();

        expect(str, contains('days: 3'));
        expect(str, contains('早餐'));
        expect(str, contains('午餐'));
        expect(str, contains('dishesPerMeal: 3'));
        expect(str, contains('moodInput: 清淡'));
      });
    });

    group('equality', () {
      test('相同属性的实例相等', () {
        const settings1 = RecommendSettings(days: 3, breakfast: true);
        const settings2 = RecommendSettings(days: 3, breakfast: true);

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('不同属性的实例不相等', () {
        const settings1 = RecommendSettings(days: 3);
        const settings2 = RecommendSettings(days: 5);

        expect(settings1, isNot(equals(settings2)));
      });

      test('与自身相等', () {
        const settings = RecommendSettings();

        expect(settings, equals(settings));
      });

      test('与其他类型不相等', () {
        const settings = RecommendSettings();

        expect(settings == 'string', false);
        expect(settings == 123, false);
        expect(settings == null, false);
      });
    });

    group('边界情况', () {
      test('moodInput 可以是空字符串', () {
        const settings = RecommendSettings(moodInput: '');

        expect(settings.moodInput, '');
      });

      test('moodInput 可以包含特殊字符', () {
        const settings = RecommendSettings(moodInput: '想吃🌶️辣的！@#\$%');

        expect(settings.moodInput, '想吃🌶️辣的！@#\$%');
      });

      test('moodInput 可以很长', () {
        final longInput = '想吃' * 100;
        final settings = RecommendSettings(moodInput: longInput);

        expect(settings.moodInput, longInput);
      });
    });
  });
}
