import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/family/data/models/family_model.dart';
import '../../features/inventory/data/models/ingredient_model.dart';
import '../../features/recipe/data/models/recipe_model.dart';
import 'storage_service.dart';

/// AI 服务配置 (OpenAI GPT)
class AIConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String visionModel;

  const AIConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    this.visionModel = 'gpt-4o',
  });

  bool get isConfigured => apiKey.isNotEmpty;

  AIConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? visionModel,
  }) {
    return AIConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      visionModel: visionModel ?? this.visionModel,
    );
  }
}

/// AI 配置通知器
class AIConfigNotifier extends StateNotifier<AIConfig> {
  final StorageService _storage;

  AIConfigNotifier(this._storage) : super(const AIConfig(apiKey: '')) {
    _loadConfig();
  }

  void _loadConfig() {
    final box = _storage.settingsBox;
    final apiKey = box.get('ai_api_key', defaultValue: '') as String;
    final baseUrl = box.get('ai_base_url', defaultValue: 'https://api.openai.com/v1') as String;
    final model = box.get('ai_model', defaultValue: 'gpt-4o') as String;
    state = AIConfig(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      visionModel: model,
    );
  }

  Future<void> setApiKey(String apiKey) async {
    await _storage.settingsBox.put('ai_api_key', apiKey);
    state = state.copyWith(apiKey: apiKey);
  }

  Future<void> setBaseUrl(String baseUrl) async {
    await _storage.settingsBox.put('ai_base_url', baseUrl);
    state = state.copyWith(baseUrl: baseUrl);
  }

  Future<void> setModel(String model) async {
    await _storage.settingsBox.put('ai_model', model);
    state = state.copyWith(model: model, visionModel: model);
  }
}

/// AI 配置 Provider
final aiConfigProvider = StateNotifierProvider<AIConfigNotifier, AIConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AIConfigNotifier(storage);
});

/// AI 服务 (OpenAI GPT)
class AIService {
  final Dio _dio;
  final AIConfig config;

  AIService({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: config.baseUrl,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ));

  /// 识别图片中的食材
  Future<List<IngredientRecognition>> recognizeIngredients(Uint8List imageBytes) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    final base64Image = base64Encode(imageBytes);

