import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFamily = ref.watch(currentFamilyProvider);
    final aiConfig = ref.watch(aiConfigProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        children: [
          // 家庭信息卡片
          _buildFamilyCard(context, currentFamily),

          const SizedBox(height: 16),

          // 功能列表
          _buildSection(
            context,
            title: '家庭',
            children: [
              _buildListTile(
                icon: Icons.family_restroom,
                title: '家庭管理',
                subtitle: currentFamily?.name ?? '未创建家庭',
                onTap: () => context.push(AppRoutes.family),
              ),
            ],
          ),

          _buildSection(
            context,
            title: '历史记录',
            children: [
              _buildListTile(
                icon: Icons.history,
                title: '菜单历史',
                onTap: () => context.push(AppRoutes.menu),
              ),
            ],
          ),

          _buildSection(
            context,
            title: '设置',
            children: [
              _buildListTile(
                icon: Icons.language,
                title: '语言',
                subtitle: locale.languageCode == 'zh' ? '中文' : 'English',
                onTap: () => _showLanguageDialog(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                icon: Icons.key,
                iconColor: aiConfig.isConfigured ? Colors.green : Colors.orange,
                title: 'API 密钥配置',
                subtitle: aiConfig.isConfigured ? '已配置 (${aiConfig.model})' : '未配置',
                subtitleColor: aiConfig.isConfigured ? Colors.green : Colors.orange,
                onTap: () => _showApiKeyDialog(context, ref, aiConfig),
              ),
            ],
          ),

          _buildSection(
            context,
            title: '关于',
            children: [
              _buildListTile(
                icon: Icons.info_outline,
                title: '版本',
                subtitle: '1.0.0',
                showArrow: false,
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                icon: Icons.description_outlined,
                title: '隐私政策',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, dynamic family) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family?.name ?? '创建您的家庭',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  family != null
                      ? '${family.members.length} 位成员'
                      : '点击开始设置',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? subtitleColor,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: subtitleColor),
            )
          : null,
      trailing: showArrow ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
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
                Text(
                  '提示: 使用第三方 API 代理时，请修改 API 地址',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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
