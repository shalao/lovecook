// 饮食相关预设选项
// 用于家庭成员的健康状况、过敏源、口味偏好和饮食禁忌设置

/// 健康状况选项
const healthConditionOptions = [
  // 基础代谢相关
  '控糖',
  '高血压',
  '高血脂',
  '高血糖',
  '脂肪肝',

  // 素食相关
  '素食',
  '纯素',

  // 营养补充
  '低盐饮食',
  '低脂饮食',
  '高蛋白',
  '补钙',
  '补铁',

  // 特殊阶段
  '儿童成长',

  // v1.2: 肾脏疾病
  '肾脏疾病-轻度（低盐）',
  '肾脏疾病-中度（低蛋白）',
  '肾脏疾病-透析期',

  // v1.2: 消化系统
  '胃病-轻度（避辛辣）',
  '胃病-中度（软烂易消化）',
  '肠胃敏感',

  // v1.2: 代谢相关
  '痛风（低嘌呤）',
  '甲状腺问题',
];

/// v1.2: 健身目标选项（细分强度）
const fitnessGoalOptions = [
  // 减脂类
  '减脂-轻度（每周减0.5kg）',
  '减脂-中度（每周减0.75kg）',
  '减脂-极速（每周减1kg）',

  // 增肌类
  '增肌-新手（高蛋白+适量碳水）',
  '增肌-进阶（高蛋白+周期碳水）',
  '增肌-专业（精确宏量控制）',

  // 维持类
  '维持体重',
  '体能提升',
];

/// v1.2: 孕期阶段选项
const pregnancyStageOptions = [
  '备孕期',
  '孕早期（1-12周）',
  '孕中期（13-27周）',
  '孕晚期（28-40周）',
  '哺乳期',
];

/// v1.2: 孕期各阶段营养重点
const pregnancyNutritionFocus = {
  '备孕期': ['叶酸', '铁', '锌'],
  '孕早期（1-12周）': ['叶酸', '维生素B6', '清淡易消化'],
  '孕中期（13-27周）': ['钙', '铁', 'DHA', '蛋白质'],
  '孕晚期（28-40周）': ['钙', '铁', '膳食纤维', '控制体重'],
  '哺乳期': ['钙', '蛋白质', '水分', '催乳食材'],
};

/// v1.2: 健身目标营养配比（用于AI生成参考）
const fitnessNutritionRatios = {
  '减脂-轻度（每周减0.5kg）': {
    'proteinRatio': 0.30,
    'carbRatio': 0.45,
    'fatRatio': 0.25,
    'calorieDeficit': 500,
  },
  '减脂-中度（每周减0.75kg）': {
    'proteinRatio': 0.35,
    'carbRatio': 0.40,
    'fatRatio': 0.25,
    'calorieDeficit': 750,
  },
  '减脂-极速（每周减1kg）': {
    'proteinRatio': 0.40,
    'carbRatio': 0.35,
    'fatRatio': 0.25,
    'calorieDeficit': 1000,
  },
  '增肌-新手（高蛋白+适量碳水）': {
    'proteinRatio': 0.30,
    'carbRatio': 0.50,
    'fatRatio': 0.20,
    'calorieSurplus': 300,
  },
  '增肌-进阶（高蛋白+周期碳水）': {
    'proteinRatio': 0.35,
    'carbRatio': 0.45,
    'fatRatio': 0.20,
    'calorieSurplus': 400,
  },
  '增肌-专业（精确宏量控制）': {
    'proteinRatio': 0.35,
    'carbRatio': 0.45,
    'fatRatio': 0.20,
    'calorieSurplus': 500,
  },
  '维持体重': {
    'proteinRatio': 0.25,
    'carbRatio': 0.50,
    'fatRatio': 0.25,
    'calorieDeficit': 0,
  },
  '体能提升': {
    'proteinRatio': 0.25,
    'carbRatio': 0.55,
    'fatRatio': 0.20,
    'calorieDeficit': 0,
  },
};

/// 年龄分组选项
const ageGroupOptions = [
  '婴幼儿',
  '儿童',
  '青少年',
  '成人',
  '老年',
];

/// 常见过敏源
const commonAllergens = [
  '花生',
  '树坚果', // 杏仁、核桃、腰果等
  '牛奶',
  '鸡蛋',
  '鱼类',
  '甲壳类海鲜', // 虾、蟹等
  '贝类', // 蛤蜊、牡蛎等
  '大豆',
  '小麦',
  '芝麻',
  '芹菜',
  '芥末',
];

/// 口味偏好
const tastePreferences = [
  '清淡',
  '微辣',
  '中辣',
  '重辣',
  '偏甜',
  '偏咸',
  '偏酸',
  '鲜香',
];

/// 饮食禁忌（宗教/文化/个人）
const dietaryRestrictions = [
  '清真',
  '不吃猪肉',
  '不吃牛肉',
  '不吃羊肉',
  '不吃内脏',
  '不吃生食',
];
