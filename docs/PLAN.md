# Love Cook 功能完善计划

## 一、问题总览

### 业务流程断点
```
库存 → 菜单生成 → 购物清单 → ❌ 断开 → 库存更新
                              ↓
                         做菜 → ❌ 断开 → 库存扣减
```

### 修复优先级汇总

| 优先级 | 问题 | 影响 |
|--------|------|------|
| 🔴 P0-1 | 路由不一致 | 菜谱详情页无法打开 |
| 🔴 P0-2 | 购物入库断开 | 核心闭环断裂 |
| 🔴 P0-3 | 烹饪扣减断开 | 核心闭环断裂 |
| 🟡 P1-1 | 每餐菜品数量不可控 | 用户体验 |
| 🟡 P1-2 | 年龄未自动关联分组 | 数据完整性 |
| 🟡 P1-3 | 菜谱无成品图 | 视觉体验 |
| 🟡 P1-4 | 菜单不可编辑 | 用户体验 |
| 🟢 P2-1 | 烹饪语音助手 | 增强功能 |
| 🟢 P2-2 | 库存智能匹配 | 增强功能 |

---

## 二、P0 高优先级修复

### P0-1: 路由不一致

**文件**: `lib/features/recipe/presentation/screens/recipe_list_screen.dart:121`

**修复**:
```dart
// 当前（错误）
onTap: () => context.push('/recipe/${recipe.id}'),

// 修复为
onTap: () => context.push('${AppRoutes.recipes}/${recipe.id}'),
```

**验证**: 点击菜谱卡片，确认跳转到详情页

---

### P0-2: 购物入库功能

**文件**:
- `lib/features/shopping/presentation/screens/shopping_list_screen.dart`
- `lib/features/inventory/presentation/providers/inventory_provider.dart`

**新增**: "确认入库"按钮

```dart
// 在购物清单页底部添加
ElevatedButton(
  onPressed: () => _confirmAddToInventory(purchasedItems),
  child: Text('确认入库 (${purchasedCount}项)'),
)

// 入库逻辑
Future<void> _confirmAddToInventory(List<ShoppingItemModel> items) async {
  for (final item in items.where((i) => i.purchased)) {
    final existing = inventory.findByName(item.name);
    if (existing != null) {
      await inventoryProvider.addQuantity(existing.id, item.quantity);
    } else {
      await inventoryProvider.addIngredient(IngredientModel.create(
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
      ));
    }
  }
  await shoppingListRepository.clearPurchased(listId);
}
```

**验证**: 勾选购物项 → 点击入库 → 检查库存数量变化

---

### P0-3: 完成烹饪功能

**文件**:
- `lib/features/recipe/presentation/screens/recipe_detail_screen.dart`

**新增**: "完成烹饪"按钮

```dart
// 在菜谱详情页添加 FAB
FloatingActionButton.extended(
  onPressed: () => _showCompleteCookingDialog(recipe),
  icon: Icon(Icons.check),
  label: Text('完成烹饪'),
)

// 确认对话框 + 扣减库存
Future<void> _showCompleteCookingDialog(RecipeModel recipe) async {
  final confirmed = await showDialog<bool>(...);
  if (confirmed == true) {
    for (final ing in recipe.ingredients) {
      final item = inventory.findByName(ing.name);
      if (item != null) {
        await inventoryProvider.deductQuantity(item.id, ing.quantity);
      }
    }
  }
}
```

**验证**: 完成烹饪 → 检查库存扣减

---

## 三、P1 中优先级修复

### P1-1: 每餐菜品数量

**文件**:
- `lib/features/menu/presentation/providers/menu_provider.dart`
- `lib/core/services/ai_service.dart`
- `lib/features/menu/presentation/screens/generate_menu_screen.dart`

**修改**:
1. `MenuGenerateSettings` 添加 `dishesPerMeal` 字段（默认2）
2. AI Prompt 添加: `"每餐生成 $dishesPerMeal 道菜"`
3. UI 添加分段选择器: 1道/2道/3道

---

### P1-2: 年龄自动关联

**文件**: `lib/features/family/presentation/screens/family_detail_screen.dart`

**修改**: 成员编辑对话框添加年龄输入，自动计算 ageGroup

```dart
TextField(
  decoration: InputDecoration(labelText: '年龄'),
  keyboardType: TextInputType.number,
  onChanged: (value) {
    final age = int.tryParse(value);
    if (age != null) {
      selectedAgeGroup = FamilyMemberModel.getAgeGroup(age);
    }
  },
),
```

---

### P1-3: 菜谱成品图

**文件**:
- `lib/core/services/ai_service.dart`
- `lib/features/recipe/presentation/screens/recipe_list_screen.dart`

