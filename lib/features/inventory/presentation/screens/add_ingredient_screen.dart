import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../providers/inventory_provider.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  ConsumerState<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  int _currentStep = 0; // 0: 选择方式, 1: 手动输入表单

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 0 ? '添加食材' : '手动输入'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 0) {
              context.pop();
            } else {
              setState(() => _currentStep = 0);
            }
          },
        ),
      ),
      body: _currentStep == 0 ? _buildMethodSelection() : const _ManualInputForm(),
    );
  }

  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddMethodCard(
            icon: Icons.camera_alt,
            title: '拍照识别',
            description: '拍摄冰箱或储物柜照片，AI 自动识别食材',
            color: AppColors.primary,
            onTap: () => _showComingSoon(context, '拍照识别'),
          ),
          const SizedBox(height: 16),
          _AddMethodCard(
            icon: Icons.mic,
            title: '语音输入',
            description: '说出食材名称和数量，如"三根胡萝卜"',
            color: AppColors.secondary,
            onTap: () => _showComingSoon(context, '语音输入'),
          ),
          const SizedBox(height: 16),
          _AddMethodCard(
            icon: Icons.edit,
            title: '手动输入',
            description: '手动输入食材名称和数量',
            color: AppColors.info,
            onTap: () => setState(() => _currentStep = 1),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 功能即将上线'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AddMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AddMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手动输入表单
class _ManualInputForm extends ConsumerStatefulWidget {
  const _ManualInputForm();

  @override
  ConsumerState<_ManualInputForm> createState() => _ManualInputFormState();
}

class _ManualInputFormState extends ConsumerState<_ManualInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  String? _selectedCategory;
  String _selectedUnit = '个';
  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFamily = ref.watch(currentFamilyProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 食材名称
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '食材名称 *',
              hintText: '如：胡萝卜、鸡蛋、牛奶',
              prefixIcon: Icon(Icons.restaurant),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入食材名称';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 类别选择
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: '类别',
              prefixIcon: Icon(Icons.category),
            ),
            items: ingredientCategories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
          const SizedBox(height: 16),

          // 数量和单位
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: '数量 *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入数量';
                    }
                    final num = double.tryParse(value);
                    if (num == null || num <= 0) {
                      return '请输入有效数量';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                  ),
                  items: ingredientUnits.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedUnit = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 保质期
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('保质期至'),
            subtitle: Text(
              _expiryDate != null
                  ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                  : '未设置',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_expiryDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _expiryDate = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectExpiryDate,
                ),
              ],
            ),
          ),
          const Divider(),

          // 快捷保质期按钮
          const Text(
            '快捷设置保质期',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickExpiryChip(
                label: '3天',
                onTap: () => _setQuickExpiry(3),
              ),
              _QuickExpiryChip(
                label: '7天',
                onTap: () => _setQuickExpiry(7),
              ),
              _QuickExpiryChip(
                label: '14天',
                onTap: () => _setQuickExpiry(14),
              ),
              _QuickExpiryChip(
                label: '1个月',
                onTap: () => _setQuickExpiry(30),
              ),
              _QuickExpiryChip(
                label: '3个月',
                onTap: () => _setQuickExpiry(90),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 提交按钮
          ElevatedButton(
            onPressed: _isSubmitting || currentFamily == null
                ? null
                : () => _submitForm(currentFamily.id),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('添加食材'),
          ),

          if (currentFamily == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '请先创建家庭才能添加食材',
                style: TextStyle(color: Colors.red.shade400),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  void _setQuickExpiry(int days) {
    setState(() {
      _expiryDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _submitForm(String familyId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final quantity = double.parse(_quantityController.text);
      final notifier = ref.read(inventoryProvider.notifier);

      final ingredient = ref.read(addIngredientFormProvider.notifier).toIngredient(familyId);
      // 直接使用表单数据创建
      await notifier.addIngredient(
        ingredient.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          quantity: quantity,
          unit: _selectedUnit,
          expiryDate: _expiryDate,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('食材添加成功'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// 快捷保质期按钮
class _QuickExpiryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickExpiryChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
