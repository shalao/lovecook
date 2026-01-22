import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../data/models/recommend_settings.dart';
import '../providers/recommend_provider.dart';

class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen> {
  final TextEditingController _moodController = TextEditingController();
  bool _showSettings = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendProvider);

    // 监听状态变化，显示成功/失败提示
    ref.listen<RecommendState>(recommendProvider, (previous, next) {
      // 从加载中变为加载完成
      if (previous?.isInitialLoading == true && next.isInitialLoading == false) {
        if (next.globalError != null) {
          // 显示错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.globalError!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (next.hasAnyRecommendation) {
          // 显示成功
          final dayCount = next.dayPlans.length;
          final totalRecipes = next.dayPlans.fold<int>(
            0,
            (sum, day) =>
                sum +
                day.breakfast.recipes.length +
                day.lunch.recipes.length +
                day.dinner.recipes.length +
                day.snacks.recipes.length,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已生成 $dayCount 天菜单，共 $totalRecipes 道菜'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          // 生成成功后收起设置面板
          setState(() => _showSettings = false);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('今天吃什么'),
        actions: [
          if (state.hasAnyRecommendation)
            IconButton(
              icon: Icon(_showSettings ? Icons.expand_less : Icons.settings),
              onPressed: () => setState(() => _showSettings = !_showSettings),
              tooltip: _showSettings ? '收起设置' : '显示设置',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isAnyLoading
                ? null
                : () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
            tooltip: '重新生成',
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(RecommendState state) {
    if (state.isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在为你生成推荐...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 问候语
          _buildGreeting(),
          const SizedBox(height: 16),

          // 设置面板
          if (_showSettings || !state.hasAnyRecommendation) ...[
            _buildSettingsPanel(state),
            const SizedBox(height: 16),

            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isAnyLoading
                    ? null
                    : () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
                icon: const Icon(Icons.auto_awesome),
                label: Text(state.hasAnyRecommendation ? '重新生成' : '生成推荐'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 错误提示
          if (state.globalError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.globalError!,
                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // 推荐结果
          if (state.hasAnyRecommendation) ...[
            // 显示生成结果统计
            _buildResultSummary(state),
            const SizedBox(height: 16),

            // 多天显示 - 当请求的天数 > 1 或实际返回天数 > 1 时使用多天视图
            if (state.settings.days > 1 || state.dayPlans.length > 1)
              ..._buildMultiDayView(state)
            else
              ..._buildSingleDayView(state),
          ],
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;

    if (hour < 6) {
      greeting = '夜深了';
      icon = Icons.nights_stay;
    } else if (hour < 11) {
      greeting = '早上好';
      icon = Icons.wb_sunny_outlined;
    } else if (hour < 14) {
      greeting = '中午好';
      icon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = '下午好';
      icon = Icons.wb_cloudy;
    } else {
      greeting = '晚上好';
      icon = Icons.nights_stay;
    }

    return Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Text(
          '$greeting，想吃点什么？',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(RecommendState state) {
    final settings = state.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 天数选择
          _buildSectionTitle('📅 天数'),
          const SizedBox(height: 8),
          _buildDaysSelector(settings),
          const SizedBox(height: 16),

          // 餐次选择
          _buildSectionTitle('🍽️ 餐次'),
          const SizedBox(height: 8),
          _buildMealTypeSelector(settings),
          const SizedBox(height: 16),

          // 每餐菜品数
          _buildSectionTitle('🥢 每餐菜品数'),
          const SizedBox(height: 8),
          _buildDishesSelector(settings),
          const SizedBox(height: 16),

          // 心情/口味输入
          _buildSectionTitle('💭 今天的心情/想法（可选）'),
          const SizedBox(height: 8),
          _buildMoodInput(settings),
          const SizedBox(height: 12),

          // 快捷标签
          _buildQuickTags(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : Colors.black87,
      ),
    );
  }

  Widget _buildDaysSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Wrap(
      spacing: 8,
      children: RecommendSettings.availableDays.map((day) {
        final isSelected = settings.days == day;
        return ChoiceChip(
          label: Text(
            '$day天',
            style: TextStyle(
              color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              height: 1.2,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => ref.read(recommendProvider.notifier).updateDays(day),
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
          selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
          side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelPadding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.comfortable,
        );
      }).toList(),
    );
  }

  Widget _buildMealTypeSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    Widget buildMealChip(String emoji, String label, bool selected, Function(bool) onSelected) {
      return FilterChip(
        avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
        label: Text(
          label,
          style: TextStyle(
            color: selected ? (isDark ? Colors.white : AppColors.primary) : textColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
        selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
        side: isDark ? BorderSide(color: selected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
        checkmarkColor: isDark ? Colors.white : AppColors.primary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelPadding: const EdgeInsets.only(left: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.comfortable,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildMealChip('🌅', '早餐', settings.breakfast, (v) => ref.read(recommendProvider.notifier).updateMealType(breakfast: v)),
        buildMealChip('☀️', '午餐', settings.lunch, (v) => ref.read(recommendProvider.notifier).updateMealType(lunch: v)),
        buildMealChip('🌙', '晚餐', settings.dinner, (v) => ref.read(recommendProvider.notifier).updateMealType(dinner: v)),
        buildMealChip('🍰', '甜点', settings.snacks, (v) => ref.read(recommendProvider.notifier).updateMealType(snacks: v)),
      ],
    );
  }

  Widget _buildDishesSelector(RecommendSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: RecommendSettings.availableDishesPerMeal.map((dishes) {
            final isSelected = settings.dishesPerMeal == dishes;
            return ChoiceChip(
              label: Text(
                '$dishes道',
                style: TextStyle(
                  color: isSelected ? (isDark ? Colors.white : AppColors.primary) : textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => ref.read(recommendProvider.notifier).updateDishesPerMeal(dishes),
              elevation: 0,
              pressElevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
              selectedColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
              side: isDark ? BorderSide(color: isSelected ? AppColors.primaryDark : AppColors.borderDark) : BorderSide.none,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelPadding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.comfortable,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '根据家庭人数自动推荐',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textTertiaryDark : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodInput(RecommendSettings settings) {
    // 同步输入框内容
    if (_moodController.text != (settings.moodInput ?? '')) {
      _moodController.text = settings.moodInput ?? '';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : Colors.grey[300]!;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _moodController,
            decoration: InputDecoration(
              hintText: '例如：想吃点清淡的...',
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: settings.moodInput?.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _moodController.clear();
                        ref.read(recommendProvider.notifier).clearMoodInput();
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(recommendProvider.notifier).updateMoodInput(value);
            },
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // 语音按钮
        IconButton(
          icon: const Icon(Icons.mic),
          onPressed: () {
            // TODO: 实现语音输入
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('语音输入功能开发中...')),
            );
          },
          tooltip: '语音输入',
          style: IconButton.styleFrom(
            backgroundColor: inputBgColor,
            foregroundColor: isDark ? AppColors.textPrimaryDark : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 聊聊按钮
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () {
            context.push(AppRoutes.moodChat);
          },
          tooltip: '和AI聊聊',
          style: IconButton.styleFrom(
            backgroundColor: inputBgColor,
            foregroundColor: isDark ? AppColors.textPrimaryDark : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecommendSettings.quickMoodTags.map((tag) {
        return ActionChip(
          label: Text(
            tag,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          onPressed: () {
            ref.read(recommendProvider.notifier).addMoodTag(tag);
          },
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
          side: isDark ? BorderSide(color: AppColors.borderDark) : BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelPadding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.comfortable,
        );
      }).toList(),
    );
  }

  /// 构建结果统计
  Widget _buildResultSummary(RecommendState state) {
    final dayCount = state.dayPlans.length;
    final requestedDays = state.settings.days;
    final totalRecipes = state.dayPlans.fold<int>(
      0,
      (sum, day) =>
          sum +
          day.breakfast.recipes.length +
          day.lunch.recipes.length +
          day.dinner.recipes.length +
          day.snacks.recipes.length,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dayCount >= requestedDays
                  ? '已生成 $dayCount 天菜单，共 $totalRecipes 道菜'
                  : '已生成 $dayCount/$requestedDays 天菜单，共 $totalRecipes 道菜',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (dayCount < requestedDays)
            Tooltip(
              message: '部分天数生成失败，可尝试重新生成',
              child: Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建单天视图
  List<Widget> _buildSingleDayView(RecommendState state) {
    final dayPlan = state.dayPlans.isNotEmpty ? state.dayPlans.first : null;
    final breakfast = dayPlan?.breakfast ?? state.breakfast;
    final lunch = dayPlan?.lunch ?? state.lunch;
    final dinner = dayPlan?.dinner ?? state.dinner;
    final snacks = dayPlan?.snacks ?? state.snacks;

    return [
      // 早餐
      if (state.settings.breakfast && breakfast.recipes.isNotEmpty)
        _buildMealSection(breakfast),

      // 午餐
      if (state.settings.lunch && lunch.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(lunch),
      ],

      // 晚餐
      if (state.settings.dinner && dinner.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(dinner),
      ],

      // 甜点/加餐
      if (state.settings.snacks && snacks.recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _buildMealSection(snacks),
      ],
    ];
  }

  /// 构建多天视图
  List<Widget> _buildMultiDayView(RecommendState state) {
    final widgets = <Widget>[];
    final requestedDays = state.settings.days;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 遍历请求的天数，而不仅仅是返回的天数
    for (int i = 0; i < requestedDays; i++) {
      // 尝试获取对应天的数据
      final dayPlan = i < state.dayPlans.length ? state.dayPlans[i] : null;
      final date = today.add(Duration(days: i));

      if (i > 0) {
        widgets.add(const SizedBox(height: 24));
      }

      // 计算天数标签
      String dayLabel;
      if (i == 0) {
        dayLabel = '今天';
      } else if (i == 1) {
        dayLabel = '明天';
      } else if (i == 2) {
        dayLabel = '后天';
      } else {
        dayLabel = '第${i + 1}天';
      }
      final dateLabel = '${date.month}月${date.day}日';

      // 日期标题
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dayPlan != null
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (dayPlan == null) ...[
                const Spacer(),
                Text(
                  '未生成',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      // 如果没有该天的数据，显示提示
      if (dayPlan == null) {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '该天菜单未能生成，请尝试重新生成',
                    style: TextStyle(color: Colors.orange[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 当天的餐次
      bool hasAnyMeal = false;

      if (state.settings.breakfast && dayPlan.breakfast.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.breakfast, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.lunch && dayPlan.lunch.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.lunch, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.dinner && dayPlan.dinner.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.dinner, showRefresh: false));
        widgets.add(const SizedBox(height: 16));
        hasAnyMeal = true;
      }

      if (state.settings.snacks && dayPlan.snacks.recipes.isNotEmpty) {
        widgets.add(_buildMealSection(dayPlan.snacks, showRefresh: false));
        hasAnyMeal = true;
      }

      // 如果该天没有任何餐次数据
      if (!hasAnyMeal) {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '该天暂无推荐菜品',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildMealSection(MealRecommend meal, {bool showRefresh = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            _getMealIcon(meal.type),
            const SizedBox(width: 8),
            Text(
              meal.typeName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (showRefresh) ...[
              if (meal.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () =>
                      ref.read(recommendProvider.notifier).refreshMeal(meal.type),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('换一换'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // 菜品列表
        if (meal.error != null)
          _buildErrorCard(meal.error!)
        else if (meal.recipes.isEmpty)
          _buildEmptyCard()
        else
          _buildRecipeCards(meal.recipes),
      ],
    );
  }

  Widget _getMealIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'breakfast':
        icon = Icons.wb_sunny_outlined;
        color = Colors.orange;
        break;
      case 'lunch':
        icon = Icons.wb_sunny;
        color = Colors.amber;
        break;
      case 'dinner':
        icon = Icons.nights_stay_outlined;
        color = Colors.indigo;
        break;
      case 'snacks':
        icon = Icons.cake_outlined;
        color = Colors.pink;
        break;
      default:
        icon = Icons.restaurant;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '暂无推荐',
          style: TextStyle(color: isDark ? AppColors.textTertiaryDark : Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildRecipeCards(List<RecipeModel> recipes) {
    // 使用列表布局替代网格，更清晰
    return Column(
      children: recipes.map((recipe) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RecipeCard(recipe: recipe),
      )).toList(),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final RecipeModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recommendProvider.notifier);
    final hasAllIngredients = notifier.hasAllIngredients(recipe);
    final missingIngredients = notifier.getMissingIngredients(recipe);
    final totalTime = recipe.prepTime + recipe.cookTime;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('${AppRoutes.recipes}/${recipe.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧色块标识
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: _getColorForRecipe(recipe),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 菜名
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 时间和标签
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$totalTime分钟',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (recipe.difficulty != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recipe.difficulty!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 右侧状态
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasAllIngredients)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: Colors.green[600]),
                        const SizedBox(width: 2),
                        Text(
                          '齐全',
                          style: TextStyle(fontSize: 11, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '缺${missingIngredients.length}样',
                      style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForRecipe(RecipeModel recipe) {
    final hash = recipe.name.hashCode;
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF607D8B),
    ];
    return colors[hash.abs() % colors.length];
  }
}
