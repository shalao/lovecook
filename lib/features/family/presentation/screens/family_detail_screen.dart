import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/family_model.dart';
import '../../data/repositories/family_repository.dart';
import '../providers/family_provider.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有添加成员',
              style: TextStyle(color: Colors.grey.shade600),
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
    int? age = member?.age;
    String? selectedAgeGroup = member?.ageGroup;
    List<String> selectedHealthConditions = member?.healthConditions.toList() ?? [];
    List<String> selectedAllergies = member?.allergies.toList() ?? [];
    List<String> dislikes = member?.dislikes.toList() ?? [];

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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: healthConditionOptions.map((condition) {
                    final isSelected = selectedHealthConditions.contains(condition);
                    return FilterChip(
                      label: Text(condition),
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
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // 过敏源
                const Text(
                  '过敏源',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: commonAllergens.map((allergen) {
                    final isSelected = selectedAllergies.contains(allergen);
                    return FilterChip(
                      label: Text(allergen),
                      selected: isSelected,
                      selectedColor: Colors.red.shade100,
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            selectedAllergies.add(allergen);
                          } else {
                            selectedAllergies.remove(allergen);
                          }
                        });
                      },
                    );
                  }).toList(),
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

                    final newMember = FamilyMemberModel(
                      id: member?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      age: age,
                      ageGroup: selectedAgeGroup,
                      healthConditions: selectedHealthConditions,
                      allergies: selectedAllergies,
                      dislikes: dislikes,
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
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    member.name.substring(0, 1),
                    style: const TextStyle(color: AppColors.primary),
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
                            color: Colors.grey.shade600,
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
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.secondary.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
            if (member.allergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: member.allergies.map((a) {
                  return Chip(
                    label: Text('过敏: $a', style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.red.shade50,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
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