**方案**: 混合方案
1. 默认: Unsplash API 搜索美食图（免费）
2. 可选: DALL-E 3 生成（$0.04-0.08/张）
3. 支持: 用户上传

---

### P1-4: 菜单编辑

**文件**:
- `lib/features/menu/presentation/screens/menu_screen.dart`
- `lib/features/menu/data/repositories/meal_plan_repository.dart`

**新增**: 替换菜品功能
- Repository 添加 `replaceMeal()` 方法
- UI 添加替换按钮

---

## 四、P2 增强功能

### P2-1: 烹饪语音助手

**新模块**: `lib/features/cooking/`

**技术方案（付费）**:
| 组件 | 方案 | 说明 |
|------|------|------|
| 语音识别 | OpenAI Whisper | 高精度中文识别 |
| AI 对话 | GPT-4o | 多轮对话 + 上下文管理 |
| 语音合成 | OpenAI TTS | 自然流畅的语音输出 |

**核心功能**:
- 语音识别 (STT): OpenAI Whisper API
- AI 多轮对话: GPT-4o + 上下文管理
- 语音合成 (TTS): OpenAI TTS API

**依赖包**:
```yaml
record: ^5.0.4              # 录音
just_audio: ^0.9.36         # 音频播放
permission_handler: ^11.0.1  # 麦克风权限
```

**成本估算**（每天做2道菜，每道菜5次语音交互）:
- Whisper: ~$0.006/分钟 × 10次 × 0.5分钟 = ~$0.03/天
- GPT-4o: ~$0.01/次 × 10次 = ~$0.10/天
- TTS: ~$0.015/1000字 × 500字 = ~$0.01/天
- **月成本**: ~$4-5

**界面**:
```
┌────────────────────────────┐
│ 🍳 烹饪模式 - 红烧肉       │
├────────────────────────────┤
│ 步骤 3/8                   │
│ ┌────────────────────────┐ │
│ │ 将五花肉切成3厘米见方   │ │
│ │ 的块，冷水下锅焯水...   │ │
│ └────────────────────────┘ │
│ ⏱️ 05:30                   │
│                            │
│ 🎤 "焯水要多长时间？"      │
│ 🔊 "焯水3-5分钟，看到浮沫  │
│    变少、肉变白就可以了"   │
│                            │
│ [上一步] [🎤] [下一步]     │
└────────────────────────────┘
```

---

### P2-2: 库存智能匹配

**文件**: `lib/features/inventory/data/repositories/ingredient_repository.dart`

**新增**: 同义词匹配
```dart
const ingredientAliases = {
  '西红柿': ['番茄', '圣女果'],
  '土豆': ['马铃薯', '洋芋'],
  // ...
};
```

---

## 五、实施顺序

### 第一阶段: 核心闭环（P0）✅ 已完成
1. ✅ 修复路由不一致
2. ✅ 添加购物入库功能
3. ✅ 添加完成烹饪功能

### 第二阶段: 用户体验（P1）✅ 已完成
4. ✅ 每餐菜品数量设置
5. ✅ 年龄自动关联
6. ✅ 菜谱成品图
7. ✅ 菜单编辑功能

### 第三阶段: 增强功能（P2）✅ 已完成
8. ✅ 烹饪语音助手
9. ✅ 库存智能匹配

---

## 六、修复后的完整闭环

```
┌──────────────────────────────────────────────────────────────┐
│   库存录入 → 菜单生成 → 购物清单 → 确认入库 → 库存增加      │
│      ↑                              ↓                        │
│      └────── 库存扣减 ←── 完成烹饪 ←── 按菜单做菜           │
└──────────────────────────────────────────────────────────────┘
```

---

## 七、关键文件清单

| 功能 | 文件路径 |
|------|----------|
| 路由修复 | `lib/features/recipe/presentation/screens/recipe_list_screen.dart` |
| 购物入库 | `lib/features/shopping/presentation/screens/shopping_list_screen.dart` |
| 完成烹饪 | `lib/features/recipe/presentation/screens/recipe_detail_screen.dart` |
| 菜品数量 | `lib/features/menu/presentation/providers/menu_provider.dart` |
| 年龄关联 | `lib/features/family/presentation/screens/family_detail_screen.dart` |
| 菜谱图片 | `lib/core/services/ai_service.dart` |
| 菜单编辑 | `lib/features/menu/presentation/screens/menu_screen.dart` |
| 语音助手 | `lib/features/cooking/` (新模块) |

---

## 八、验证清单

- [ ] 菜谱卡片点击能跳转详情页
- [ ] 购物勾选后入库，库存数量增加
- [ ] 完成烹饪后，库存数量减少
- [ ] 可设置每餐菜品数量
- [ ] 输入年龄自动计算年龄分组
- [ ] 菜谱列表显示成品图
- [ ] 可替换菜单中的菜品
- [ ] 烹饪模式可语音问答
