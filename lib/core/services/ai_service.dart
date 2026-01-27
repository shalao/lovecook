import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/family/data/models/dietary_options.dart';
import 'log_service.dart';
import '../../features/family/data/models/family_model.dart';
import '../../features/inventory/data/models/ingredient_model.dart';
import '../../features/recipe/data/models/recipe_model.dart';
import 'ai_proxy_service.dart';
import 'storage_service.dart';

/// AI 服务配置 (简化版 - 无需 API Key)
class AIConfig {
  final String model;
  final String visionModel;

  const AIConfig({
    this.model = 'gpt-4o-mini',  // 使用更快的模型
    this.visionModel = 'gpt-4o',  // 视觉识别保持 gpt-4o
  });

  /// 始终返回 true，因为使用服务端代理
  bool get isConfigured => true;

  AIConfig copyWith({
    String? model,
    String? visionModel,
  }) {
    return AIConfig(
      model: model ?? this.model,
      visionModel: visionModel ?? this.visionModel,
    );
  }
}

/// AI 配置通知器 (简化版)
class AIConfigNotifier extends StateNotifier<AIConfig> {
  final StorageService _storage;

  AIConfigNotifier(this._storage) : super(const AIConfig()) {
    _loadConfig();
  }

  void _loadConfig() {
    final box = _storage.settingsBox;
    final model = box.get('ai_model', defaultValue: 'gpt-4o-mini') as String;
    state = AIConfig(model: model, visionModel: 'gpt-4o');  // 视觉模型保持 gpt-4o

    // 清理旧的 API Key 存储（迁移到服务端代理后不再需要）
    _cleanupLegacySettings();
  }

