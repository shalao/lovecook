// 纯 Dart 测试文件 - 不依赖 Flutter，用于验证核心逻辑
// 可以使用 `dart test test/core/services/ai_service_pure_dart_test.dart` 运行

import 'dart:convert';

import 'package:test/test.dart';

void main() {
  group('AIConfig', () {
    test('should create with default values', () {
      final config = _AIConfig(apiKey: 'test-key');

      expect(config.apiKey, 'test-key');
      expect(config.baseUrl, 'https://api.openai.com/v1');
      expect(config.model, 'gpt-4o');
      expect(config.visionModel, 'gpt-4o');
    });

    test('should create with custom values', () {
      final config = _AIConfig(
        apiKey: 'custom-key',
        baseUrl: 'https://custom.api.com',
        model: 'gpt-3.5-turbo',
        visionModel: 'gpt-4-vision',
      );

      expect(config.apiKey, 'custom-key');
      expect(config.baseUrl, 'https://custom.api.com');
      expect(config.model, 'gpt-3.5-turbo');
      expect(config.visionModel, 'gpt-4-vision');
    });

    test('isConfigured should return true when apiKey is not empty', () {
      final config = _AIConfig(apiKey: 'test-key');
      expect(config.isConfigured, true);
    });

    test('isConfigured should return false when apiKey is empty', () {
      final config = _AIConfig(apiKey: '');
      expect(config.isConfigured, false);
    });

    test('copyWith should create new instance with updated values', () {
      final original = _AIConfig(apiKey: 'original-key');
      final updated = original.copyWith(apiKey: 'new-key');

      expect(updated.apiKey, 'new-key');
      expect(updated.baseUrl, original.baseUrl);
      expect(updated.model, original.model);
    });

    test('copyWith should keep original values when not specified', () {
      final original = _AIConfig(
        apiKey: 'key',
        baseUrl: 'https://custom.api.com',
        model: 'custom-model',
      );
      final updated = original.copyWith(apiKey: 'new-key');

      expect(updated.apiKey, 'new-key');
      expect(updated.baseUrl, 'https://custom.api.com');
      expect(updated.model, 'custom-model');
    });
  });

  group('AIServiceException', () {
    test('should store message correctly', () {
      final exception = _AIServiceException('Test error message');
      expect(exception.message, 'Test error message');
    });

    test('toString should return message', () {
      final exception = _AIServiceException('Error occurred');
      expect(exception.toString(), 'Error occurred');
    });

    test('should handle Chinese message', () {
      final exception = _AIServiceException('API 密钥未配置');
      expect(exception.toString(), 'API 密钥未配置');
    });
  });

  group('IngredientRecognition', () {
    test('should create from JSON with all fields', () {
      final json = {
        'name': '胡萝卜',
        'quantity': 3,
        'unit': '根',
        'freshness': 'fresh',
        'category': '蔬菜',
        'storageAdvice': '冷藏保存，可存放1-2周',
      };

      final result = _IngredientRecognition.fromJson(json);

      expect(result.name, '胡萝卜');
      expect(result.quantity, 3.0);
      expect(result.unit, '根');
      expect(result.freshness, 'fresh');
      expect(result.category, '蔬菜');
      expect(result.storageAdvice, '冷藏保存，可存放1-2周');
    });

    test('should create from JSON with required fields only', () {
      final json = {
        'name': '鸡蛋',
        'quantity': 10,
        'unit': '个',
      };

      final result = _IngredientRecognition.fromJson(json);

      expect(result.name, '鸡蛋');
      expect(result.quantity, 10.0);
      expect(result.unit, '个');
      expect(result.freshness, isNull);
      expect(result.category, isNull);
      expect(result.storageAdvice, isNull);
    });

    test('should handle double quantity', () {
      final json = {
        'name': '牛奶',
        'quantity': 1.5,
        'unit': '升',
      };

      final result = _IngredientRecognition.fromJson(json);
      expect(result.quantity, 1.5);
    });

    test('should create via constructor', () {
      final recognition = _IngredientRecognition(
        name: '番茄',
        quantity: 5,
        unit: '个',
        freshness: 'normal',
        category: '蔬菜',
      );

      expect(recognition.name, '番茄');
      expect(recognition.quantity, 5);
    });
  });

  group('MenuPlanResult', () {
    test('should create from complete JSON', () {
      final json = {
        'days': [
          {
            'date': '第1天',
            'meals': [
              {
                'type': '早餐',
                'recipes': [
                  {
                    'name': '小米粥',
                    'description': '营养早餐',
                    'prepTime': 5,
                    'cookTime': 30,
                    'ingredients': [
                      {'name': '小米', 'quantity': 100, 'unit': '克'}
                    ],
                    'steps': ['洗米', '煮粥'],
                    'tips': '小火慢煮',
                    'tags': ['早餐'],
                    'nutrition': {
                      'calories': 150,
                      'protein': 5,
                      'carbs': 30,
                      'fat': 2
                    }
                  }
                ]
              }
            ]
          }
        ],
        'shoppingList': [
          {'name': '小米', 'quantity': 500, 'unit': '克', 'category': '主食'}
        ],
        'nutritionSummary': '营养均衡'
      };

      final result = _MenuPlanResult.fromJson(json);

      expect(result.days.length, 1);
      expect(result.days[0].date, '第1天');
      expect(result.days[0].meals.length, 1);
      expect(result.days[0].meals[0].type, '早餐');
      expect(result.days[0].meals[0].recipes.length, 1);
      expect(result.shoppingList.length, 1);
      expect(result.shoppingList[0].name, '小米');
      expect(result.nutritionSummary, '营养均衡');
    });

    test('should handle empty shopping list', () {
      final json = {
        'days': [
          {'date': '第1天', 'meals': []}
        ],
      };

      final result = _MenuPlanResult.fromJson(json);
      expect(result.shoppingList, isEmpty);
      expect(result.nutritionSummary, isNull);
    });

    test('should handle multiple days', () {
      final json = {
        'days': [
          {'date': '第1天', 'meals': []},
          {'date': '第2天', 'meals': []},
          {'date': '第3天', 'meals': []},
        ],
        'shoppingList': [],
      };

      final result = _MenuPlanResult.fromJson(json);
      expect(result.days.length, 3);
      expect(result.days[1].date, '第2天');
    });
  });

  group('DayPlanData', () {
    test('should create from JSON', () {
      final json = {
        'date': '第1天',
        'meals': [
          {'type': '早餐', 'recipes': []},
          {'type': '午餐', 'recipes': []},
        ]
      };

      final result = _DayPlanData.fromJson(json);

      expect(result.date, '第1天');
      expect(result.meals.length, 2);
    });
  });

  group('MealData', () {
    test('should create from JSON', () {
      final json = {
        'type': '晚餐',
        'recipes': [
          {'name': '红烧肉', 'description': '下饭菜'},
          {'name': '清炒时蔬', 'description': '健康蔬菜'},
        ]
      };

      final result = _MealData.fromJson(json);

      expect(result.type, '晚餐');
      expect(result.recipes.length, 2);
      expect(result.recipes[0]['name'], '红烧肉');
    });
  });

  group('ShoppingItemData', () {
    test('should create from JSON with all fields', () {
      final json = {
        'name': '猪肉',
        'quantity': 500,
        'unit': '克',
        'category': '肉类',
        'notes': '五花肉',
      };

      final result = _ShoppingItemData.fromJson(json);

      expect(result.name, '猪肉');
      expect(result.quantity, 500.0);
      expect(result.unit, '克');
      expect(result.category, '肉类');
      expect(result.notes, '五花肉');
    });

    test('should create from JSON with required fields only', () {
      final json = {
        'name': '葱',
        'quantity': 2,
        'unit': '根',
      };

      final result = _ShoppingItemData.fromJson(json);

      expect(result.name, '葱');
      expect(result.quantity, 2.0);
      expect(result.unit, '根');
      expect(result.category, isNull);
      expect(result.notes, isNull);
    });
  });

  group('MoodChatResponse', () {
    test('should create with reply only', () {
      final response = _MoodChatResponse(reply: '你好！今天想吃什么呢？');

      expect(response.reply, '你好！今天想吃什么呢？');
      expect(response.extractedPreference, isNull);
      expect(response.suggestedDishes, isNull);
    });

    test('should create with all fields', () {
      final response = _MoodChatResponse(
        reply: '好的，给你推荐几道菜',
        extractedPreference: '清淡口味，想吃蔬菜',
        suggestedDishes: ['清炒西兰花', '蒜蓉菠菜', '白灼芥兰'],
      );

      expect(response.reply, '好的，给你推荐几道菜');
      expect(response.extractedPreference, '清淡口味，想吃蔬菜');
      expect(response.suggestedDishes, hasLength(3));
      expect(response.suggestedDishes, contains('清炒西兰花'));
    });
  });

  group('JSON extraction', () {
    test('should extract JSON from plain text', () {
      const text = '[{"name":"test"}]';
      final result = _extractJson(text);
      expect(result, '[{"name":"test"}]');
    });

    test('should extract JSON from markdown code block', () {
      const text = '```json\n[{"name":"test"}]\n```';
      final result = _extractJson(text);
      expect(result, '[{"name":"test"}]');
    });

    test('should extract JSON from plain code block', () {
      const text = '```\n{"key":"value"}\n```';
      final result = _extractJson(text);
      expect(result, '{"key":"value"}');
    });

    test('should extract JSON object', () {
      const text = 'Here is the result: {"name":"test","value":123}';
      final result = _extractJson(text);
      expect(result, '{"name":"test","value":123}');
    });

    test('should extract JSON array', () {
      const text = 'Results: [{"a":1},{"b":2}]';
      final result = _extractJson(text);
      expect(result, '[{"a":1},{"b":2}]');
    });

    test('should handle nested JSON', () {
      const text = '{"outer":{"inner":"value"}}';
      final result = _extractJson(text);
      expect(result, '{"outer":{"inner":"value"}}');
    });

    test('should handle complex multiline JSON', () {
      const text = '''
Here is the menu:
```json
{
  "days": [
    {"date": "第1天", "meals": []}
  ]
}
```
''';
      final result = _extractJson(text);
      final parsed = json.decode(result);
      expect(parsed['days'], isNotEmpty);
    });
  });

  group('NutritionInfoModel', () {
    test('should create from JSON', () {
      final json = {
        'calories': 200.5,
        'protein': 15.0,
        'carbs': 25.0,
        'fat': 8.0,
        'fiber': 3.0,
        'summary': '营养均衡',
      };

      final result = _NutritionInfoModel.fromJson(json);

      expect(result.calories, 200.5);
      expect(result.protein, 15.0);
      expect(result.carbs, 25.0);
      expect(result.fat, 8.0);
      expect(result.fiber, 3.0);
      expect(result.summary, '营养均衡');
    });

    test('should handle null values', () {
      final json = {'calories': 200};

      final result = _NutritionInfoModel.fromJson(json);

      expect(result.calories, 200.0);
      expect(result.protein, isNull);
      expect(result.carbs, isNull);
    });

    test('should format nutrition info', () {
      final nutrition = _NutritionInfoModel(
        calories: 200,
        protein: 15,
        carbs: 25,
        fat: 8,
      );

      final formatted = nutrition.formatted;
      expect(formatted, contains('热量: 200千卡'));
      expect(formatted, contains('蛋白质: 15.0g'));
    });
  });

  group('Recipe parsing', () {
    test('should parse recipe from JSON', () {
      final json = {
        'name': '番茄炒蛋',
        'description': '家常菜',
        'prepTime': 5,
        'cookTime': 10,
        'servings': 2,
        'ingredients': [
          {'name': '番茄', 'quantity': 2, 'unit': '个', 'isOptional': false},
          {
            'name': '鸡蛋',
            'quantity': 3,
            'unit': '个',
            'isOptional': false,
            'substitute': '鸭蛋'
          },
        ],
        'steps': ['切番茄', '炒鸡蛋', '混合翻炒'],
        'tips': '鸡蛋要嫩',
        'tags': ['家常菜', '快手菜'],
        'difficulty': 'easy',
        'nutrition': {'calories': 180, 'protein': 12, 'carbs': 10, 'fat': 10}
      };

      final recipe = _parseRecipe(json);

      expect(recipe.name, '番茄炒蛋');
      expect(recipe.description, '家常菜');
      expect(recipe.prepTime, 5);
      expect(recipe.cookTime, 10);
      expect(recipe.totalTime, 15);
      expect(recipe.servings, 2);
      expect(recipe.ingredients.length, 2);
      expect(recipe.ingredients[0].name, '番茄');
      expect(recipe.ingredients[1].substitute, '鸭蛋');
      expect(recipe.steps.length, 3);
      expect(recipe.tips, '鸡蛋要嫩');
      expect(recipe.tags, contains('家常菜'));
      expect(recipe.difficulty, 'easy');
      expect(recipe.nutrition?.calories, 180);
    });

    test('should handle recipe with minimal fields', () {
      final json = {
        'name': '简单菜',
        'ingredients': [],
        'steps': [],
      };

      final recipe = _parseRecipe(json);

      expect(recipe.name, '简单菜');
      expect(recipe.description, isNull);
      expect(recipe.prepTime, 0);
      expect(recipe.cookTime, 0);
      expect(recipe.servings, 2);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.steps, isEmpty);
    });
  });

  group('Family info building', () {
    test('should build family info string', () {
      final family = _FamilyModel(
        name: '测试家庭',
        members: [
          _FamilyMemberModel(
            name: '张三',
            ageGroup: '成人',
            healthConditions: ['控糖', '高血压'],
            allergies: ['花生'],
            dislikes: ['香菜'],
          ),
          _FamilyMemberModel(
            name: '小明',
            ageGroup: '儿童',
            healthConditions: [],
            allergies: [],
            dislikes: [],
          ),
        ],
      );

      final info = _buildFamilyInfo(family);

      expect(info, contains('测试家庭'));
      expect(info, contains('张三'));
      expect(info, contains('成人'));
      expect(info, contains('控糖'));
      expect(info, contains('高血压'));
      expect(info, contains('花生'));
      expect(info, contains('香菜'));
      expect(info, contains('小明'));
      expect(info, contains('儿童'));
    });
  });

  group('Inventory info building', () {
    test('should build inventory info string', () {
      final inventory = [
        _IngredientModel(name: '胡萝卜', category: '蔬菜', quantity: 3, unit: '根'),
        _IngredientModel(name: '鸡蛋', category: '蛋奶', quantity: 6, unit: '个'),
        _IngredientModel(name: '牛奶', category: '蛋奶', quantity: 1, unit: '盒'),
      ];

      final info = _buildInventoryInfo(inventory);

      expect(info, contains('蔬菜'));
      expect(info, contains('胡萝卜'));
      expect(info, contains('3.0根'));
      expect(info, contains('蛋奶'));
      expect(info, contains('鸡蛋'));
      expect(info, contains('牛奶'));
    });

    test('should handle empty inventory', () {
      final info = _buildInventoryInfo([]);
      expect(info, '暂无库存食材');
    });

    test('should group ingredients by category', () {
      final inventory = [
        _IngredientModel(name: '胡萝卜', category: '蔬菜', quantity: 3, unit: '根'),
        _IngredientModel(name: '土豆', category: '蔬菜', quantity: 2, unit: '个'),
        _IngredientModel(name: '鸡蛋', category: '蛋奶', quantity: 6, unit: '个'),
      ];

      final info = _buildInventoryInfo(inventory);

      // 验证蔬菜分组
      expect(info, contains('【蔬菜】'));
      expect(info, contains('胡萝卜'));
      expect(info, contains('土豆'));

      // 验证蛋奶分组
      expect(info, contains('【蛋奶】'));
      expect(info, contains('鸡蛋'));
    });
  });

  group('Preference info building', () {
    test('should build preference info with all fields', () {
      final info = _buildPreferenceInfo(
        recentRecipeNames: ['红烧肉', '番茄炒蛋'],
        likedRecipes: ['宫保鸡丁', '麻婆豆腐'],
        dislikedRecipes: ['苦瓜炒蛋'],
        favoriteRecipes: ['鱼香肉丝'],
      );

      expect(info, contains('近期吃过'));
      expect(info, contains('红烧肉'));
      expect(info, contains('喜欢'));
      expect(info, contains('宫保鸡丁'));
      expect(info, contains('不喜欢'));
      expect(info, contains('苦瓜炒蛋'));
      expect(info, contains('收藏'));
      expect(info, contains('鱼香肉丝'));
    });

    test('should handle empty preferences', () {
      final info = _buildPreferenceInfo();
      expect(info, isEmpty);
    });

    test('should limit recipes to 10', () {
      final longList = List.generate(15, (i) => '菜品$i');
      final info = _buildPreferenceInfo(likedRecipes: longList);

      // 应该只包含前10个
      expect(info, contains('菜品0'));
      expect(info, contains('菜品9'));
      expect(info, isNot(contains('菜品10')));
    });
  });
}

