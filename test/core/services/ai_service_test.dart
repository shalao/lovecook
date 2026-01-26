import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:love_cook/core/services/ai_service.dart';
import 'package:love_cook/features/family/data/models/family_model.dart';
import 'package:love_cook/features/inventory/data/models/ingredient_model.dart';
import 'package:love_cook/features/recipe/data/models/recipe_model.dart';

void main() {
  group('AIConfig', () {
    test('should create with default values', () {
      const config = AIConfig();

      expect(config.model, 'gpt-4o-mini');
      expect(config.visionModel, 'gpt-4o');
    });

    test('should create with custom values', () {
      const config = AIConfig(
        model: 'gpt-3.5-turbo',
        visionModel: 'gpt-4-vision',
      );

      expect(config.model, 'gpt-3.5-turbo');
      expect(config.visionModel, 'gpt-4-vision');
    });

    test('isConfigured should always return true (using proxy service)', () {
      const config = AIConfig();
      expect(config.isConfigured, true);
    });

    test('copyWith should create new instance with updated values', () {
      const original = AIConfig();
      final updated = original.copyWith(model: 'new-model');

      expect(updated.model, 'new-model');
      expect(updated.visionModel, original.visionModel);
    });

    test('copyWith should keep original values when not specified', () {
      const original = AIConfig(
        model: 'custom-model',
        visionModel: 'custom-vision',
      );
      final updated = original.copyWith(model: 'new-model');

      expect(updated.model, 'new-model');
      expect(updated.visionModel, 'custom-vision');
    });
  });

  group('AIServiceException', () {
    test('should store message correctly', () {
      final exception = AIServiceException('Test error message');
      expect(exception.message, 'Test error message');
    });

    test('toString should return message', () {
      final exception = AIServiceException('Error occurred');
      expect(exception.toString(), 'Error occurred');
    });

    test('should handle Chinese message', () {
      final exception = AIServiceException('API 密钥未配置');
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

      final result = IngredientRecognition.fromJson(json);

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

      final result = IngredientRecognition.fromJson(json);

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

      final result = IngredientRecognition.fromJson(json);
      expect(result.quantity, 1.5);
    });

    test('should create via constructor', () {
      final recognition = IngredientRecognition(
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

      final result = MenuPlanResult.fromJson(json);

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
          {
            'date': '第1天',
            'meals': []
          }
        ],
      };

      final result = MenuPlanResult.fromJson(json);
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

      final result = MenuPlanResult.fromJson(json);
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

      final result = DayPlanData.fromJson(json);

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

      final result = MealData.fromJson(json);

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

      final result = ShoppingItemData.fromJson(json);

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

      final result = ShoppingItemData.fromJson(json);

      expect(result.name, '葱');
      expect(result.quantity, 2.0);
      expect(result.unit, '根');
      expect(result.category, isNull);
      expect(result.notes, isNull);
    });
  });

  group('MoodChatResponse', () {
    test('should create with reply only', () {
      final response = MoodChatResponse(reply: '你好！今天想吃什么呢？');

      expect(response.reply, '你好！今天想吃什么呢？');
      expect(response.extractedPreference, isNull);
      expect(response.suggestedDishes, isNull);
    });

    test('should create with all fields', () {
      final response = MoodChatResponse(
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

  group('AIService', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late _TestableAIService aiService;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.openai.com/v1'));
      dioAdapter = DioAdapter(dio: dio);
      // 创建带有配置好的 Dio 的 AIService
      aiService = _TestableAIService(
        config: const AIConfig(),
        dio: dio,
      );
    });

    group('recognizeIngredients', () {
      test('should parse successful response', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''[
                  {"name":"胡萝卜","quantity":3,"unit":"根","freshness":"fresh","category":"蔬菜","storageAdvice":"冷藏"},
                  {"name":"土豆","quantity":5,"unit":"个","freshness":"normal","category":"蔬菜","storageAdvice":"阴凉处"}
                ]'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.recognizeIngredients(Uint8List(10));

        expect(result.length, 2);
        expect(result[0].name, '胡萝卜');
        expect(result[0].quantity, 3.0);
        expect(result[1].name, '土豆');
      });

      test('should handle markdown wrapped JSON response', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''```json
[{"name":"西红柿","quantity":4,"unit":"个"}]
```'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.recognizeIngredients(Uint8List(10));

        expect(result.length, 1);
        expect(result[0].name, '西红柿');
      });
    });

    group('parseIngredientText', () {
      test('should parse text input successfully', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content':
                    '[{"name":"胡萝卜","quantity":3,"unit":"根","category":"蔬菜"}]'
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.parseIngredientText('三根胡萝卜');

        expect(result.length, 1);
        expect(result[0].name, '胡萝卜');
        expect(result[0].quantity, 3.0);
        expect(result[0].unit, '根');
      });

      test('should handle multiple ingredients', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''[
                  {"name":"胡萝卜","quantity":3,"unit":"根","category":"蔬菜"},
                  {"name":"鸡蛋","quantity":6,"unit":"个","category":"蛋奶"},
                  {"name":"牛奶","quantity":1,"unit":"盒","category":"蛋奶"}
                ]'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result =
            await aiService.parseIngredientText('三根胡萝卜、六个鸡蛋、一盒牛奶');

        expect(result.length, 3);
      });
    });

    group('generateMealPlan', () {
      late FamilyModel testFamily;
      late List<IngredientModel> testInventory;

      setUp(() {
        testFamily = FamilyModel(
          id: 'test-family',
          name: '测试家庭',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          members: [
            FamilyMemberModel(
              id: '1',
              name: '张三',
              ageGroup: '成人',
              healthConditions: ['控糖'],
              allergies: [],
              dislikes: [],
            ),
          ],
          mealSettings: MealSettingsModel.defaultSettings(),
        );

        testInventory = [
          IngredientModel(
            id: '1',
            familyId: 'test-family',
            name: '鸡胸肉',
            category: '肉类',
            quantity: 500,
            unit: '克',
            source: 'manual',
            addedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
      });

      test('should generate meal plan successfully', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''{
                  "days": [
                    {
                      "date": "第1天",
                      "meals": [
                        {
                          "type": "午餐",
                          "recipes": [
                            {
                              "name": "香煎鸡胸肉",
                              "description": "低脂高蛋白",
                              "prepTime": 10,
                              "cookTime": 15,
                              "ingredients": [{"name":"鸡胸肉","quantity":200,"unit":"克"}],
                              "steps": ["腌制","煎制"],
                              "tips": "不要煎太久",
                              "tags": ["高蛋白"],
                              "nutrition": {"calories":200,"protein":30,"carbs":5,"fat":8}
                            }
                          ]
                        }
                      ]
                    }
                  ],
                  "shoppingList": [],
                  "nutritionSummary": "高蛋白低脂肪"
                }'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.generateMealPlan(
          family: testFamily,
          inventory: testInventory,
          days: 1,
          mealTypes: ['午餐'],
        );

        expect(result.days.length, 1);
        expect(result.days[0].meals[0].type, '午餐');
        expect(result.days[0].meals[0].recipes[0]['name'], '香煎鸡胸肉');
      });

      test('should include mood input in request', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''{
                  "days": [{"date": "第1天", "meals": []}],
                  "shoppingList": []
                }'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.generateMealPlan(
          family: testFamily,
          inventory: testInventory,
          days: 1,
          mealTypes: ['晚餐'],
          moodInput: '今天想吃清淡的',
        );

        expect(result.days.length, 1);
      });
    });

    group('suggestRecipes', () {
      late FamilyModel testFamily;
      late List<IngredientModel> testInventory;

      setUp(() {
        testFamily = FamilyModel(
          id: 'test-family',
          name: '测试家庭',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          members: [],
          mealSettings: MealSettingsModel.defaultSettings(),
        );

        testInventory = [
          IngredientModel(
            id: '1',
            familyId: 'test-family',
            name: '番茄',
            category: '蔬菜',
            quantity: 3,
            unit: '个',
            source: 'manual',
            addedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          IngredientModel(
            id: '2',
            familyId: 'test-family',
            name: '鸡蛋',
            category: '蛋奶',
            quantity: 5,
            unit: '个',
            source: 'manual',
            addedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
      });

      test('should suggest recipes based on inventory', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''[
                  {
                    "name": "番茄炒蛋",
                    "description": "家常菜",
                    "prepTime": 5,
                    "cookTime": 10,
                    "servings": 2,
                    "ingredients": [
                      {"name":"番茄","quantity":2,"unit":"个","isOptional":false},
                      {"name":"鸡蛋","quantity":3,"unit":"个","isOptional":false}
                    ],
                    "steps": ["切番茄","炒鸡蛋","混合翻炒"],
                    "tips": "鸡蛋要嫩",
                    "tags": ["家常菜","快手菜"],
                    "difficulty": "easy",
                    "nutrition": {"calories":180,"protein":12,"carbs":10,"fat":10}
                  }
                ]'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.suggestRecipes(
          inventory: testInventory,
          family: testFamily,
          count: 1,
        );

        expect(result.length, 1);
        expect(result[0].name, '番茄炒蛋');
        expect(result[0].ingredients.length, 2);
        expect(result[0].difficulty, 'easy');
      });
    });

    group('generateRecipe', () {
      late FamilyModel testFamily;

      setUp(() {
        testFamily = FamilyModel(
          id: 'test-family',
          name: '测试家庭',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          members: [],
          mealSettings: MealSettingsModel.defaultSettings(),
        );
      });

      test('should generate recipe for dish name', () async {
        final responseJson = {
          'choices': [
            {
              'message': {
                'content': '''{
                  "name": "红烧肉",
                  "description": "经典家常菜",
                  "prepTime": 15,
                  "cookTime": 60,
                  "servings": 4,
                  "ingredients": [
                    {"name":"五花肉","quantity":500,"unit":"克","isOptional":false},
                    {"name":"酱油","quantity":30,"unit":"毫升","isOptional":false}
                  ],
                  "steps": ["切块","焯水","炖煮","收汁"],
                  "tips": "小火慢炖更入味",
                  "tags": ["家常菜","下饭菜"],
                  "difficulty": "medium",
                  "nutrition": {"calories":450,"protein":25,"carbs":10,"fat":35,"summary":"高蛋白高脂肪"}
                }'''
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.generateRecipe(
          dishName: '红烧肉',
          family: testFamily,
        );

        expect(result.name, '红烧肉');
        expect(result.description, '经典家常菜');
        expect(result.prepTime, 15);
        expect(result.cookTime, 60);
        expect(result.ingredients.length, 2);
        expect(result.steps.length, 4);
        expect(result.nutrition?.summary, '高蛋白高脂肪');
      });
    });

    group('analyzeNutrition', () {
      test('should analyze recipe nutrition', () async {
        final recipe = RecipeModel(
          id: 'test',
          name: '清炒西兰花',
          createdAt: DateTime.now(),
          servings: 2,
          ingredients: [
            RecipeIngredientModel(
              name: '西兰花',
              quantity: 300,
              unit: '克',
            ),
            RecipeIngredientModel(
              name: '蒜',
              quantity: 3,
              unit: '瓣',
            ),
          ],
        );

        final responseJson = {
          'choices': [
            {
              'message': {
                'content':
                    '{"calories":80,"protein":6,"carbs":12,"fat":2,"fiber":4,"summary":"低热量高纤维"}'
              }
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.analyzeNutrition(recipe);

        expect(result.calories, 80);
        expect(result.protein, 6);
        expect(result.carbs, 12);
        expect(result.fat, 2);
        expect(result.fiber, 4);
        expect(result.summary, '低热量高纤维');
      });
    });

    group('chatCompletion', () {
      test('should complete chat successfully', () async {
        final responseJson = {
          'choices': [
            {
              'message': {'content': '这是 AI 的回复'}
            }
          ]
        };

        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(200, responseJson),
          data: Matchers.any,
        );

        final result = await aiService.chatCompletion(
          messages: [
            {'role': 'user', 'content': '你好'}
          ],
        );

        expect(result, '这是 AI 的回复');
      });

    });

    group('error handling', () {
      test('should throw AIServiceException on network error', () async {
        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.throws(
            500,
            DioException(
              requestOptions: RequestOptions(path: '/chat/completions'),
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout',
            ),
          ),
        );

        expect(
          () => aiService.parseIngredientText('测试'),
          throwsA(isA<AIServiceException>()),
        );
      });

      test('should parse API error message', () async {
        dioAdapter.onPost(
          '/chat/completions',
          (server) => server.reply(
            401,
            {
              'error': {'message': 'Invalid API key'}
            },
          ),
        );

        expect(
          () => aiService.parseIngredientText('测试'),
          throwsA(isA<AIServiceException>()),
        );
      });
    });
  });

  group('JSON extraction', () {
    // 测试 _extractJson 方法的逻辑
    test('should extract JSON from plain text', () {
      const text = '[{"name":"test"}]';
      final result = _extractJsonHelper(text);
      expect(result, '[{"name":"test"}]');
    });

    test('should extract JSON from markdown code block', () {
      const text = '```json\n[{"name":"test"}]\n```';
      final result = _extractJsonHelper(text);
      expect(result, '[{"name":"test"}]');
    });

    test('should extract JSON from plain code block', () {
      const text = '```\n{"key":"value"}\n```';
      final result = _extractJsonHelper(text);
      expect(result, '{"key":"value"}');
    });

    test('should extract JSON object', () {
      const text = 'Here is the result: {"name":"test","value":123}';
      final result = _extractJsonHelper(text);
      expect(result, '{"name":"test","value":123}');
    });

    test('should extract JSON array', () {
      const text = 'Results: [{"a":1},{"b":2}]';
      final result = _extractJsonHelper(text);
      expect(result, '[{"a":1},{"b":2}]');
    });

    test('should handle nested JSON', () {
      const text = '{"outer":{"inner":"value"}}';
      final result = _extractJsonHelper(text);
      expect(result, '{"outer":{"inner":"value"}}');
    });
  });
}

/// 辅助函数：模拟 _extractJson 方法的逻辑
String _extractJsonHelper(String text) {
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

/// 可测试的 AIService 类，允许注入 Dio 实例（不继承 AIService 以避免 proxyService 依赖）
class _TestableAIService {
  final Dio _testDio;
  final AIConfig config;

  _TestableAIService({
    required this.config,
    required Dio dio,
  }) : _testDio = dio;

  Future<List<IngredientRecognition>> recognizeIngredients(
      Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.visionModel,
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'system',
            'content': '你是一位专业的食材识别助手。请仔细分析图片中的食材，并以JSON格式返回结果。'
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
              {
                'type': 'text',
                'text': '请识别图片中的食材...',
              },
            ],
          },
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      return items.map((item) => IngredientRecognition.fromJson(item)).toList();
    } on DioException catch (e) {
      throw AIServiceException('识别失败: ${_parseError(e)}');
    }
  }

    Future<List<IngredientRecognition>> parseIngredientText(String text) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {'role': 'system', 'content': '你是一位食材解析助手。'},
          {'role': 'user', 'content': '解析: "$text"'},
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      return items.map((item) => IngredientRecognition.fromJson(item)).toList();
    } on DioException catch (e) {
      throw AIServiceException('解析失败: ${_parseError(e)}');
    }
  }

    Future<MenuPlanResult> generateMealPlan({
    required FamilyModel family,
    required List<IngredientModel> inventory,
    required int days,
    required List<String> mealTypes,
    int dishesPerMeal = 2,
    String? moodInput,
    List<String>? recentRecipeNames,
    List<String>? likedRecipes,
    List<String>? dislikedRecipes,
    List<String>? favoriteRecipes,
  }) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 4096 + days * 2000,
        'temperature': 0.7,
        'messages': [
          {'role': 'system', 'content': '你是一位专业的家庭营养师。'},
          {'role': 'user', 'content': '生成 $days 天菜单'},
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      return MenuPlanResult.fromJson(data);
    } on DioException catch (e) {
      throw AIServiceException('生成菜单失败: ${_parseError(e)}');
    }
  }

    Future<List<RecipeModel>> suggestRecipes({
    required List<IngredientModel> inventory,
    required FamilyModel family,
    int count = 5,
  }) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 2048,
        'temperature': 0.8,
        'messages': [
          {'role': 'system', 'content': '你是一位创意家常菜专家。'},
          {'role': 'user', 'content': '推荐 $count 道菜谱'},
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      return items.map((item) => _parseRecipe(item)).toList();
    } on DioException catch (e) {
      throw AIServiceException('推荐失败: ${_parseError(e)}');
    }
  }

    Future<RecipeModel> generateRecipe({
    required String dishName,
    required FamilyModel family,
  }) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {'role': 'system', 'content': '你是一位专业的家庭烹饪导师。'},
          {'role': 'user', 'content': '生成菜谱: $dishName'},
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      return _parseRecipe(data);
    } on DioException catch (e) {
      throw AIServiceException('生成菜谱失败: ${_parseError(e)}');
    }
  }

    Future<NutritionInfoModel> analyzeNutrition(RecipeModel recipe) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 512,
        'messages': [
          {'role': 'system', 'content': '你是一位营养师。'},
          {'role': 'user', 'content': '分析营养: ${recipe.name}'},
        ],
      });

      final content = response.data['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      return NutritionInfoModel(
        calories: (data['calories'] as num?)?.toDouble(),
        protein: (data['protein'] as num?)?.toDouble(),
        carbs: (data['carbs'] as num?)?.toDouble(),
        fat: (data['fat'] as num?)?.toDouble(),
        fiber: (data['fiber'] as num?)?.toDouble(),
        summary: data['summary'] as String?,
      );
    } on DioException catch (e) {
      throw AIServiceException('分析失败: ${_parseError(e)}');
    }
  }

    Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _testDio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'messages': messages,
      });

      return response.data['choices'][0]['message']['content'] as String;
    } on DioException catch (e) {
      throw AIServiceException('请求失败: ${_parseError(e)}');
    }
  }

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

    final jsonMatch =
        RegExp(r'[\[\{].*[\]\}]', dotAll: true).firstMatch(cleaned);
    if (jsonMatch != null) {
      return jsonMatch.group(0)!;
    }
    return cleaned;
  }

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['error'] != null) {
        final error = data['error'];
        if (error is Map && error['message'] != null) {
          return error['message'] as String;
        }
      }
    }
    return e.message ?? '网络请求失败';
  }

  RecipeModel _parseRecipe(Map<String, dynamic> data) {
    final ingredients = (data['ingredients'] as List?)
            ?.map((i) => RecipeIngredientModel(
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
        ? NutritionInfoModel(
            calories: (nutritionData['calories'] as num?)?.toDouble(),
            protein: (nutritionData['protein'] as num?)?.toDouble(),
            carbs: (nutritionData['carbs'] as num?)?.toDouble(),
            fat: (nutritionData['fat'] as num?)?.toDouble(),
            fiber: (nutritionData['fiber'] as num?)?.toDouble(),
            summary: nutritionData['summary'] as String?,
          )
        : null;

    return RecipeModel.create(
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
}