  /// 清理旧的设置项
  Future<void> _cleanupLegacySettings() async {
    final box = _storage.settingsBox;
    if (box.containsKey('ai_api_key')) {
      await box.delete('ai_api_key');
    }
    if (box.containsKey('ai_base_url')) {
      await box.delete('ai_base_url');
    }
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

/// AI 服务 (通过代理访问 OpenAI GPT)
class AIService {
  final AiProxyService _proxyService;
  final AIConfig config;

  AIService({
    required AiProxyService proxyService,
    required this.config,
  }) : _proxyService = proxyService;

  /// 识别图片中的食材
  Future<List<IngredientRecognition>> recognizeIngredients(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    try {
      final response = await _proxyService.chatCompletions(
        model: config.visionModel,
        maxTokens: 2048,
        messages: [
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
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      return items.map((item) => IngredientRecognition.fromJson(item)).toList();
    } on AiProxyException catch (e) {
      throw AIServiceException('识别失败: ${e.message}');
    }
  }

  /// 解析食材文字输入
  Future<List<IngredientRecognition>> parseIngredientText(String text) async {
    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 1024,
        messages: [
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
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      return items.map((item) => IngredientRecognition.fromJson(item)).toList();
    } on AiProxyException catch (e) {
      throw AIServiceException('解析失败: ${e.message}');
    }
  }

  /// 智能识别食材类别
  /// 当本地映射表无法匹配时，使用 AI 进行分类
  Future<String?> classifyIngredient(String ingredientName) async {
    if (ingredientName.isEmpty) {
      return null;
    }

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 50,
        temperature: 0.1, // 低温度，确保结果稳定
        messages: [
          {
            'role': 'system',
            'content': '''你是食材分类助手。根据食材名称返回其类别。
类别只能是以下之一：蔬菜、水果、肉类、海鲜、蛋奶、豆制品、主食、调味料、干货、饮品、零食、其他
只返回类别名称，不要返回任何其他内容。'''
          },
          {
            'role': 'user',
            'content': ingredientName,
          },
        ],
      );

      final content = response['choices'][0]['message']['content'] as String;
      final category = content.trim();

      // 验证返回的类别是否有效
      const validCategories = [
        '蔬菜', '水果', '肉类', '海鲜', '蛋奶', '豆制品',
        '主食', '调味料', '干货', '饮品', '零食', '其他'
      ];

      if (validCategories.contains(category)) {
        return category;
      }

      return null;
    } on AiProxyException {
      return null; // 网络错误时静默返回 null
    } catch (e) {
      return null;
    }
  }

  /// 生成菜单计划
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
    // 构建家庭信息
    final familyInfo = _buildFamilyInfo(family);
    final inventoryInfo = _buildInventoryInfo(inventory);

    // 构建偏好信息
    final preferenceInfo = _buildPreferenceInfo(
      recentRecipeNames: recentRecipeNames,
      likedRecipes: likedRecipes,
      dislikedRecipes: dislikedRecipes,
      favoriteRecipes: favoriteRecipes,
    );

    // 根据天数动态调整 token 限制，确保多天菜单完整生成
    // 每天约需 1500-2000 tokens (含所有餐次和菜品)
    // 注意：GPT-4o 等模型最大支持 16384 completion tokens
    final maxTokens = min(4096 + days * 2000, 16384);

    logger.apiCall('AIService', 'generateMealPlan', api: 'OpenAI GPT', request: {
      'days': days,
      'mealTypes': mealTypes,
      'dishesPerMeal': dishesPerMeal,
      'familyId': family.id,
      'inventoryCount': inventory.length,
      'hasMoodInput': moodInput != null && moodInput.isNotEmpty,
    });

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: maxTokens,
        temperature: 0.7,
        messages: [
          {
            'role': 'system',
            'content': '''你是一位专业的家庭营养师和烹饪顾问。
你的任务是根据家庭成员的健康状况、口味偏好和现有食材，生成营养均衡、美味可口的家庭菜单计划。

【重要】你必须完整生成用户要求的全部天数，不能省略或跳过任何一天！

注意事项：
1. 优先使用库存中的食材，减少浪费
2. 根据家庭成员健康状况调整菜单（如有控糖需求，减少高糖食物；有高血压，减少盐分）
3. 当健康需求有冲突时（如控糖 vs 儿童成长），智能平衡，提供折中方案
4. 营养均衡，每天蛋白质、碳水、蔬菜搭配合理
5. 菜谱要简洁实用，步骤精简（3-5步）
6. 购物清单只包含库存不足的食材
7. 使用自然、家常的语气描述
8. 每餐生成指定数量的菜品
9. 避免推荐近期吃过的菜品
10. 参考用户的历史评价偏好
11. 多天菜单要保证菜品多样性，不重复
12. 【健身目标】如有成员设置健身目标，严格按建议的营养配比设计菜单：
    - 减脂期：高蛋白低碳水，增加蔬菜，控制总热量
    - 增肌期：高蛋白高碳水，保证热量盈余
13. 【孕期营养】如有成员处于孕期/备孕/哺乳期：
    - 备孕期：富含叶酸、铁、锌的食材
    - 孕早期：清淡易消化，避免生冷
    - 孕中晚期：补钙、补铁、DHA
    - 哺乳期：催乳食材，高钙高蛋白'''
          },
          {
            'role': 'user',
            'content': '''请生成 **$days 天** 的完整家庭菜单计划（从今天开始，共 $days 天，不能少！）：

【家庭信息】
$familyInfo

【现有食材库存】
$inventoryInfo

【需要的餐次】
${mealTypes.join('、')}

【每餐菜品数量】
$dishesPerMeal 道菜
${moodInput != null && moodInput.isNotEmpty ? '''

【今天的特别需求/心情】
$moodInput''' : ''}
$preferenceInfo

请严格按以下JSON格式返回（days数组必须包含 $days 个元素）：
{
  "days": [
    {
      "date": "第1天",
      "meals": [
        {
          "type": "早餐/午餐/晚餐/加餐",
          "recipes": [
            {
              "name": "菜名",
              "description": "一句话描述",
              "prepTime": 10,
              "cookTime": 15,
              "ingredients": [{"name":"食材","quantity":1,"unit":"个"}],
              "steps": ["步骤1","步骤2","步骤3"],
              "tips": "技巧",
              "tags": ["标签"],
              "nutrition": {"calories":200,"protein":15,"carbs":20,"fat":8}
            }
          ]
        }
      ]
    },
    ... // 共 $days 天
  ],
  "shoppingList": [{"name":"食材","quantity":1,"unit":"个","category":"蔬菜"}],
  "nutritionSummary": "营养总结（仅供参考）"
}

注意：days数组必须有 $days 个元素，每天必须包含所有选择的餐次！只返回JSON。''',
          },
        ],
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      final result = MenuPlanResult.fromJson(data);
      logger.apiCall('AIService', 'generateMealPlan', api: 'OpenAI GPT', response: {
        'status': 'success',
        'daysCount': result.days.length,
        'shoppingListCount': result.shoppingList.length,
      });
      return result;
    } on AiProxyException catch (e) {
      logger.apiCall('AIService', 'generateMealPlan', api: 'OpenAI GPT', response: {
        'status': 'error',
        'error': e.message,
      }, isError: true);
      throw AIServiceException('生成菜单失败: ${e.message}');
    }
  }