// ===== 测试用的简化模型类 =====

class _AIConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String visionModel;

  _AIConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    this.visionModel = 'gpt-4o',
  });

  bool get isConfigured => apiKey.isNotEmpty;

  _AIConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? visionModel,
  }) {
    return _AIConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      visionModel: visionModel ?? this.visionModel,
    );
  }
}

class _AIServiceException implements Exception {
  final String message;
  _AIServiceException(this.message);

  @override
  String toString() => message;
}

class _IngredientRecognition {
  final String name;
  final double quantity;
  final String unit;
  final String? freshness;
  final String? category;
  final String? storageAdvice;

  _IngredientRecognition({
    required this.name,
    required this.quantity,
    required this.unit,
    this.freshness,
    this.category,
    this.storageAdvice,
  });

  factory _IngredientRecognition.fromJson(Map<String, dynamic> json) {
    return _IngredientRecognition(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      freshness: json['freshness'] as String?,
      category: json['category'] as String?,
      storageAdvice: json['storageAdvice'] as String?,
    );
  }
}

class _MenuPlanResult {
  final List<_DayPlanData> days;
  final List<_ShoppingItemData> shoppingList;
  final String? nutritionSummary;

  _MenuPlanResult({
    required this.days,
    required this.shoppingList,
    this.nutritionSummary,
  });

