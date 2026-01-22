# Love Cook V1 - 智能餐食推荐功能实现计划

> **状态：已完成** | 完成日期：2025-01-22 | 版本：V1.0

---

## 一、背景分析

### 1.1 项目背景

Love Cook 是一个家庭餐食 AI 助手，旨在帮助家庭解决"今天吃什么"的问题。V1 版本需要实现完整的智能餐食推荐闭环。

### 1.2 用户痛点

| 痛点 | 描述 |
|------|------|
| 决策疲劳 | 每天为吃什么纠结，缺乏灵感 |
| 重复单调 | 经常做同样的菜，缺乏变化 |
| 健康考虑 | 家庭成员有不同的健康需求和口味 |
| 食材浪费 | 库存食材经常过期浪费 |

### 1.3 核心目标

1. **灵活的菜单生成**：支持 1/3/5/7 天计划
2. **个性化推荐**：基于家庭成员口味、健康状况
3. **智能避重**：避免近期重复推荐
4. **完整闭环**：从推荐→做饭→记录→评价→学习

### 1.4 技术选型

| 技术 | 选择 | 原因 |
|------|------|------|
| 框架 | Flutter Web | 跨平台，一套代码 |
| 状态管理 | Riverpod | 类型安全，依赖注入 |
| 本地存储 | Hive | 轻量级，性能好 |
| AI | OpenAI GPT-4o | 能力强，响应快 |
| 路由 | GoRouter | 声明式，支持深链接 |

---

## 二、实现步骤

### 阶段1：推荐模块增强

**目标**：让推荐模块支持完整配置

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 1.1 | 创建 RecommendSettings 数据模型 | `recommend_provider.dart` |
| 1.2 | 添加天数/餐次/菜品数状态管理 | `recommend_provider.dart` |
| 1.3 | 实现设置 UI（天数、餐次、菜品数选择器） | `recommend_screen.dart` |
| 1.4 | 添加心情输入框和快捷标签 | `recommend_screen.dart` |
| 1.5 | 修改 AI 提示词整合心情输入 | `ai_service.dart` |

### 阶段2：实时对话模式

**目标**：支持用户与 AI 对话确定口味需求

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 2.1 | 创建 MoodChatProvider 对话状态管理 | `mood_chat_provider.dart` |
| 2.2 | 创建对话界面（聊天气泡、输入框） | `mood_chat_screen.dart` |
| 2.3 | 实现 AI 对话 API | `ai_service.dart` |
| 2.4 | 添加"聊聊"入口按钮 | `recommend_screen.dart` |

### 阶段3：用餐历史记录

**目标**：记录用户实际吃了什么

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 3.1 | 创建 MealHistoryModel (Hive typeId=50) | `meal_history_model.dart` |
| 3.2 | 创建 MealHistoryRepository | `meal_history_repository.dart` |
| 3.3 | 菜谱详情页添加"已吃"按钮 | `recipe_detail_screen.dart` |
| 3.4 | 创建 HistoryProvider | `history_provider.dart` |

### 阶段4：日历视图

**目标**：通过日历查看和评价历史用餐

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 4.1 | 创建日历界面（table_calendar） | `meal_calendar_screen.dart` |
| 4.2 | 实现日期点击查看详情 | `meal_calendar_screen.dart` |
| 4.3 | 添加评价功能（5级 emoji 评分） | `meal_calendar_screen.dart` |
| 4.4 | 我的页面添加日历入口 | `profile_screen.dart` |

### 阶段5：智能推荐优化

**目标**：根据历史数据优化推荐

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 5.1 | 实现近期菜品查询方法 | `meal_history_repository.dart` |
| 5.2 | 设置页添加避重天数配置 | `settings_screen.dart` |
| 5.3 | AI 提示词添加避重和偏好逻辑 | `ai_service.dart` |
| 5.4 | 收藏菜谱优先推荐 | `ai_service.dart` |

### 阶段6：导航重构

**目标**：优化导航结构

| 步骤 | 任务 | 关键文件 |
|------|------|----------|
| 6.1 | 修改为 3-Tab 导航（推荐/购物/我的） | `router.dart` |
| 6.2 | 更新底部导航栏 | `main_scaffold.dart` |
| 6.3 | 整合我的页面功能入口 | `profile_screen.dart` |

---

## 三、待办清单

### 已完成 ✅

- [x] **T1.1** 创建 RecommendSettings 数据模型
- [x] **T1.2** 修改 RecommendProvider 支持配置
- [x] **T1.3** 修改 recommend_screen 添加设置 UI
- [x] **T1.4** 修改 ai_service 提示词整合心情输入
- [x] **T2.1** 创建 MoodChatProvider 对话状态管理
- [x] **T2.2** 创建 mood_chat_screen 对话界面
- [x] **T2.3** 修改 ai_service 添加对话模式 API
- [x] **T2.4** recommend_screen 添加"聊聊"入口
- [x] **T3.1** 创建 MealHistoryModel (Hive typeId=50)
- [x] **T3.2** 创建 MealHistoryRepository
- [x] **T3.3** 修改 recipe_detail_screen 添加"已吃"按钮
- [x] **T3.4** 创建 HistoryProvider 状态管理
- [x] **T4.1** 创建 meal_calendar_screen 日历界面
- [x] **T4.2** 实现日期点击查看详情 + 评价
- [x] **T4.3** 修改 profile_screen 添加日历入口
- [x] **T4.4** 设置页添加避重天数配置
- [x] **T5.1** 实现近期菜品查询方法
- [x] **T5.2** AI 提示词添加"避免重复"逻辑
- [x] **T5.3** AI 提示词添加"偏好分析"逻辑
- [x] **T5.4** 收藏菜谱优先推荐
- [x] **T6.1** 修改 router.dart 为 3 个 Tab
- [x] **T6.2** 修改 main_scaffold.dart 导航项
- [x] **T6.3** 整合"我的"页面功能入口

