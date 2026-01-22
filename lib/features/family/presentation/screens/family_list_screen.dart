import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/family_model.dart';
import '../../data/repositories/family_repository.dart';
import '../providers/family_provider.dart';

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(familyListProvider);
    final currentFamily = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭管理'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.families.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildFamilyList(context, ref, state.families, currentFamily),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFamilyDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建家庭'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.family_restroom,
            size: 80,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有创建家庭',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮创建您的第一个家庭',
            style: TextStyle(
              color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateFamilyDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('创建家庭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyList(
    BuildContext context,
    WidgetRef ref,
    List<FamilyModel> families,
    FamilyModel? currentFamily,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primary;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: families.length,
      itemBuilder: (context, index) {
        final family = families[index];
        final isCurrent = currentFamily?.id == family.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('${AppRoutes.family}/${family.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isCurrent
                        ? primaryColor.withOpacity(isDark ? 0.25 : 0.2)
                        : (isDark ? AppColors.inputBackgroundDark : Colors.grey.shade200),
                    child: Text(
                      family.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? primaryColor : (isDark ? AppColors.textSecondaryDark : Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              family.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimaryDark : null,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isDark ? Border.all(color: primaryColor.withOpacity(0.4)) : null,
                                ),
                                child: Text(
                                  '当前',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${family.members.length} 位成员',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCurrent)
                    TextButton(
                      onPressed: () {
                        ref.read(currentFamilyProvider.notifier).setCurrentFamily(family.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换到 ${family.name}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('切换'),
                    ),
                  Icon(Icons.chevron_right, color: isDark ? AppColors.textSecondaryDark : null),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建家庭'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '家庭名称',
            hintText: '如：我的家',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入家庭名称'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final family = FamilyModel.create(
                name: name,
                members: [],
                mealSettings: MealSettingsModel(),
              );

              await ref.read(familyListProvider.notifier).createFamily(family);

              // 如果是第一个家庭，自动设为当前家庭
              final families = ref.read(familyListProvider).families;
              if (families.length == 1) {
                await ref.read(currentFamilyProvider.notifier).setCurrentFamily(family.id);
              }

              if (context.mounted) {
                Navigator.pop(context);
                // 进入详情页添加成员
                context.push('${AppRoutes.family}/${family.id}');
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
