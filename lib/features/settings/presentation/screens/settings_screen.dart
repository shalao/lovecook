import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/services/ai_service.dart';
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
    final aiConfig = ref.watch(aiConfigProvider);
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
            title: 'AI 设置',
            children: [
              ListTile(
                leading: Icon(
                  Icons.key,
                  color: aiConfig.isConfigured ? Colors.green : Colors.orange,
                ),
                title: const Text('API 密钥配置'),
                subtitle: Text(
                  aiConfig.isConfigured ? '已配置 (${aiConfig.model})' : '未配置',
                  style: TextStyle(
                    color: aiConfig.isConfigured ? Colors.green : Colors.orange,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showApiKeyDialog(context, ref, aiConfig),
              ),
            ],
          ),
          _SettingsSection(
            title: '数据管理',
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('备份与恢复'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to backup settings
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('清除所有数据', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  // TODO: Show clear data confirmation
                },
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
                onTap: () {
                  // TODO: Show privacy policy
                },
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

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, AIConfig currentConfig) {
    final apiKeyController = TextEditingController(text: currentConfig.apiKey);
    final baseUrlController = TextEditingController(text: currentConfig.baseUrl);
    String selectedModel = currentConfig.model;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('OpenAI API 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API 密钥',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'API 地址',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '模型',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedModel,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o')),
                    DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o Mini')),
                    DropdownMenuItem(value: 'gpt-4-turbo', child: Text('GPT-4 Turbo')),
                    DropdownMenuItem(value: 'gpt-3.5-turbo', child: Text('GPT-3.5 Turbo')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedModel = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      '提示: 使用第三方 API 代理时，请修改 API 地址',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final notifier = ref.read(aiConfigProvider.notifier);
                await notifier.setApiKey(apiKeyController.text.trim());
                await notifier.setBaseUrl(baseUrlController.text.trim());
                await notifier.setModel(selectedModel);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API 配置已保存')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
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
