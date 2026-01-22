// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Love Cook';

  @override
  String get inventory => '库存';

  @override
  String get menu => '菜单';

  @override
  String get recipes => '菜谱';

  @override
  String get shopping => '购物';

  @override
  String get settings => '设置';

  @override
  String get family => '家庭';

  @override
  String get familyManagement => '家庭管理';

  @override
  String get inventoryTitle => '食材库存';

  @override
  String get noInventory => '暂无库存食材';

  @override
  String get addIngredientHint => '点击右下角按钮添加食材';

  @override
  String get addIngredient => '添加食材';

  @override
  String get photoRecognition => '拍照识别';

  @override
  String get photoRecognitionDesc => '拍摄冰箱或储物柜照片，AI 自动识别食材';

  @override
  String get voiceInput => '语音输入';

  @override
  String get voiceInputDesc => '说出食材名称和数量，如\"三根胡萝卜\"';

  @override
  String get manualInput => '手动输入';

  @override
  String get manualInputDesc => '手动输入食材名称和数量';

  @override
  String get menuPlan => '菜单计划';

  @override
  String get noMenuPlan => '暂无菜单计划';

  @override
  String get generateMenuHint => '点击下方按钮生成本周菜单';

  @override
  String get generateMenu => '生成菜单';

  @override
  String get selectDays => '选择天数';

  @override
  String get selectMeals => '选择餐次';

  @override
  String days(int count) {
    return '$count 天';
  }

  @override
  String get breakfast => '早餐';

  @override
  String get lunch => '午餐';

  @override
  String get dinner => '晚餐';

  @override
  String get snacks => '加餐/点心';

  @override
  String get startGenerate => '开始生成';

  @override
  String get savedRecipes => '收藏菜谱';

  @override
  String get smartRecommend => '智能推荐';

  @override
  String get noSavedRecipes => '暂无收藏菜谱';

  @override
  String get savedRecipesHint => '生成菜单后可收藏喜欢的菜谱';

  @override
  String get recommendByInventory => '根据库存推荐菜谱';

  @override
  String get recommendByInventoryHint => '添加食材后，AI 会推荐可做的菜谱';

  @override
  String get recipeDetail => '菜谱详情';

  @override
  String get shoppingList => '购物清单';

  @override
  String get noShoppingList => '暂无购物清单';

  @override
  String get shoppingListHint => '生成菜单后会自动生成购物清单';

  @override
  String get exportList => '导出清单';

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get apiKeyConfig => 'API 密钥配置';

  @override
  String get apiKeyConfigDesc => '配置 Claude/GPT API 密钥';

  @override
  String get dataManagement => '数据管理';

  @override
  String get backupRestore => '备份与恢复';

  @override
  String get clearAllData => '清除所有数据';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get preferences => '偏好设置';

  @override
  String get aiSettings => 'AI 设置';

  @override
  String get healthDisclaimer => '仅供参考，不代替医生建议';
}