### 后续优化（V2 规划）

- [ ] 语音输入完善 - 语音识别功能集成
- [ ] 单元测试补充 - 按测试计划补充
- [ ] 离线支持 - AI 功能离线降级方案
- [ ] 性能优化 - 大量历史记录时的加载优化
- [ ] 数据导出 - 支持导出用餐历史和菜谱
- [ ] 云端同步 - 多设备数据同步

---

## 四、风险点

### 4.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| AI API 调用延迟 | 用户等待时间长 | 添加 loading 状态，优化提示词减少 token |
| AI 返回格式错误 | 解析失败 | 添加重试机制，最多 3 次 |
| Hive 数据迁移 | 升级时数据丢失 | 预留 typeId，做好版本管理 |
| 浏览器兼容性 | Web Speech API 不兼容 | 提供备用方案（Whisper API） |

### 4.2 产品风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 推荐不符合口味 | 用户体验差 | 增加偏好学习，支持即时反馈 |
| 避重逻辑过严 | 可选菜品太少 | 避重天数可配置（3-30天） |
| 家庭数据丢失 | 用户流失 | 本地多备份，未来支持云同步 |

### 4.3 运营风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| API 费用过高 | 成本不可控 | 限制调用频率，优化提示词 |
| 用户不创建家庭 | 功能无法使用 | 新用户引导流程 |
| 历史数据过多 | 性能下降 | 分页加载，定期清理 |

### 4.4 已知问题

| 问题 | 状态 | 计划 |
|------|------|------|
| 语音输入 UI 已添加但功能未完成 | 待实现 | V2 版本实现 |
| 单元测试覆盖不足 | 待补充 | V2 版本补充 |
| 无离线支持 | 待实现 | V2 版本考虑 |

---

## 五、数据模型

### 5.1 RecommendSettings

```dart
class RecommendSettings {
  final int days;              // 1/3/5/7
  final bool breakfast;
  final bool lunch;
  final bool dinner;
  final bool snacks;
  final int dishesPerMeal;     // 1-6
  final String? moodInput;
  final int avoidRecentDays;   // 默认 7
}
```

### 5.2 MealHistoryModel

```dart
@HiveType(typeId: 50)
class MealHistoryModel {
  String id;
  String familyId;
  DateTime date;
  String mealType;
  List<MealHistoryRecipeModel> recipes;
  String? notes;
  DateTime createdAt;
}

@HiveType(typeId: 51)
class MealHistoryRecipeModel {
  String recipeId;
  String recipeName;
  int? rating;      // 1-5
  String? comment;
}
```

---

## 六、文件清单

### 新建文件

| 文件 | 功能 |
|------|------|
| `lib/features/history/data/models/meal_history_model.dart` | 用餐历史模型 |
| `lib/features/history/data/repositories/meal_history_repository.dart` | 历史仓库 |
| `lib/features/history/presentation/screens/meal_calendar_screen.dart` | 日历视图 |
| `lib/features/history/presentation/providers/history_provider.dart` | 历史状态 |
| `lib/features/recommend/presentation/screens/mood_chat_screen.dart` | 对话页面 |
| `lib/features/recommend/presentation/providers/mood_chat_provider.dart` | 对话状态 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `recommend_provider.dart` | 天数/餐次/菜品数/心情设置 |
| `recommend_screen.dart` | 设置 UI + 对话入口 |
| `recipe_detail_screen.dart` | "已吃"按钮 |
| `ai_service.dart` | 对话模式 + 提示词增强 |
| `router.dart` | 3-Tab 导航 |
| `main_scaffold.dart` | 3-Tab 导航项 |
| `settings_screen.dart` | 避重天数设置 |
| `profile_screen.dart` | 日历入口 |

---

## 七、验收标准

| 功能 | 验收项 | 状态 |
|------|--------|------|
| 推荐模块 | 天数/餐次/菜品数/心情/标签/对话/跳转 | ✅ |
| 用餐历史 | "已吃"按钮/直接保存/按日期存储 | ✅ |
| 日历视图 | 入口/月视图/标记/详情/评价/提示 | ✅ |
| 智能推荐 | 避重配置/避重逻辑/喜好/收藏优先 | ✅ |
| 家庭管理 | 数据保存/AI 传递/人数影响菜品数 | ✅ |
| 构建验证 | `flutter build web` 成功 | ✅ |