  /// 根据库存推荐菜谱
  Future<List<RecipeModel>> suggestRecipes({
    required List<IngredientModel> inventory,
    required FamilyModel family,
    int count = 5,
  }) async {
    final inventoryInfo = _buildInventoryInfo(inventory);
    final familyInfo = _buildFamilyInfo(family);

    logger.apiCall('AIService', 'suggestRecipes', api: 'OpenAI GPT', request: {
      'count': count,
      'inventoryCount': inventory.length,
      'familyId': family.id,
    });

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 2048,
        temperature: 0.8,
        messages: [
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
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final List<dynamic> items = json.decode(jsonStr);

      final recipes = items.map((item) => _parseRecipe(item)).toList();
      logger.apiCall('AIService', 'suggestRecipes', api: 'OpenAI GPT', response: {
        'status': 'success',
        'recipesCount': recipes.length,
      });
      return recipes;
    } on AiProxyException catch (e) {
      logger.apiCall('AIService', 'suggestRecipes', api: 'OpenAI GPT', response: {
        'status': 'error',
        'error': e.message,
      }, isError: true);
      throw AIServiceException('推荐失败: ${e.message}');
    }
  }

  /// 生成单个菜谱
  Future<RecipeModel> generateRecipe({
    required String dishName,
    required FamilyModel family,
  }) async {
    final familyInfo = _buildFamilyInfo(family);

    logger.apiCall('AIService', 'generateRecipe', api: 'OpenAI GPT', request: {
      'dishName': dishName,
      'familyId': family.id,
    });

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 1024,
        messages: [
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
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      final recipe = _parseRecipe(data);
      logger.apiCall('AIService', 'generateRecipe', api: 'OpenAI GPT', response: {
        'status': 'success',
        'recipeName': recipe.name,
      });
      return recipe;
    } on AiProxyException catch (e) {
      logger.apiCall('AIService', 'generateRecipe', api: 'OpenAI GPT', response: {
        'status': 'error',
        'error': e.message,
      }, isError: true);
      throw AIServiceException('生成菜谱失败: ${e.message}');
    }
  }

