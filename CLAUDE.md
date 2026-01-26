# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Love Cook 是一个家庭餐食 AI 助手 Flutter 应用，帮助家庭管理食材库存、生成智能菜单、查看菜谱和管理购物清单。

**技术栈**: Flutter Web + Riverpod (状态管理) + GoRouter (路由) + Hive (本地存储) + OpenAI GPT-4o (AI)

## Common Commands

```bash
# 获取依赖
flutter pub get

# 生成 Hive 适配器（修改数据模型后必须执行）
flutter pub run build_runner build

# 开发模式运行
flutter run -d chrome

# 代码分析
flutter analyze

# 生产构建
flutter build web

# 运行所有测试（需要绕过代理）
NO_PROXY=localhost,127.0.0.1 flutter test

# 运行单个测试文件
NO_PROXY=localhost,127.0.0.1 flutter test test/core/services/ai_service_test.dart

# 运行特定测试组
NO_PROXY=localhost,127.0.0.1 flutter test --plain-name "AIConfig"

# 运行纯 Dart 测试（不需要 Flutter 环境）
dart test test/core/services/ai_service_pure_dart_test.dart
```

## Architecture

### 分层架构 (Feature-First + Clean Architecture)

```
lib/
├── app/                    # 应用配置
│   ├── app.dart           # MaterialApp 配置
│   └── router.dart        # GoRouter 路由定义 (AppRoutes)
├── core/
│   ├── services/          # 全局服务
│   │   ├── ai_service.dart      # OpenAI GPT 集成 (AIService, AIConfig)
│   │   ├── storage_service.dart # Hive 存储管理 (HiveBoxes)
│   │   └── locale_service.dart  # 多语言服务
│   ├── theme/             # 主题配置 (AppColors, AppTheme)
│   └── widgets/           # 通用组件 (MainScaffold)
├── features/              # 功能模块
│   ├── family/            # 家庭档案管理
│   ├── inventory/         # 库存管理
│   ├── menu/              # 菜单计划
│   ├── recipe/            # 菜谱管理
│   ├── recommend/         # AI 推荐引擎
│   ├── shopping/          # 购物清单
│   ├── history/           # 用餐历史
│   ├── cooking/           # 烹饪模式
│   ├── profile/           # 用户档案
│   └── settings/          # 应用设置
└── l10n/                  # 本地化资源
```

### Feature 模块结构

每个 feature 遵循统一结构：
```
features/{feature}/
├── data/
│   ├── models/           # Hive 数据模型 (@HiveType)
│   └── repositories/     # 数据访问层
└── presentation/
    ├── screens/          # UI 页面
    └── providers/        # Riverpod 状态管理
```

### 数据流

```
UI (Screens) → Providers (Riverpod StateNotifier) → Repositories → Hive Storage
                    ↓
              AIService (OpenAI API)
```

### Hive TypeId 分配

| TypeId | 模型 |
|--------|------|
| 0-2 | Family (FamilyModel, FamilyMemberModel, MealSettingsModel) |
| 10 | Ingredient (IngredientModel) |
| 20-22 | Recipe (RecipeModel, RecipeIngredientModel, NutritionInfoModel) |
| 30-32 | MealPlan (MealPlanModel, DayPlanModel, MealModel) |
| 40-41 | Shopping (ShoppingListModel, ShoppingItemModel) |
| 50-51 | History (MealHistoryModel, MealHistoryRecipeModel) |

### 关键 Providers

- `aiConfigProvider` / `aiServiceProvider` - AI 服务配置和实例
- `storageServiceProvider` - Hive 存储服务
- `familyListProvider` - 家庭列表状态
- `inventoryProvider` - 库存列表
- `recommendProvider` - AI 推荐状态
- `localeProvider` - 当前语言

## Development Notes

### 修改数据模型

1. 修改 `*_model.dart` 文件
2. 运行 `flutter pub run build_runner build` 生成适配器
3. 新增模型需分配唯一 TypeId

### AI 服务集成

`AIService` 提供以下方法：
- `recognizeIngredients()` - 图片识别食材
- `parseIngredientText()` - 文本解析食材
- `generateMealPlan()` - 生成菜单计划
- `suggestRecipes()` - 根据库存推荐菜谱
- `generateRecipe()` - 生成单个菜谱

### 饮食选项定义

预设选项集中在 `lib/features/family/data/models/dietary_options.dart`：
- `healthConditionOptions` - 健康状况
- `commonAllergens` - 过敏源
- `tastePreferences` - 口味偏好
- `dietaryRestrictions` - 饮食禁忌

### 路由

所有路由定义在 `lib/app/router.dart` 的 `AppRoutes` 类中。使用 `ShellRoute` 包装 `MainScaffold` 提供底部导航栏。

### 主题和暗黑模式

- 颜色定义在 `lib/core/theme/app_colors.dart`，分为 Light 和 Dark 两套
- 主题配置在 `lib/core/theme/app_theme.dart`
- Chips 组件需要显式设置 `elevation: 0`, `shadowColor: Colors.transparent`, `surfaceTintColor: Colors.transparent` 以避免 Material 3 覆盖层问题
- 使用 `Theme.of(context).brightness == Brightness.dark` 检测当前主题模式

### 测试

- 使用 `flutter_test` + `mockito` 进行单元测试
- 使用 `http_mock_adapter` 模拟 AI API 请求
- 测试文件位于 `test/` 目录，镜像 `lib/` 结构

**重要：代理环境问题**

如果系统设置了 HTTP_PROXY，Flutter 测试运行器会因为 localhost 连接被代理拦截而失败，报错：
```
HttpException: Connection closed before full header was received
```

解决方案：运行测试时添加 `NO_PROXY=localhost,127.0.0.1` 环境变量：
```bash
NO_PROXY=localhost,127.0.0.1 flutter test
```

**测试文件说明**

| 文件 | 说明 |
|------|------|
| `ai_service_test.dart` | AI 服务单元测试（需要 Flutter 环境） |
| `ai_service_pure_dart_test.dart` | AI 服务纯 Dart 测试（不依赖 Flutter） |
| `recommend_settings_test.dart` | 推荐设置模型测试 |
| `day_plan_test.dart` | 日计划和推荐状态测试 |