  factory _MenuPlanResult.fromJson(Map<String, dynamic> json) {
    return _MenuPlanResult(
      days:
          (json['days'] as List).map((d) => _DayPlanData.fromJson(d)).toList(),
      shoppingList: (json['shoppingList'] as List?)
              ?.map((s) => _ShoppingItemData.fromJson(s))
              .toList() ??
          [],
      nutritionSummary: json['nutritionSummary'] as String?,
    );
  }
}

class _DayPlanData {
  final String date;
  final List<_MealData> meals;

  _DayPlanData({required this.date, required this.meals});

  factory _DayPlanData.fromJson(Map<String, dynamic> json) {
    return _DayPlanData(
      date: json['date'] as String,
      meals:
          (json['meals'] as List).map((m) => _MealData.fromJson(m)).toList(),
    );
  }
}

class _MealData {
  final String type;
  final List<Map<String, dynamic>> recipes;

  _MealData({required this.type, required this.recipes});

  factory _MealData.fromJson(Map<String, dynamic> json) {
    return _MealData(
      type: json['type'] as String,
      recipes: (json['recipes'] as List).cast<Map<String, dynamic>>(),
    );
  }
}

class _ShoppingItemData {
  final String name;
  final double quantity;
  final String unit;
  final String? category;
  final String? notes;