  /// 对话模式：提取用户饮食偏好
  Future<MoodChatResponse> chatForMoodExtraction({
    required List<dynamic> messages,
    required dynamic family,
    required List<dynamic> inventory,
  }) async {
    // 构建家庭和库存信息
    String familyInfo = '暂无家庭信息';
    String inventoryInfo = '暂无库存信息';

    if (family != null && family is FamilyModel) {
      familyInfo = _buildFamilyInfo(family);
    }

    if (inventory.isNotEmpty) {
      final typedInventory = inventory.whereType<IngredientModel>().toList();
      if (typedInventory.isNotEmpty) {
        inventoryInfo = _buildInventoryInfo(typedInventory);
      }
    }

    // 构建对话历史
    final chatMessages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': '''你是一位友好、专业的家庭美食顾问。你的任务是通过对话了解用户今天想吃什么，帮助他们确定饮食偏好。

你需要：
1. 用亲切自然的语气与用户交流
2. 根据用户的描述（如心情、口味、食材偏好）给出建议
3. 适时提出问题帮助用户明确需求
4. 当用户的需求足够明确时，总结偏好并推荐3-5道菜品

【当前家庭信息】
$familyInfo

【现有食材库存】
$inventoryInfo

回复格式要求：
- 正常对话时，直接返回自然语言回复
- 当你认为已经充分了解用户需求时，在回复最后添加以下JSON（用```json```包裹）：
```json
{
  "extractedPreference": "提取的用户偏好总结",
  "suggestedDishes": ["菜品1", "菜品2", "菜品3"]
}
```

注意：只有当你认为可以给出推荐时才添加JSON，普通对话不需要。'''
      },
    ];

    // 添加对话历史
    for (final msg in messages) {
      if (msg.isLoading) continue;
      chatMessages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 1024,
        temperature: 0.8,
        messages: chatMessages,
      );

      final content = response['choices'][0]['message']['content'] as String;

      // 解析回复，检查是否包含JSON
      String reply = content;
      String? extractedPreference;
      List<String>? suggestedDishes;

      // 尝试提取JSON部分
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(1)!;
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          extractedPreference = data['extractedPreference'] as String?;
          suggestedDishes = (data['suggestedDishes'] as List?)?.cast<String>();
          // 移除JSON部分，保留自然语言回复
          reply = content.replaceAll(jsonMatch.group(0)!, '').trim();
        } catch (_) {
          // JSON解析失败，忽略
        }
      }

      return MoodChatResponse(
        reply: reply,
        extractedPreference: extractedPreference,
        suggestedDishes: suggestedDishes,
      );
    } on AiProxyException catch (e) {
      throw AIServiceException('对话失败: ${e.message}');
    }
  }

  /// 生成单道替换菜品（快速版本，用于换一道菜）
  Future<Map<String, dynamic>> generateSingleRecipe({
    required FamilyModel family,
    required List<IngredientModel> inventory,
    required String mealType,
    required List<String> excludeRecipes,
    String? preference,
  }) async {
    // 简化家庭信息：只包含必要的健康限制
    final healthRestrictions = <String>[];
    final allergies = <String>[];
    for (final member in family.members) {
      healthRestrictions.addAll(member.healthConditions);
      allergies.addAll(member.allergies);
    }

    // 简化库存信息：只列出名称
    final inventoryNames = inventory.map((i) => i.name).take(30).join('、');

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 800,  // 单道菜只需要较少 token
        temperature: 0.8,
        messages: [
          {
            'role': 'system',
            'content': '你是家常菜专家。快速推荐一道适合的菜品。'
          },
          {
            'role': 'user',
            'content': '''推荐一道$mealType菜品：

${healthRestrictions.isNotEmpty ? '健康限制：${healthRestrictions.toSet().join("、")}\n' : ''}${allergies.isNotEmpty ? '过敏源：${allergies.toSet().join("、")}\n' : ''}${inventoryNames.isNotEmpty ? '可用食材：$inventoryNames\n' : ''}${excludeRecipes.isNotEmpty ? '排除：${excludeRecipes.join("、")}\n' : ''}${preference != null ? '偏好：$preference\n' : ''}
返回JSON：
{"name":"菜名","description":"简短描述","prepTime":10,"cookTime":15,"ingredients":[{"name":"食材","quantity":1,"unit":"个"}],"steps":["步骤1","步骤2"],"tips":"技巧","tags":["标签"],"nutrition":{"calories":200,"protein":15,"carbs":20,"fat":8}}

只返回JSON。''',
          },
        ],
      );

      final content = response['choices'][0]['message']['content'] as String;
      final jsonStr = _extractJson(content);
      return json.decode(jsonStr) as Map<String, dynamic>;
    } on AiProxyException catch (e) {
      throw AIServiceException('生成失败: ${e.message}');
    }
  }

  /// 估算营养信息
  Future<NutritionInfoModel> analyzeNutrition(RecipeModel recipe) async {
    final ingredientsList = recipe.ingredients
        .map((i) => '${i.name} ${i.quantity}${i.unit}')
        .join('、');

    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: 512,
        messages: [
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
      );

      final content = response['choices'][0]['message']['content'] as String;
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
    } on AiProxyException catch (e) {
      throw AIServiceException('分析失败: ${e.message}');
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
      // v1.2: 健身目标
      if (member.fitnessGoal != null) {
        buffer.write('，健身目标：${member.fitnessGoal}');
        final ratios = fitnessNutritionRatios[member.fitnessGoal];
        if (ratios != null) {
          final protein = ((ratios['proteinRatio'] as double) * 100).toInt();
          final carb = ((ratios['carbRatio'] as double) * 100).toInt();
          final fat = ((ratios['fatRatio'] as double) * 100).toInt();
          buffer.write('（建议配比：蛋白$protein%/碳水$carb%/脂肪$fat%）');
        }
      }
      // v1.2: 孕期阶段
      if (member.pregnancyStage != null) {
        buffer.write('，孕期：${member.pregnancyStage}');
        final focus = pregnancyNutritionFocus[member.pregnancyStage];
        if (focus != null && focus.isNotEmpty) {
          buffer.write('（重点补充：${focus.join("、")}）');
        }
      }
      // 备注信息（包含具体疾病或特殊说明）
      if (member.notes != null && member.notes!.isNotEmpty) {
        buffer.write('，特别注意：${member.notes}');
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

  String _buildPreferenceInfo({
    List<String>? recentRecipeNames,
    List<String>? likedRecipes,
    List<String>? dislikedRecipes,
    List<String>? favoriteRecipes,
  }) {
    final buffer = StringBuffer();

    // 避免重复的近期菜品
    if (recentRecipeNames != null && recentRecipeNames.isNotEmpty) {
      buffer.writeln('\n【请避免推荐以下近期吃过的菜品】');
      buffer.writeln(recentRecipeNames.join('、'));
    }

    // 喜欢的菜品风格
    if (likedRecipes != null && likedRecipes.isNotEmpty) {
      buffer.writeln('\n【用户喜欢的菜品（可参考类似风格）】');
      buffer.writeln(likedRecipes.take(10).join('、'));
    }

    // 不喜欢的菜品
    if (dislikedRecipes != null && dislikedRecipes.isNotEmpty) {
      buffer.writeln('\n【用户不喜欢的菜品（请避免）】');
      buffer.writeln(dislikedRecipes.take(10).join('、'));
    }

    // 收藏的菜谱优先
    if (favoriteRecipes != null && favoriteRecipes.isNotEmpty) {
      buffer.writeln('\n【用户收藏的菜谱（可优先考虑）】');
      buffer.writeln(favoriteRecipes.take(10).join('、'));
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

  /// 通用聊天完成接口
  Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _proxyService.chatCompletions(
        model: config.model,
        maxTokens: maxTokens,
        temperature: temperature,
        messages: messages,
      );

      return response['choices'][0]['message']['content'] as String;
    } on AiProxyException catch (e) {
      throw AIServiceException('请求失败: ${e.message}');
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
  final proxyService = ref.watch(aiProxyServiceProvider);
  final config = ref.watch(aiConfigProvider);
  return AIService(proxyService: proxyService, config: config);
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

/// 对话模式响应
class MoodChatResponse {
  final String reply;
  final String? extractedPreference;
  final List<String>? suggestedDishes;

  MoodChatResponse({
    required this.reply,
    this.extractedPreference,
    this.suggestedDishes,
  });
}
