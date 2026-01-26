import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/family_model.dart';
import '../../data/repositories/family_repository.dart';
import '../providers/family_provider.dart'; // 包含 dietary_options 的导出

class FamilyDetailScreen extends ConsumerStatefulWidget {
  final String familyId;

  const FamilyDetailScreen({
    super.key,
    required this.familyId,
  });

  @override
  ConsumerState<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends ConsumerState<FamilyDetailScreen> {
  FamilyModel? _family;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  void _loadFamily() {
    final repository = ref.read(familyRepositoryProvider);
    try {
      _family = repository.getFamilyById(widget.familyId);
    } catch (_) {
      // Family not found
    }
  }

  @override
  Widget build(BuildContext context) {
    // 重新加载以获取最新数据
    _loadFamily();

    if (_family == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('家庭详情')),
        body: const Center(child: Text('家庭不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_family!.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _showRenameDialog();
                  break;
                case 'delete':
                  _showDeleteConfirmation();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('重命名'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除家庭', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 家庭成员
            _buildSectionHeader('家庭成员', onAdd: _showAddMemberDialog),
            const SizedBox(height: 12),
            if (_family!.members.isEmpty)
              _buildEmptyMembersCard()
            else
              ..._family!.members.asMap().entries.map((entry) {
                return _MemberCard(
                  member: entry.value,
                  onEdit: () => _showEditMemberDialog(entry.key, entry.value),
                  onDelete: () => _confirmDeleteMember(entry.key, entry.value),
                );
              }),

            const SizedBox(height: 24),

            // 餐次设置
            _buildSectionHeader('餐次设置'),
            const SizedBox(height: 12),
            _buildMealSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
      ],
    );
  }

  Widget _buildEmptyMembersCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              size: 48,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有添加成员',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddMemberDialog,
              child: const Text('添加成员'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSettingsCard() {
    final settings = _family!.mealSettings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MealSettingRow(
              label: '早餐',
              icon: '🌅',
              value: settings.breakfast,
              onChanged: (value) => _updateMealSetting(breakfast: value),
            ),
            const Divider(),
            _MealSettingRow(
              label: '午餐',
              icon: '☀️',
              value: settings.lunch,
              onChanged: (value) => _updateMealSetting(lunch: value),
            ),
            const Divider(),
            _MealSettingRow(
              label: '晚餐',
              icon: '🌙',
              value: settings.dinner,
              onChanged: (value) => _updateMealSetting(dinner: value),
            ),
            const Divider(),
            _MealSettingRow(
              label: '加餐',
              icon: '🍪',
              value: settings.snacks,
              onChanged: (value) => _updateMealSetting(snacks: value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMealSetting({
    bool? breakfast,
    bool? lunch,
    bool? dinner,
    bool? snacks,
  }) async {
    final repository = ref.read(familyRepositoryProvider);
    final newSettings = MealSettingsModel(
      breakfast: breakfast ?? _family!.mealSettings.breakfast,
      lunch: lunch ?? _family!.mealSettings.lunch,
      dinner: dinner ?? _family!.mealSettings.dinner,
      snacks: snacks ?? _family!.mealSettings.snacks,
      defaultPlanDays: _family!.mealSettings.defaultPlanDays,
    );
    await repository.updateMealSettings(_family!.id, newSettings);
    setState(() => _loadFamily());
  }

  /// v1.2: 获取健身目标的营养提示
  String _getFitnessNutritionHint(String goal) {
    final ratios = fitnessNutritionRatios[goal];
    if (ratios == null) return '';

    final protein = ((ratios['proteinRatio'] as double) * 100).toInt();
    final carb = ((ratios['carbRatio'] as double) * 100).toInt();
    final fat = ((ratios['fatRatio'] as double) * 100).toInt();

    final deficit = ratios['calorieDeficit'] as int?;
    final surplus = ratios['calorieSurplus'] as int?;

    String calorieInfo = '';
    if (deficit != null && deficit > 0) {
      calorieInfo = '，热量缺口 ${deficit}kcal';
    } else if (surplus != null && surplus > 0) {
      calorieInfo = '，热量盈余 ${surplus}kcal';
    }

    return '蛋白$protein% 碳水$carb% 脂肪$fat%$calorieInfo';
  }

  /// v1.2: 获取孕期阶段的营养提示
  String _getPregnancyNutritionHint(String stage) {
    final focus = pregnancyNutritionFocus[stage];
    if (focus == null || focus.isEmpty) return '';
    return '重点补充：${focus.join('、')}';
  }

  void _showAddMemberDialog() {
    _showMemberDialog(null, null);
  }

  void _showEditMemberDialog(int index, FamilyMemberModel member) {
    _showMemberDialog(index, member);
  }

  void _showMemberDialog(int? index, FamilyMemberModel? member) {
    final nameController = TextEditingController(text: member?.name ?? '');
    final ageController = TextEditingController(
      text: member?.age != null ? member!.age.toString() : '',
    );
    final notesController = TextEditingController(text: member?.notes ?? '');
    int? age = member?.age;
    String? selectedAgeGroup = member?.ageGroup;
    List<String> selectedHealthConditions = member?.healthConditions.toList() ?? [];
    List<String> selectedAllergies = member?.allergies.toList() ?? [];
    List<String> selectedTastePrefs = <String>[];
    List<String> selectedRestrictions = <String>[];
    // v1.2: 健身目标和孕期阶段
    String? selectedFitnessGoal = member?.fitnessGoal;
    String? selectedPregnancyStage = member?.pregnancyStage;

    // 从 dislikes 中解析已有的口味偏好和饮食禁忌
    final existingDislikes = member?.dislikes.toList() ?? [];
    for (final item in existingDislikes) {
      if (tastePreferences.contains(item)) {
        selectedTastePrefs.add(item);
      } else if (dietaryRestrictions.contains(item)) {
        selectedRestrictions.add(item);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      member == null ? '添加成员' : '编辑成员',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 姓名
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名 *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // 年龄（输入后自动计算年龄分组）
                TextField(
                  controller: ageController,
                  decoration: InputDecoration(
                    labelText: '年龄',
                    prefixIcon: const Icon(Icons.calendar_today),
                    helperText: selectedAgeGroup != null
                        ? '自动识别为: $selectedAgeGroup'
                        : '输入年龄自动计算年龄分组',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsedAge = int.tryParse(value);
                    setSheetState(() {
                      age = parsedAge;
                      if (parsedAge != null && parsedAge > 0) {
                        selectedAgeGroup = FamilyMemberModel.getAgeGroup(parsedAge);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 年龄分组（可手动覆盖）
                DropdownButtonFormField<String>(
                  value: selectedAgeGroup,
                  decoration: const InputDecoration(
                    labelText: '年龄分组',
                    prefixIcon: Icon(Icons.cake),
                    helperText: '可手动选择或由年龄自动计算',
                  ),
                  items: ageGroupOptions.map((group) {
                    return DropdownMenuItem(value: group, child: Text(group));
                  }).toList(),
                  onChanged: (value) {
                    setSheetState(() => selectedAgeGroup = value);
                  },
                ),
                const SizedBox(height: 24),

                // 健康状况
                const Text(
                  '健康状况',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: healthConditionOptions.map((condition) {
                        final isSelected = selectedHealthConditions.contains(condition);
                        return FilterChip(
                          label: Text(
                            condition,
                            style: TextStyle(
                              color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedHealthConditions.add(condition);
                              } else {
                                selectedHealthConditions.remove(condition);
                              }
                            });
                          },
                          elevation: 0,
                          pressElevation: 0,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
                          selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
                          side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
                          checkmarkColor: isDark ? Colors.white : AppColors.primary,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // v1.2: 健身目标（单选下拉）
                const Text(
                  '健身目标',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedFitnessGoal,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.fitness_center),
                    hintText: '选择健身目标（可选）',
                    helperText: selectedFitnessGoal != null
                        ? _getFitnessNutritionHint(selectedFitnessGoal!)
                        : '选择后 AI 会根据目标调整营养配比',
                    helperMaxLines: 2,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无健身目标'),
                    ),
                    ...fitnessGoalOptions.map((goal) {
                      return DropdownMenuItem(value: goal, child: Text(goal));
                    }),
                  ],
                  onChanged: (value) {
                    setSheetState(() => selectedFitnessGoal = value);
                  },
                ),
                const SizedBox(height: 24),

                // v1.2: 孕期阶段（单选下拉）
                const Text(
                  '孕期阶段',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedPregnancyStage,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.pregnant_woman),
                    hintText: '选择孕期阶段（可选）',
                    helperText: selectedPregnancyStage != null
                        ? _getPregnancyNutritionHint(selectedPregnancyStage!)
                        : '选择后 AI 会推荐该阶段所需营养',
                    helperMaxLines: 2,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('非孕期'),
                    ),
                    ...pregnancyStageOptions.map((stage) {
                      return DropdownMenuItem(value: stage, child: Text(stage));
                    }),
                  ],
                  onChanged: (value) {
                    setSheetState(() => selectedPregnancyStage = value);
                  },
                ),
                const SizedBox(height: 24),

                // 过敏源
                const Text(
                  '过敏源',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: commonAllergens.map((allergen) {
                        final isSelected = selectedAllergies.contains(allergen);
                        return FilterChip(
                          label: Text(
                            allergen,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                  : textColor,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedAllergies.add(allergen);
                              } else {
                                selectedAllergies.remove(allergen);
                              }
                            });
                          },
                          elevation: 0,
                          pressElevation: 0,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
                          side: isDark ? BorderSide(color: isSelected ? Colors.red.shade700 : AppColors.borderDark) : BorderSide.none,
                          checkmarkColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 口味偏好
                const Text(
                  '口味偏好',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tastePreferences.map((pref) {
                        final isSelected = selectedTastePrefs.contains(pref);
                        return FilterChip(
                          label: Text(
                            pref,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.orange.shade300 : Colors.orange.shade700)
                                  : textColor,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade100,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedTastePrefs.add(pref);
                              } else {
                                selectedTastePrefs.remove(pref);
                              }
                            });
                          },
                          elevation: 0,
                          pressElevation: 0,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
                          side: isDark ? BorderSide(color: isSelected ? Colors.orange.shade700 : AppColors.borderDark) : BorderSide.none,
                          checkmarkColor: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 饮食禁忌
                const Text(
                  '饮食禁忌',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dietaryRestrictions.map((restriction) {
                        final isSelected = selectedRestrictions.contains(restriction);
                        return FilterChip(
                          label: Text(
                            restriction,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.purple.shade300 : Colors.purple.shade700)
                                  : textColor,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade100,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedRestrictions.add(restriction);
                              } else {
                                selectedRestrictions.remove(restriction);
                              }
                            });
                          },
                          elevation: 0,
                          pressElevation: 0,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
                          side: isDark ? BorderSide(color: isSelected ? Colors.purple.shade700 : AppColors.borderDark) : BorderSide.none,
                          checkmarkColor: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 备注说明
                const Text(
                  '备注说明',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: '如：糖尿病需严格控糖、痛风避免高嘌呤食物...',
                    prefixIcon: Icon(Icons.notes),
                    helperText: '填写具体的疾病或饮食注意事项，AI 生成菜谱时会参考',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 32),

                // 保存按钮
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入姓名')),
                      );
                      return;
                    }

                    // 合并口味偏好和饮食禁忌到 dislikes
                    final combinedDislikes = [
                      ...selectedTastePrefs,
                      ...selectedRestrictions,
                    ];

                    // 获取备注内容
                    final notes = notesController.text.trim();

                    final newMember = FamilyMemberModel(
                      id: member?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      age: age,
                      ageGroup: selectedAgeGroup,
                      healthConditions: selectedHealthConditions,
                      allergies: selectedAllergies,
                      dislikes: combinedDislikes,
                      notes: notes.isEmpty ? null : notes,
                      fitnessGoal: selectedFitnessGoal,
                      pregnancyStage: selectedPregnancyStage,
                    );

                    final repository = ref.read(familyRepositoryProvider);
                    if (index == null) {
                      await repository.addMember(_family!.id, newMember);
                    } else {
                      await repository.updateMember(_family!.id, member!.id, newMember);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() => _loadFamily());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(member == null ? '添加成员' : '保存修改'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMember(int index, FamilyMemberModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除成员'),
        content: Text('确定要删除"${member.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final repository = ref.read(familyRepositoryProvider);
              await repository.removeMember(_family!.id, member.id);
              setState(() => _loadFamily());
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _family!.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名家庭'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '家庭名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              _family!.name = name;
              _family!.updatedAt = DateTime.now();
              await _family!.save();

              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除家庭'),
        content: Text('确定要删除"${_family!.name}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(familyListProvider.notifier).deleteFamily(_family!.id);
              if (mounted) {
                context.pop();
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 成员卡片
class _MemberCard extends StatelessWidget {
  final FamilyMemberModel member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark
                      ? AppColors.primaryDark.withOpacity(0.2)
                      : AppColors.primary.withOpacity(0.1),
                  child: Text(
                    member.name.substring(0, 1),
                    style: TextStyle(
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.ageGroup != null)
                        Text(
                          member.ageGroup!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (member.healthConditions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: member.healthConditions.map((c) {
                  return Chip(
                    label: Text(
                      c,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: isDark
                        ? AppColors.secondaryDark.withOpacity(0.2)
                        : AppColors.secondary.withOpacity(0.1),
                    side: isDark ? BorderSide(color: AppColors.secondaryDark.withOpacity(0.5)) : BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  );
                }).toList(),
              ),
            ],
            // v1.2: 健身目标
            if (member.fitnessGoal != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(
                  Icons.fitness_center,
                  size: 14,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                ),
                label: Text(
                  member.fitnessGoal!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                  ),
                ),
                backgroundColor: isDark
                    ? Colors.green.shade900.withOpacity(0.3)
                    : Colors.green.shade50,
                side: isDark ? BorderSide(color: Colors.green.shade700) : BorderSide.none,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
              ),
            ],
            // v1.2: 孕期阶段
            if (member.pregnancyStage != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(
                  Icons.pregnant_woman,
                  size: 14,
                  color: isDark ? Colors.pink.shade300 : Colors.pink.shade700,
                ),
                label: Text(
                  member.pregnancyStage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.pink.shade300 : Colors.pink.shade700,
                  ),
                ),
                backgroundColor: isDark
                    ? Colors.pink.shade900.withOpacity(0.3)
                    : Colors.pink.shade50,
                side: isDark ? BorderSide(color: Colors.pink.shade700) : BorderSide.none,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
              ),
            ],
            if (member.allergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: member.allergies.map((a) {
                  return Chip(
                    label: Text(
                      '过敏: $a',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                    ),
                    backgroundColor: isDark
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                    side: isDark ? BorderSide(color: Colors.red.shade700) : BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  );
                }).toList(),
              ),
            ],
            // 显示口味偏好和饮食禁忌
            if (member.dislikes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: member.dislikes.map((d) {
                  // 判断是口味偏好还是饮食禁忌
                  final isTastePref = tastePreferences.contains(d);
                  final isRestriction = dietaryRestrictions.contains(d);

                  Color chipColor;
                  String prefix;
                  if (isTastePref) {
                    chipColor = isDark ? Colors.orange.shade300 : Colors.orange.shade700;
                    prefix = '';
                  } else if (isRestriction) {
                    chipColor = isDark ? Colors.purple.shade300 : Colors.purple.shade700;
                    prefix = '';
                  } else {
                    chipColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
                    prefix = '';
                  }

                  return Chip(
                    label: Text(
                      '$prefix$d',
                      style: TextStyle(
                        fontSize: 12,
                        color: chipColor,
                      ),
                    ),
                    backgroundColor: isDark
                        ? (isTastePref
                            ? Colors.orange.shade900.withOpacity(0.3)
                            : isRestriction
                                ? Colors.purple.shade900.withOpacity(0.3)
                                : Colors.grey.shade800)
                        : (isTastePref
                            ? Colors.orange.shade50
                            : isRestriction
                                ? Colors.purple.shade50
                                : Colors.grey.shade100),
                    side: isDark
                        ? BorderSide(color: isTastePref
                            ? Colors.orange.shade700
                            : isRestriction
                                ? Colors.purple.shade700
                                : Colors.grey.shade600)
                        : BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  );
                }).toList(),
              ),
            ],
            // 显示备注
            if (member.notes != null && member.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.shade900.withOpacity(0.2)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 餐次设置行
class _MealSettingRow extends StatelessWidget {
  final String label;
  final String icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MealSettingRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
