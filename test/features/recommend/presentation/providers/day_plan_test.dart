import 'package:flutter_test/flutter_test.dart';
import 'package:love_cook/features/recommend/presentation/providers/recommend_provider.dart';
import 'package:love_cook/features/recipe/data/models/recipe_model.dart';

void main() {
  group('DayPlan', () {
    group('dayLabel', () {
      test('第0天显示"今天"', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final plan = DayPlan(
          dayIndex: 0,
          date: today,
        );

        expect(plan.dayLabel, '今天');
      });

      test('第1天显示"明天"', () {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        final plan = DayPlan(
          dayIndex: 1,
          date: tomorrow,
        );

        expect(plan.dayLabel, '明天');
      });

      test('第2天显示"后天"', () {
        final now = DateTime.now();
        final dayAfterTomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
        final plan = DayPlan(
          dayIndex: 2,
          date: dayAfterTomorrow,
        );

        expect(plan.dayLabel, '后天');
      });

      test('第3天及以后显示"第N天"', () {
        final now = DateTime.now();
        final day3 = DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
        final plan3 = DayPlan(
          dayIndex: 3,
          date: day3,
        );

        expect(plan3.dayLabel, '第4天');

        final day6 = DateTime(now.year, now.month, now.day).add(const Duration(days: 6));
        final plan6 = DayPlan(
          dayIndex: 6,
          date: day6,
        );

        expect(plan6.dayLabel, '第7天');
      });
    });

    group('dateLabel', () {
      test('正确格式化日期', () {
        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        expect(plan.dateLabel, '1月22日');
      });

      test('两位数月份和日期', () {
        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 12, 31),
        );

        expect(plan.dateLabel, '12月31日');
      });
    });

    group('hasAnyRecipes', () {
      test('空计划返回false', () {
        // DayPlan 需要 date，这里测试默认餐次都为空
        final emptyPlan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        expect(emptyPlan.hasAnyRecipes, false);
      });

      test('有早餐返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
          breakfast: MealRecommend(
            type: 'breakfast',
            typeName: '早餐',
            recipes: [recipe],
          ),
        );

        expect(plan.hasAnyRecipes, true);
      });

      test('有午餐返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
          lunch: MealRecommend(
            type: 'lunch',
            typeName: '午餐',
            recipes: [recipe],
          ),
        );

        expect(plan.hasAnyRecipes, true);
      });

      test('有晚餐返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
          dinner: MealRecommend(
            type: 'dinner',
            typeName: '晚餐',
            recipes: [recipe],
          ),
        );

        expect(plan.hasAnyRecipes, true);
      });

      test('有甜点返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final plan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
          snacks: MealRecommend(
            type: 'snacks',
            typeName: '甜点',
            recipes: [recipe],
          ),
        );

        expect(plan.hasAnyRecipes, true);
      });
    });

    group('copyWith', () {
      test('复制并修改dayIndex', () {
        final original = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        final copied = original.copyWith(dayIndex: 1);

        expect(copied.dayIndex, 1);
        expect(copied.date, original.date);
      });

      test('复制并修改date', () {
        final original = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        final newDate = DateTime(2025, 1, 23);
        final copied = original.copyWith(date: newDate);

        expect(copied.date, newDate);
        expect(copied.dayIndex, 0);
      });

      test('复制并修改breakfast', () {
        final original = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final newBreakfast = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
          recipes: [recipe],
        );

        final copied = original.copyWith(breakfast: newBreakfast);

        expect(copied.breakfast.recipes.length, 1);
        expect(copied.breakfast.recipes.first.name, '测试菜');
      });

      test('不传参数返回相同值的新实例', () {
        final original = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        final copied = original.copyWith();

        expect(copied.dayIndex, original.dayIndex);
        expect(copied.date, original.date);
      });
    });
  });

  group('MealRecommend', () {
    group('默认值', () {
      test('默认recipes为空列表', () {
        const meal = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
        );

        expect(meal.recipes, isEmpty);
        expect(meal.isLoading, false);
        expect(meal.error, null);
      });
    });

    group('copyWith', () {
      test('复制并修改recipes', () {
        const original = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
        );

        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final copied = original.copyWith(recipes: [recipe]);

        expect(copied.recipes.length, 1);
        expect(copied.type, 'breakfast');
        expect(copied.typeName, '早餐');
      });

      test('复制并修改isLoading', () {
        const original = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
        );

        final copied = original.copyWith(isLoading: true);

        expect(copied.isLoading, true);
      });

      test('复制并修改error', () {
        const original = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
        );

        final copied = original.copyWith(error: '网络错误');

        expect(copied.error, '网络错误');
      });

      test('clearError清除错误', () {
        const original = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
          error: '之前的错误',
        );

        final copied = original.copyWith(clearError: true);

        expect(copied.error, null);
      });

      test('clearError优先于error', () {
        const original = MealRecommend(
          type: 'breakfast',
          typeName: '早餐',
          error: '之前的错误',
        );

        final copied = original.copyWith(
          error: '新错误',
          clearError: true,
        );

        expect(copied.error, null);
      });
    });
  });

  group('RecommendState', () {
    group('hasAnyRecommendation', () {
      test('空状态返回false', () {
        const state = RecommendState();

        expect(state.hasAnyRecommendation, false);
      });

      test('有dayPlans且有菜谱返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final dayPlan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
          breakfast: MealRecommend(
            type: 'breakfast',
            typeName: '早餐',
            recipes: [recipe],
          ),
        );

        final state = RecommendState(dayPlans: [dayPlan]);

        expect(state.hasAnyRecommendation, true);
      });

      test('直接的breakfast有菜谱返回true', () {
        final recipe = RecipeModel.create(
          name: '测试菜',
          ingredients: [],
          steps: [],
        );

        final state = RecommendState(
          breakfast: MealRecommend(
            type: 'breakfast',
            typeName: '早餐',
            recipes: [recipe],
          ),
        );

        expect(state.hasAnyRecommendation, true);
      });
    });

    group('isAnyLoading', () {
      test('初始状态不加载', () {
        const state = RecommendState();

        expect(state.isAnyLoading, false);
      });

      test('isInitialLoading为true时返回true', () {
        const state = RecommendState(isInitialLoading: true);

        expect(state.isAnyLoading, true);
      });

      test('任意餐次加载中返回true', () {
        const state = RecommendState(
          breakfast: MealRecommend(
            type: 'breakfast',
            typeName: '早餐',
            isLoading: true,
          ),
        );

        expect(state.isAnyLoading, true);
      });
    });

    group('isMultiDay', () {
      test('空dayPlans返回false', () {
        const state = RecommendState();

        expect(state.isMultiDay, false);
      });

      test('单天返回false', () {
        final dayPlan = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );

        final state = RecommendState(dayPlans: [dayPlan]);

        expect(state.isMultiDay, false);
      });

      test('多天返回true', () {
        final dayPlan1 = DayPlan(
          dayIndex: 0,
          date: DateTime(2025, 1, 22),
        );
        final dayPlan2 = DayPlan(
          dayIndex: 1,
          date: DateTime(2025, 1, 23),
        );

        final state = RecommendState(dayPlans: [dayPlan1, dayPlan2]);

        expect(state.isMultiDay, true);
      });
    });

    group('getMealByType', () {
      test('返回正确的餐次', () {
        final recipe = RecipeModel.create(
          name: '早餐菜',
          ingredients: [],
          steps: [],
        );

        final state = RecommendState(
          breakfast: MealRecommend(
            type: 'breakfast',
            typeName: '早餐',
            recipes: [recipe],
          ),
        );

        final breakfast = state.getMealByType('breakfast');
        expect(breakfast.recipes.first.name, '早餐菜');

        final lunch = state.getMealByType('lunch');
        expect(lunch.recipes, isEmpty);
      });

      test('未知类型返回breakfast', () {
        const state = RecommendState();

        final result = state.getMealByType('unknown');
        expect(result.type, 'breakfast');
      });
    });
  });
}
