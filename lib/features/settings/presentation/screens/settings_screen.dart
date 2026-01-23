import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recommend/data/models/recommend_settings.dart';

/// 避重天数设置 Provider
final avoidRecentDaysProvider = StateNotifierProvider<AvoidRecentDaysNotifier, int>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AvoidRecentDaysNotifier(storage);
});

class AvoidRecentDaysNotifier extends StateNotifier<int> {
  final StorageService _storage;

  AvoidRecentDaysNotifier(this._storage) : super(7) {
    _load();
  }

  void _load() {
    state = _storage.settingsBox.get('avoidRecentDays', defaultValue: 7) as int;
  }

  Future<void> setDays(int days) async {
    await _storage.settingsBox.put('avoidRecentDays', days);
    state = days;
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final avoidDays = ref.watch(avoidRecentDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _SettingsSection(
            title: '家庭',
            children: [
              ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('家庭管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.family),
              ),
            ],
          ),
          _SettingsSection(
            title: '偏好设置',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('语言'),
                subtitle: Text(locale.languageCode == 'zh' ? '中文' : 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ],
          ),
          _SettingsSection(
            title: '推荐设置',
            children: [
              ListTile(
                leading: const Icon(Icons.history_toggle_off),
                title: const Text('避免重复推荐天数'),
                subtitle: Text('$avoidDays 天内不重复推荐相同菜品'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAvoidDaysDialog(context, ref, avoidDays),
              ),
            ],
          ),
          _SettingsSection(
            title: '数据管理',
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('备份与恢复'),
                subtitle: const Text('数据存储在本地浏览器'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackupInfoDialog(context),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('清除所有数据', style: TextStyle(color: AppColors.error)),
                onTap: () => _showClearDataDialog(context, ref),
              ),
            ],
          ),
          _SettingsSection(
            title: '关于',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('版本'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('隐私政策'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPrivacyPolicyDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: supportedLocales.map((locale) {
            final name = locale.languageCode == 'zh' ? '中文' : 'English';
            return ListTile(
              title: Text(name),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(locale);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAvoidDaysDialog(BuildContext context, WidgetRef ref, int currentDays) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('避免重复推荐天数'),
        content: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统会避免推荐这段时间内吃过的菜品',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ...RecommendSettings.availableAvoidRecentDays.map((days) {
                  return RadioListTile<int>(
                    title: Text('$days 天'),
                    value: days,
                    groupValue: currentDays,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(avoidRecentDaysProvider.notifier).setDays(value);
                        Navigator.pop(context);
                      }
                    },
                  );
                }),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showBackupInfoDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据备份说明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              context,
              Icons.storage,
              '本地存储',
              '所有数据存储在浏览器的 IndexedDB 中',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.devices,
              '跨设备同步',
              '目前不支持跨设备同步，数据仅在当前浏览器可用',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.warning_amber,
              '注意事项',
              '清除浏览器数据会导致应用数据丢失',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputBackgroundDark : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '云端备份功能正在开发中，敬请期待',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              const SizedBox(width: 8),
              const Text('清除所有数据'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '此操作将永久删除以下所有数据：',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDeleteItem('家庭信息和成员数据'),
              _buildDeleteItem('所有库存食材'),
              _buildDeleteItem('所有菜谱'),
              _buildDeleteItem('菜单计划和历史'),
              _buildDeleteItem('购物清单'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '此操作不可撤销！',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '请输入「删除」以确认：',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  hintText: '输入「删除」',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: confirmController.text == '删除'
                  ? () async {
                      Navigator.pop(context);
                      await _clearAllData(context, ref);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认删除'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.remove, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在清除数据...'),
          ],
        ),
      ),
    );

    try {
      final storage = ref.read(storageServiceProvider);

      // 清除所有 Hive boxes
      await storage.familiesBox.clear();
      await storage.ingredientsBox.clear();
      await storage.recipesBox.clear();
      await storage.mealPlansBox.clear();
      await storage.shoppingListsBox.clear();
      await storage.mealHistoryBox.clear();
      await storage.settingsBox.clear();

      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所有数据已清除，请重新启动应用'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私政策'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPolicySection(
                context,
                '数据收集',
                '本应用不会收集或上传您的任何个人数据。所有数据（包括家庭信息、食材库存、菜谱等）均存储在您的本地设备上。',
              ),
              const SizedBox(height: 16),
              _buildPolicySection(
                context,
                'AI 服务',
                '当您使用 AI 功能（如生成菜单、识别食材）时，相关数据会通过安全的代理服务发送到 AI 服务提供商（如 OpenAI）进行处理。请参阅相应服务提供商的隐私政策了解其数据处理方式。',
              ),
              const SizedBox(height: 16),
              _buildPolicySection(
                context,
                '数据安全',
                '您的所有本地数据均存储在本设备上，不会被上传到任何服务器。AI 功能通过安全代理提供，无需您配置任何密钥。',
              ),
              const SizedBox(height: 16),
              _buildPolicySection(
                context,
                '第三方服务',
                '本应用可能使用第三方服务（如图片加载）。这些服务可能有其自己的隐私政策。',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '最后更新：2024年1月\n如有任何隐私相关问题，请联系开发者。',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