    try {
      final response = await _dio.post('/chat/completions', data: {
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
                'text': '''请识别图片中的食材，并以JSON格式返回。每个食材包含：
- name: 食材名称
- quantity: 估算数量
- unit: 单位（个、根、块、包等）
- freshness: 新鲜度（fresh/normal/expiring）
- category: 类别（蔬菜/水果/肉类/海鲜/蛋奶/豆制品/主食/调味料/干货/其他）
- storageAdvice: 存储建议

只返回JSON数组，不要其他文字。示例：
[{"name":"胡萝卜","quantity":3,"unit":"根","freshness":"fresh","category":"蔬菜","storageAdvice":"冷藏保存，可存放1-2周"}]''',
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

  /// 解析食材文字输入
  Future<List<IngredientRecognition>> parseIngredientText(String text) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'system',
            'content': '你是一位食材解析助手。请将用户描述的食材信息解析为结构化的JSON数据。'
          },
          {
            'role': 'user',
            'content': '''请解析以下食材描述，提取食材信息并以JSON格式返回：

"$text"

每个食材包含：
- name: 食材名称
- quantity: 数量
- unit: 单位
- category: 类别（蔬菜/水果/肉类/海鲜/蛋奶/豆制品/主食/调味料/干货/其他）

只返回JSON数组。示例：
[{"name":"胡萝卜","quantity":3,"unit":"根","category":"蔬菜"}]''',
          },
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

  /// 生成菜单计划
  Future<MenuPlanResult> generateMealPlan({
    required FamilyModel family,
    required List<IngredientModel> inventory,
    required int days,
    required List<String> mealTypes,
    int dishesPerMeal = 2,
  }) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    // 构建家庭信息
    final familyInfo = _buildFamilyInfo(family);
    final inventoryInfo = _buildInventoryInfo(inventory);

    // 根据天数动态调整 token 限制，确保多天菜单完整生成
    final maxTokens = 4096 + (days - 1) * 1500;

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': maxTokens,
        'temperature': 0.7,
        'messages': [
          {
            'role': 'system',
            'content': '''你是一位专业的家庭营养师和烹饪顾问。
你的任务是根据家庭成员的健康状况、口味偏好和现有食材，生成营养均衡、美味可口的家庭菜单计划。

注意事项：
1. 优先使用库存中的食材，减少浪费
2. 根据家庭成员健康状况调整菜单（如有控糖需求，减少高糖食物；有高血压，减少盐分）
3. 当健康需求有冲突时（如控糖 vs 儿童成长），智能平衡，提供折中方案
4. 营养均衡，每天蛋白质、碳水、蔬菜搭配合理
5. 菜谱要详细实用，包含具体用量、步骤和技巧
6. 购物清单只包含库存不足的食材
7. 使用自然、家常的语气描述
8. 每餐生成指定数量的菜品'''
          },
          {
            'role': 'user',
            'content': '''请根据以下信息生成$days天的家庭菜单计划：

【家庭信息】
$familyInfo

【现有食材库存】
$inventoryInfo

【需要的餐次】
${mealTypes.join('、')}

【每餐菜品数量】
每餐生成 $dishesPerMeal 道菜

请生成菜单并以JSON格式返回，格式如下：
{
  "days": [
    {
      "date": "第1天",
      "meals": [
        {
          "type": "breakfast/lunch/dinner/snack",
          "recipes": [
            {
              "name": "菜名",
              "description": "简短描述",
              "prepTime": 10,
              "cookTime": 15,
              "ingredients": [{"name":"食材","quantity":1,"unit":"个"}],
              "steps": ["步骤1","步骤2"],
              "tips": "烹饪技巧",
              "tags": ["控糖友好","快手菜"],
              "nutrition": {"calories":200,"protein":15,"carbs":20,"fat":8}
            }
          ]
        }
      ]
    }
  ],
  "shoppingList": [
    {"name":"食材","quantity":1,"unit":"个","category":"蔬菜","notes":"备注"}
  ],
  "nutritionSummary": "营养总结和建议（仅供参考，不代替医生建议）"
}

只返回JSON，不要其他文字。''',
          },
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

  /// 根据库存推荐菜谱
  Future<List<RecipeModel>> suggestRecipes({
    required List<IngredientModel> inventory,
    required FamilyModel family,
    int count = 5,
  }) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    final inventoryInfo = _buildInventoryInfo(inventory);
    final familyInfo = _buildFamilyInfo(family);

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 2048,
        'temperature': 0.8,
        'messages': [
          {
            'role': 'system',
            'content': '你是一位创意家常菜专家。根据用户的食材库存和家庭情况，推荐适合的菜谱。'
          },
          {
            'role': 'user',
            'content': '''根据以下食材库存，推荐$count道可以制作的菜谱：

【食材库存】
$inventoryInfo

【家庭信息】
$familyInfo

请以JSON数组格式返回菜谱，每个菜谱包含：
{
  "name": "菜名",
  "description": "简短描述",
  "prepTime": 10,
  "cookTime": 15,
  "servings": 2,
  "ingredients": [{"name":"食材","quantity":1,"unit":"个","isOptional":false}],
  "steps": ["步骤1","步骤2"],
  "tips": "烹饪技巧",
  "tags": ["标签"],
  "difficulty": "easy/medium/hard",
  "nutrition": {"calories":200,"protein":15,"carbs":20,"fat":8}
}

优先推荐能充分利用现有食材的菜谱。只返回JSON数组。''',
          },
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

  /// 生成单个菜谱
  Future<RecipeModel> generateRecipe({
    required String dishName,
    required FamilyModel family,
  }) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    final familyInfo = _buildFamilyInfo(family);

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'system',
            'content': '你是一位专业的家庭烹饪导师。请提供详细、实用的菜谱。'
          },
          {
            'role': 'user',
            'content': '''请为以下菜品生成详细菜谱：

菜名：$dishName

【家庭信息】
$familyInfo

请以JSON格式返回：
{
  "name": "菜名",
  "description": "简短描述",
  "prepTime": 10,
  "cookTime": 15,
  "servings": 2,
  "ingredients": [{"name":"食材","quantity":1,"unit":"个","isOptional":false,"substitute":"可替代食材"}],
  "steps": ["详细步骤1","详细步骤2"],
  "tips": "烹饪技巧和注意事项",
  "tags": ["标签"],
  "difficulty": "easy/medium/hard",
  "nutrition": {"calories":200,"protein":15,"carbs":20,"fat":8,"summary":"营养点评"}
}

根据家庭成员健康状况调整配方。只返回JSON。''',
          },
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

  /// 估算营养信息
  Future<NutritionInfoModel> analyzeNutrition(RecipeModel recipe) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    final ingredientsList = recipe.ingredients
        .map((i) => '${i.name} ${i.quantity}${i.unit}')
        .join('、');

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': config.model,
        'max_tokens': 512,
        'messages': [
          {
            'role': 'system',
            'content': '你是一位营养师。请估算菜品的营养信息。数据仅供参考，不代替专业医生建议。'
          },
          {
            'role': 'user',
            'content': '''请估算以下菜品的营养信息（每份）：

菜名：${recipe.name}
食材：$ingredientsList
份数：${recipe.servings}

以JSON格式返回：
{"calories":数值,"protein":数值,"carbs":数值,"fat":数值,"fiber":数值,"summary":"简短营养点评（仅供参考）"}

只返回JSON。''',
          },
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

  // 辅助方法
  String _buildFamilyInfo(FamilyModel family) {
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

  String _buildInventoryInfo(List<IngredientModel> inventory) {
    if (inventory.isEmpty) return '暂无库存食材';

    final grouped = <String, List<IngredientModel>>{};
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

  String _extractJson(String text) {
    // 移除可能的 markdown 代码块标记
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

    // 尝试提取 JSON 内容
    final jsonMatch = RegExp(r'[\[\{].*[\]\}]', dotAll: true).firstMatch(cleaned);
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

  /// 通用聊天完成接口
  Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    if (!config.isConfigured) {
      throw AIServiceException('API 密钥未配置');
    }

    try {
      final response = await _dio.post('/chat/completions', data: {
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

/// AI 服务 Provider
final aiServiceProvider = Provider<AIService>((ref) {
  final config = ref.watch(aiConfigProvider);
  return AIService(config: config);
});

/// AI 服务异常
class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);

  @override
  String toString() => message;
}

/// 食材识别结果
class IngredientRecognition {
  final String name;
  final double quantity;
  final String unit;
  final String? freshness;
  final String? category;
  final String? storageAdvice;

  IngredientRecognition({
    required this.name,
    required this.quantity,
    required this.unit,
    this.freshness,
    this.category,
    this.storageAdvice,
  });

  factory IngredientRecognition.fromJson(Map<String, dynamic> json) {
    return IngredientRecognition(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      freshness: json['freshness'] as String?,
      category: json['category'] as String?,
      storageAdvice: json['storageAdvice'] as String?,
    );
  }
}

/// 菜单生成结果
class MenuPlanResult {
  final List<DayPlanData> days;
  final List<ShoppingItemData> shoppingList;
  final String? nutritionSummary;

  MenuPlanResult({
    required this.days,
    required this.shoppingList,
    this.nutritionSummary,
  });

  factory MenuPlanResult.fromJson(Map<String, dynamic> json) {
    return MenuPlanResult(
      days: (json['days'] as List).map((d) => DayPlanData.fromJson(d)).toList(),
      shoppingList: (json['shoppingList'] as List?)
              ?.map((s) => ShoppingItemData.fromJson(s))
              .toList() ??
          [],
      nutritionSummary: json['nutritionSummary'] as String?,
    );
  }
}

class DayPlanData {
  final String date;
  final List<MealData> meals;

  DayPlanData({required this.date, required this.meals});

  factory DayPlanData.fromJson(Map<String, dynamic> json) {
    return DayPlanData(
      date: json['date'] as String,
      meals: (json['meals'] as List).map((m) => MealData.fromJson(m)).toList(),
    );
  }
}

class MealData {
  final String type;
  final List<Map<String, dynamic>> recipes;

  MealData({required this.type, required this.recipes});

  factory MealData.fromJson(Map<String, dynamic> json) {
    return MealData(
      type: json['type'] as String,
      recipes: (json['recipes'] as List).cast<Map<String, dynamic>>(),
    );
  }
}

class ShoppingItemData {
  final String name;
  final double quantity;
  final String unit;
  final String? category;
  final String? notes;

  ShoppingItemData({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
    this.notes,
  });

  factory ShoppingItemData.fromJson(Map<String, dynamic> json) {
    return ShoppingItemData(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
