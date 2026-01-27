import 'package:flutter_test/flutter_test.dart';
import 'package:love_cook/core/utils/unit_converter.dart';

void main() {
  group('UnitConverter', () {
    group('areUnitsEquivalent', () {
      test('相同单位应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('个', '个'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('克', '克'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('根', '根'), isTrue);
      });

      test('条状蔬菜单位应该等价（根/个/条）', () {
        expect(UnitConverter.areUnitsEquivalent('根', '个'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('根', '条'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('个', '条'), isTrue);
      });

      test('重量单位应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('克', '千克'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('克', '斤'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('斤', '两'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('克', 'g'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('千克', 'kg'), isTrue);
      });

      test('体积单位应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('毫升', '升'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('毫升', '杯'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('毫升', 'ml'), isTrue);
      });

      test('调味料单位应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('勺', '汤匙'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('勺', '大勺'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('茶匙', '小勺'), isTrue);
      });

      test('包装单位应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('包', '袋'), isTrue);
        expect(UnitConverter.areUnitsEquivalent('盒', '瓶'), isTrue);
      });

      test('不同组的单位不应该等价', () {
        expect(UnitConverter.areUnitsEquivalent('克', '个'), isFalse);
        expect(UnitConverter.areUnitsEquivalent('毫升', '克'), isFalse);
        expect(UnitConverter.areUnitsEquivalent('根', '块'), isFalse);
        expect(UnitConverter.areUnitsEquivalent('勺', '克'), isFalse);
      });

      test('未知单位不等价', () {
        expect(UnitConverter.areUnitsEquivalent('未知单位', '克'), isFalse);
        expect(UnitConverter.areUnitsEquivalent('abc', 'def'), isFalse);
      });
    });

    group('convert', () {
      test('相同单位转换返回原值', () {
        final result = UnitConverter.convert(
          quantity: 100,
          fromUnit: '克',
          toUnit: '克',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(100));
        expect(result.unit, equals('克'));
        expect(result.wasConverted, isFalse);
      });

      test('重量单位转换 - 克到千克', () {
        final result = UnitConverter.convert(
          quantity: 1000,
          fromUnit: '克',
          toUnit: '千克',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(1));
        expect(result.unit, equals('千克'));
        expect(result.wasConverted, isTrue);
      });

      test('重量单位转换 - 千克到克', () {
        final result = UnitConverter.convert(
          quantity: 2,
          fromUnit: '千克',
          toUnit: '克',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(2000));
        expect(result.unit, equals('克'));
      });

      test('重量单位转换 - 斤到克', () {
        final result = UnitConverter.convert(
          quantity: 1,
          fromUnit: '斤',
          toUnit: '克',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(500));
      });

      test('重量单位转换 - 两到克', () {
        final result = UnitConverter.convert(
          quantity: 1,
          fromUnit: '两',
          toUnit: '克',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(50));
      });

      test('体积单位转换 - 升到毫升', () {
        final result = UnitConverter.convert(
          quantity: 1,
          fromUnit: '升',
          toUnit: '毫升',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(1000));
      });

      test('体积单位转换 - 杯到毫升', () {
        final result = UnitConverter.convert(
          quantity: 2,
          fromUnit: '杯',
          toUnit: '毫升',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(500)); // 2杯 = 500ml
      });

      test('计数单位转换 - 根到个（1:1）', () {
        final result = UnitConverter.convert(
          quantity: 3,
          fromUnit: '根',
          toUnit: '个',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(3));
      });

      test('不同组单位无法转换', () {
        final result = UnitConverter.convert(
          quantity: 100,
          fromUnit: '克',
          toUnit: '个',
        );
        expect(result, isNull);
      });
    });

    group('convertToStandard', () {
      test('重量转换为标准单位（克）', () {
        final result = UnitConverter.convertToStandard(
          quantity: 1,
          unit: '斤',
        );
        expect(result.quantity, equals(500));
        expect(result.unit, equals('克'));
        expect(result.wasConverted, isTrue);
      });

      test('体积转换为标准单位（毫升）', () {
        final result = UnitConverter.convertToStandard(
          quantity: 2,
          unit: '升',
        );
        expect(result.quantity, equals(2000));
        expect(result.unit, equals('毫升'));
      });

      test('指定食材名使用食材特定标准单位', () {
        // 黄瓜的标准单位是"根"
        final result = UnitConverter.convertToStandard(
          quantity: 2,
          unit: '个',
          ingredientName: '黄瓜',
        );
        expect(result.quantity, equals(2));
        expect(result.unit, equals('根'));
      });

      test('未知单位保持不变', () {
        final result = UnitConverter.convertToStandard(
          quantity: 5,
          unit: '未知单位',
        );
        expect(result.quantity, equals(5));
        expect(result.unit, equals('未知单位'));
        expect(result.wasConverted, isFalse);
      });
    });

    group('getStandardUnit', () {
      test('条状蔬菜返回"根"', () {
        expect(UnitConverter.getStandardUnit('黄瓜'), equals('根'));
        expect(UnitConverter.getStandardUnit('胡萝卜'), equals('根'));
        expect(UnitConverter.getStandardUnit('茄子'), equals('根'));
        expect(UnitConverter.getStandardUnit('玉米'), equals('根'));
      });

      test('叶菜返回"把"', () {
        expect(UnitConverter.getStandardUnit('香菜'), equals('把'));
        expect(UnitConverter.getStandardUnit('韭菜'), equals('把'));
        expect(UnitConverter.getStandardUnit('小葱'), equals('把'));
      });

      test('圆形蔬果返回"个"', () {
        expect(UnitConverter.getStandardUnit('土豆'), equals('个'));
        expect(UnitConverter.getStandardUnit('洋葱'), equals('个'));
        expect(UnitConverter.getStandardUnit('番茄'), equals('个'));
        expect(UnitConverter.getStandardUnit('鸡蛋'), equals('个'));
      });

      test('未定义的食材返回null', () {
        expect(UnitConverter.getStandardUnit('未知食材'), isNull);
      });
    });

    group('canMerge', () {
      test('名称相同且单位相同可以合并', () {
        expect(
          UnitConverter.canMerge(
            name1: '黄瓜',
            unit1: '根',
            name2: '黄瓜',
            unit2: '根',
          ),
          isTrue,
        );
      });

      test('名称相同且单位等价可以合并', () {
        expect(
          UnitConverter.canMerge(
            name1: '黄瓜',
            unit1: '根',
            name2: '黄瓜',
            unit2: '个',
          ),
          isTrue,
        );
      });

      test('名称不同不能合并', () {
        expect(
          UnitConverter.canMerge(
            name1: '黄瓜',
            unit1: '根',
            name2: '胡萝卜',
            unit2: '根',
          ),
          isFalse,
        );
      });

      test('名称相同但单位不等价不能合并', () {
        expect(
          UnitConverter.canMerge(
            name1: '黄瓜',
            unit1: '根',
            name2: '黄瓜',
            unit2: '克',
          ),
          isFalse,
        );
      });
    });

    group('mergeQuantities', () {
      test('相同单位直接相加', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 2,
          unit1: '根',
          quantity2: 3,
          unit2: '根',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(5));
        expect(result.unit, equals('根'));
      });

      test('等价计数单位合并（根+个）', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 2,
          unit1: '根',
          quantity2: 3,
          unit2: '个',
          ingredientName: '黄瓜',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(5));
        expect(result.unit, equals('根'));
      });

      test('重量单位合并（克+斤）', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 500,
          unit1: '克',
          quantity2: 1,
          unit2: '斤',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(1000)); // 500g + 500g = 1000g
        expect(result.unit, equals('克'));
      });

      test('重量单位合并（斤+两）', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 1,
          unit1: '斤',
          quantity2: 5,
          unit2: '两',
        );
        expect(result, isNotNull);
        // 1斤 = 500g, 5两 = 250g -> 转为斤: 750g / 500 = 1.5斤
        expect(result!.quantity, equals(1.5));
        expect(result.unit, equals('斤'));
      });

      test('体积单位合并（毫升+杯）', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 500,
          unit1: '毫升',
          quantity2: 2,
          unit2: '杯',
        );
        expect(result, isNotNull);
        expect(result!.quantity, equals(1000)); // 500ml + 500ml = 1000ml
        expect(result.unit, equals('毫升'));
      });

      test('不同组单位无法合并', () {
        final result = UnitConverter.mergeQuantities(
          quantity1: 100,
          unit1: '克',
          quantity2: 2,
          unit2: '个',
        );
        expect(result, isNull);
      });
    });

    group('formatQuantity', () {
      test('整数不显示小数点', () {
        expect(UnitConverter.formatQuantity(3, '个'), equals('3个'));
        expect(UnitConverter.formatQuantity(100, '克'), equals('100克'));
        expect(UnitConverter.formatQuantity(2.0, '根'), equals('2根'));
      });

      test('小数保留一位', () {
        expect(UnitConverter.formatQuantity(1.5, '斤'), equals('1.5斤'));
        expect(UnitConverter.formatQuantity(2.33, '克'), equals('2.3克'));
      });
    });

    group('getAllUnits', () {
      test('返回所有支持的单位', () {
        final units = UnitConverter.getAllUnits();
        expect(units, contains('克'));
        expect(units, contains('千克'));
        expect(units, contains('斤'));
        expect(units, contains('个'));
        expect(units, contains('根'));
        expect(units, contains('毫升'));
        expect(units, contains('升'));
        expect(units, contains('勺'));
      });
    });

    group('getEquivalenceGroup', () {
      test('返回正确的等价组', () {
        final weightGroup = UnitConverter.getEquivalenceGroup('克');
        expect(weightGroup, isNotNull);
        expect(weightGroup!.name, equals('weight'));
        expect(weightGroup.standardUnit, equals('克'));

        final volumeGroup = UnitConverter.getEquivalenceGroup('毫升');
        expect(volumeGroup, isNotNull);
        expect(volumeGroup!.name, equals('volume'));
      });

      test('未知单位返回null', () {
        expect(UnitConverter.getEquivalenceGroup('未知'), isNull);
      });
    });
  });

  group('实际使用场景测试', () {
    test('场景1: 黄瓜 1根 + 黄瓜 1个 = 黄瓜 2根', () {
      // 模拟购物清单入库场景
      const existingQuantity = 1.0;
      const existingUnit = '根';
      const newQuantity = 1.0;
      const newUnit = '个';
      const ingredientName = '黄瓜';

      // 检查是否可以合并
      expect(
        UnitConverter.canMerge(
          name1: ingredientName,
          unit1: existingUnit,
          name2: ingredientName,
          unit2: newUnit,
        ),
        isTrue,
      );

      // 执行合并
      final result = UnitConverter.mergeQuantities(
        quantity1: existingQuantity,
        unit1: existingUnit,
        quantity2: newQuantity,
        unit2: newUnit,
        ingredientName: ingredientName,
      );

      expect(result, isNotNull);
      expect(result!.quantity, equals(2));
      expect(result.unit, equals('根'));
    });

    test('场景2: 鸡蛋 6个 + 鸡蛋 1打(12个) = 鸡蛋 18个', () {
      // 注意：当前系统不支持"打"作为单位，此测试验证同单位合并
      const existingQuantity = 6.0;
      const existingUnit = '个';
      const newQuantity = 12.0;
      const newUnit = '个';

      final result = UnitConverter.mergeQuantities(
        quantity1: existingQuantity,
        unit1: existingUnit,
        quantity2: newQuantity,
        unit2: newUnit,
      );

      expect(result!.quantity, equals(18));
      expect(result.unit, equals('个'));
    });

    test('场景3: 猪肉 500克 + 猪肉 1斤 = 猪肉 1000克', () {
      final result = UnitConverter.mergeQuantities(
        quantity1: 500,
        unit1: '克',
        quantity2: 1,
        unit2: '斤',
        ingredientName: '猪肉',
      );

      expect(result!.quantity, equals(1000));
      expect(result.unit, equals('克'));
    });

    test('场景4: 牛奶 500毫升 + 牛奶 1升 = 牛奶 1500毫升', () {
      final result = UnitConverter.mergeQuantities(
        quantity1: 500,
        unit1: '毫升',
        quantity2: 1,
        unit2: '升',
        ingredientName: '牛奶',
      );

      expect(result!.quantity, equals(1500));
      expect(result.unit, equals('毫升'));
    });

    test('场景5: 酱油 2勺 + 酱油 1汤匙 = 酱油 3勺', () {
      final result = UnitConverter.mergeQuantities(
        quantity1: 2,
        unit1: '勺',
        quantity2: 1,
        unit2: '汤匙',
        ingredientName: '酱油',
      );

      expect(result!.quantity, equals(3));
      expect(result.unit, equals('勺'));
    });

    test('场景6: 无法合并不同类型单位 - 黄瓜 1根 + 黄瓜 100克', () {
      final result = UnitConverter.mergeQuantities(
        quantity1: 1,
        unit1: '根',
        quantity2: 100,
        unit2: '克',
        ingredientName: '黄瓜',
      );

      expect(result, isNull);
    });
  });
}
