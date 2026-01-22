import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In zh, this message translates to:
  /// **'Love Cook'**
  String get appTitle;

  /// No description provided for @inventory.
  ///
  /// In zh, this message translates to:
  /// **'库存'**
  String get inventory;

  /// No description provided for @menu.
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get menu;

  /// No description provided for @recipes.
  ///
  /// In zh, this message translates to:
  /// **'菜谱'**
  String get recipes;

  /// No description provided for @shopping.
  ///
  /// In zh, this message translates to:
  /// **'购物'**
  String get shopping;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @family.
  ///
  /// In zh, this message translates to:
  /// **'家庭'**
  String get family;

  /// No description provided for @familyManagement.
  ///
  /// In zh, this message translates to:
  /// **'家庭管理'**
  String get familyManagement;

  /// No description provided for @inventoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'食材库存'**
  String get inventoryTitle;

  /// No description provided for @noInventory.
  ///
  /// In zh, this message translates to:
  /// **'暂无库存食材'**
  String get noInventory;

  /// No description provided for @addIngredientHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角按钮添加食材'**
  String get addIngredientHint;

  /// No description provided for @addIngredient.
  ///
  /// In zh, this message translates to:
  /// **'添加食材'**
  String get addIngredient;

  /// No description provided for @photoRecognition.
  ///
  /// In zh, this message translates to:
  /// **'拍照识别'**
  String get photoRecognition;

  /// No description provided for @photoRecognitionDesc.
  ///
  /// In zh, this message translates to:
  /// **'拍摄冰箱或储物柜照片，AI 自动识别食材'**
  String get photoRecognitionDesc;

  /// No description provided for @voiceInput.
  ///
  /// In zh, this message translates to:
  /// **'语音输入'**
  String get voiceInput;

  /// No description provided for @voiceInputDesc.
  ///
  /// In zh, this message translates to:
  /// **'说出食材名称和数量，如\"三根胡萝卜\"'**
  String get voiceInputDesc;

  /// No description provided for @manualInput.
  ///
  /// In zh, this message translates to:
  /// **'手动输入'**
  String get manualInput;

  /// No description provided for @manualInputDesc.
  ///
  /// In zh, this message translates to:
  /// **'手动输入食材名称和数量'**
  String get manualInputDesc;

  /// No description provided for @menuPlan.
  ///
  /// In zh, this message translates to:
  /// **'菜单计划'**
  String get menuPlan;

  /// No description provided for @noMenuPlan.
  ///
  /// In zh, this message translates to:
  /// **'暂无菜单计划'**
  String get noMenuPlan;

  /// No description provided for @generateMenuHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮生成本周菜单'**
  String get generateMenuHint;

  /// No description provided for @generateMenu.
  ///
  /// In zh, this message translates to:
  /// **'生成菜单'**
  String get generateMenu;

  /// No description provided for @selectDays.
  ///
  /// In zh, this message translates to:
  /// **'选择天数'**
  String get selectDays;

  /// No description provided for @selectMeals.
  ///
  /// In zh, this message translates to:
  /// **'选择餐次'**
  String get selectMeals;

  /// No description provided for @days.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String days(int count);

  /// No description provided for @breakfast.
  ///
  /// In zh, this message translates to:
  /// **'早餐'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In zh, this message translates to:
  /// **'午餐'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In zh, this message translates to:
  /// **'晚餐'**
  String get dinner;

  /// No description provided for @snacks.
  ///
  /// In zh, this message translates to:
  /// **'加餐/点心'**
  String get snacks;

  /// No description provided for @startGenerate.
  ///
  /// In zh, this message translates to:
  /// **'开始生成'**
  String get startGenerate;

  /// No description provided for @savedRecipes.
  ///
  /// In zh, this message translates to:
  /// **'收藏菜谱'**
  String get savedRecipes;

  /// No description provided for @smartRecommend.
  ///
  /// In zh, this message translates to:
  /// **'智能推荐'**
  String get smartRecommend;

  /// No description provided for @noSavedRecipes.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏菜谱'**
  String get noSavedRecipes;

  /// No description provided for @savedRecipesHint.
  ///
  /// In zh, this message translates to:
  /// **'生成菜单后可收藏喜欢的菜谱'**
  String get savedRecipesHint;

  /// No description provided for @recommendByInventory.
  ///
  /// In zh, this message translates to:
  /// **'根据库存推荐菜谱'**
  String get recommendByInventory;

  /// No description provided for @recommendByInventoryHint.
  ///
  /// In zh, this message translates to:
  /// **'添加食材后，AI 会推荐可做的菜谱'**
  String get recommendByInventoryHint;

  /// No description provided for @recipeDetail.
  ///
  /// In zh, this message translates to:
  /// **'菜谱详情'**
  String get recipeDetail;

  /// No description provided for @shoppingList.
  ///
  /// In zh, this message translates to:
  /// **'购物清单'**
  String get shoppingList;

  /// No description provided for @noShoppingList.
  ///
  /// In zh, this message translates to:
  /// **'暂无购物清单'**
  String get noShoppingList;

  /// No description provided for @shoppingListHint.
  ///
  /// In zh, this message translates to:
  /// **'生成菜单后会自动生成购物清单'**
  String get shoppingListHint;

  /// No description provided for @exportList.
  ///
  /// In zh, this message translates to:
  /// **'导出清单'**
  String get exportList;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get selectLanguage;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @apiKeyConfig.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥配置'**
  String get apiKeyConfig;

  /// No description provided for @apiKeyConfigDesc.
  ///
  /// In zh, this message translates to:
  /// **'配置 Claude/GPT API 密钥'**
  String get apiKeyConfigDesc;

  /// No description provided for @dataManagement.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// No description provided for @backupRestore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupRestore;

  /// No description provided for @clearAllData.
  ///
  /// In zh, this message translates to:
  /// **'清除所有数据'**
  String get clearAllData;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @preferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get preferences;

  /// No description provided for @aiSettings.
  ///
  /// In zh, this message translates to:
  /// **'AI 设置'**
  String get aiSettings;

  /// No description provided for @healthDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'仅供参考，不代替医生建议'**
  String get healthDisclaimer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
