// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Love Cook';

  @override
  String get inventory => 'Inventory';

  @override
  String get menu => 'Menu';

  @override
  String get recipes => 'Recipes';

  @override
  String get shopping => 'Shopping';

  @override
  String get settings => 'Settings';

  @override
  String get family => 'Family';

  @override
  String get familyManagement => 'Family Management';

  @override
  String get inventoryTitle => 'Ingredient Inventory';

  @override
  String get noInventory => 'No ingredients in inventory';

  @override
  String get addIngredientHint => 'Tap the button below to add ingredients';

  @override
  String get addIngredient => 'Add Ingredient';

  @override
  String get photoRecognition => 'Photo Recognition';

  @override
  String get photoRecognitionDesc =>
      'Take a photo of your fridge, AI will identify ingredients';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get voiceInputDesc => 'Say ingredient names and quantities';

  @override
  String get manualInput => 'Manual Input';

  @override
  String get manualInputDesc =>
      'Manually enter ingredient names and quantities';

  @override
  String get menuPlan => 'Menu Plan';

  @override
  String get noMenuPlan => 'No menu plan yet';

  @override
  String get generateMenuHint => 'Tap below to generate this week\'s menu';

  @override
  String get generateMenu => 'Generate Menu';

  @override
  String get selectDays => 'Select Days';

  @override
  String get selectMeals => 'Select Meals';

  @override
  String days(int count) {
    return '$count days';
  }

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get snacks => 'Snacks';

  @override
  String get startGenerate => 'Start Generating';

  @override
  String get savedRecipes => 'Saved Recipes';

  @override
  String get smartRecommend => 'Smart Recommendations';

  @override
  String get noSavedRecipes => 'No saved recipes';

  @override
  String get savedRecipesHint =>
      'Save your favorite recipes from generated menus';

  @override
  String get recommendByInventory => 'Recommend by Inventory';

  @override
  String get recommendByInventoryHint =>
      'AI will recommend recipes based on your ingredients';

  @override
  String get recipeDetail => 'Recipe Details';

  @override
  String get shoppingList => 'Shopping List';

  @override
  String get noShoppingList => 'No shopping list';

  @override
  String get shoppingListHint =>
      'A shopping list will be generated with your menu';

  @override
  String get exportList => 'Export List';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get apiKeyConfig => 'API Key Configuration';

  @override
  String get apiKeyConfigDesc => 'Configure Claude/GPT API key';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get preferences => 'Preferences';

  @override
  String get aiSettings => 'AI Settings';

  @override
  String get healthDisclaimer =>
      'For reference only, not a substitute for medical advice';
}
