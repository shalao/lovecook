import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFamily = ref.watch(currentFamilyProvider);
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
            title: '记录',
            children: [
              _buildListTile(
                icon: Icons.calendar_month,
                title: '用餐日历',
                subtitle: '查看和评价每日用餐',
                onTap: () => context.push(AppRoutes.mealCalendar),
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                icon: Icons.history,
                title: '菜单历史',
                onTap: () => context.push(AppRoutes.menu),
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                icon: Icons.bookmark,
                title: '我的收藏',
                onTap: () => context.push(AppRoutes.favorites),
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                icon: Icons.menu_book,
                title: '菜谱库',
                onTap: () => context.push(AppRoutes.recipes),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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

}