  _ShoppingItemData({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
    this.notes,
  });

  factory _ShoppingItemData.fromJson(Map<String, dynamic> json) {
    return _ShoppingItemData(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class _MoodChatResponse {
  final String reply;
  final String? extractedPreference;
  final List<String>? suggestedDishes;

  _MoodChatResponse({
    required this.reply,
    this.extractedPreference,
    this.suggestedDishes,
  });
}

class _NutritionInfoModel {
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String? summary;

  _NutritionInfoModel({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.summary,
  });

  factory _NutritionInfoModel.fromJson(Map<String, dynamic> json) {
    return _NutritionInfoModel(
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      summary: json['summary'] as String?,
    );
  }

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

class _RecipeIngredientModel {
  final String name;
  final double quantity;
  final String unit;
  final bool isOptional;
  final String? substitute;

  _RecipeIngredientModel({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
    this.substitute,
  });
}

class _RecipeModel {
  final String name;
  final String? description;
  final int prepTime;
  final int cookTime;
  final int servings;
  final List<_RecipeIngredientModel> ingredients;
  final List<String> steps;
  final String? tips;
  final List<String> tags;
  final String? difficulty;
  final _NutritionInfoModel? nutrition;

  _RecipeModel({
    required this.name,
    this.description,
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 2,
    this.ingredients = const [],
    this.steps = const [],
    this.tips,
    this.tags = const [],
    this.difficulty,
    this.nutrition,
  });

  int get totalTime => prepTime + cookTime;
}

class _FamilyMemberModel {
  final String name;
  final String? ageGroup;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> dislikes;

  _FamilyMemberModel({
    required this.name,
    this.ageGroup,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dislikes = const [],
  });
}

class _FamilyModel {
  final String name;
  final List<_FamilyMemberModel> members;

  _FamilyModel({
    required this.name,
    required this.members,
  });
}

class _IngredientModel {
  final String name;
  final String? category;
  final double quantity;
  final String unit;

  _IngredientModel({
    required this.name,
    this.category,
    required this.quantity,
    required this.unit,
  });

  double get remainingQuantity => quantity;
}

// ===== 辅助函数 =====

String _extractJson(String text) {
  var cleaned = text.trim();
  if (cleaned.startsWith('```json')) {
    cleaned = cleaned.substring(7);
  } else if (cleaned.startsWith('```')) {
    cleaned = cleaned.substring(3);
  }
  if (cleaned.endsWith('```')) {
    cleaned = cleaned.substring(0, cleaned.length - 3);
  }
  cleaned = cleaned.trim();

  final jsonMatch = RegExp(r'[\[\{].*[\]\}]', dotAll: true).firstMatch(cleaned);
  if (jsonMatch != null) {
    return jsonMatch.group(0)!;
  }
  return cleaned;
}

_RecipeModel _parseRecipe(Map<String, dynamic> data) {
  final ingredients = (data['ingredients'] as List?)
          ?.map((i) => _RecipeIngredientModel(
                name: i['name'] as String,
                quantity: (i['quantity'] as num).toDouble(),
                unit: i['unit'] as String,
                isOptional: i['isOptional'] as bool? ?? false,
                substitute: i['substitute'] as String?,
              ))
          .toList() ??
      [];

  final nutritionData = data['nutrition'] as Map<String, dynamic>?;
  final nutrition = nutritionData != null
      ? _NutritionInfoModel(
          calories: (nutritionData['calories'] as num?)?.toDouble(),
          protein: (nutritionData['protein'] as num?)?.toDouble(),
          carbs: (nutritionData['carbs'] as num?)?.toDouble(),
          fat: (nutritionData['fat'] as num?)?.toDouble(),
          fiber: (nutritionData['fiber'] as num?)?.toDouble(),
          summary: nutritionData['summary'] as String?,
        )
      : null;

  return _RecipeModel(
    name: data['name'] as String,
    description: data['description'] as String?,
    prepTime: data['prepTime'] as int? ?? 0,
    cookTime: data['cookTime'] as int? ?? 0,
    servings: data['servings'] as int? ?? 2,
    ingredients: ingredients,
    steps: (data['steps'] as List?)?.cast<String>() ?? [],
    tips: data['tips'] as String?,
    tags: (data['tags'] as List?)?.cast<String>() ?? [],
    difficulty: data['difficulty'] as String?,
    nutrition: nutrition,
  );
}

String _buildFamilyInfo(_FamilyModel family) {
  final buffer = StringBuffer();
  buffer.writeln('家庭名称：${family.name}');
  buffer.writeln('成员（${family.members.length}人）：');
  for (final member in family.members) {
    buffer.write('- ${member.name}');
    if (member.ageGroup != null) buffer.write('（${member.ageGroup}）');
    if (member.healthConditions.isNotEmpty) {
      buffer.write('，健康关注：${member.healthConditions.join("、")}');
    }
    if (member.allergies.isNotEmpty) {
      buffer.write('，过敏：${member.allergies.join("、")}');
    }
    if (member.dislikes.isNotEmpty) {
      buffer.write('，忌口：${member.dislikes.join("、")}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _buildInventoryInfo(List<_IngredientModel> inventory) {
  if (inventory.isEmpty) return '暂无库存食材';

  final grouped = <String, List<_IngredientModel>>{};
  for (final item in inventory) {
    final category = item.category ?? '其他';
    grouped.putIfAbsent(category, () => []).add(item);
  }

  final buffer = StringBuffer();
  for (final category in grouped.keys) {
    buffer.writeln('【$category】');
    for (final item in grouped[category]!) {
      buffer.writeln('- ${item.name}：${item.remainingQuantity}${item.unit}');
    }
  }
  return buffer.toString();
}

String _buildPreferenceInfo({
  List<String>? recentRecipeNames,
  List<String>? likedRecipes,
  List<String>? dislikedRecipes,
  List<String>? favoriteRecipes,
}) {
  final buffer = StringBuffer();

  if (recentRecipeNames != null && recentRecipeNames.isNotEmpty) {
    buffer.writeln('\n【请避免推荐以下近期吃过的菜品】');
    buffer.writeln(recentRecipeNames.join('、'));
  }

  if (likedRecipes != null && likedRecipes.isNotEmpty) {
    buffer.writeln('\n【用户喜欢的菜品（可参考类似风格）】');
    buffer.writeln(likedRecipes.take(10).join('、'));
  }

  if (dislikedRecipes != null && dislikedRecipes.isNotEmpty) {
    buffer.writeln('\n【用户不喜欢的菜品（请避免）】');
    buffer.writeln(dislikedRecipes.take(10).join('、'));
  }

  if (favoriteRecipes != null && favoriteRecipes.isNotEmpty) {
    buffer.writeln('\n【用户收藏的菜谱（可优先考虑）】');
    buffer.writeln(favoriteRecipes.take(10).join('、'));
  }

  return buffer.toString();
}
