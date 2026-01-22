import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/meal_history_model.dart';
import '../providers/history_provider.dart';

class MealCalendarScreen extends ConsumerStatefulWidget {
  const MealCalendarScreen({super.key});

  @override
  ConsumerState<MealCalendarScreen> createState() => _MealCalendarScreenState();
}

class _MealCalendarScreenState extends ConsumerState<MealCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final datesWithHistory = ref.watch(historyProvider.notifier)
        .getDatesWithHistory(year: _focusedDay.year, month: _focusedDay.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('用餐日历'),
      ),
      body: Column(
        children: [
          // 日历
          _buildCalendar(datesWithHistory),

          const Divider(height: 1),

          // 选中日期的详情
          Expanded(
            child: _buildDayDetail(state),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<DateTime> datesWithHistory) {
    return TableCalendar(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        ref.read(historyProvider.notifier).selectDate(selectedDay);
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      eventLoader: (day) {
        // 检查该日期是否有记录
        final hasHistory = datesWithHistory.any((d) =>
            d.year == day.year && d.month == day.month && d.day == day.day);
        return hasHistory ? [true] : [];
      },
      calendarStyle: CalendarStyle(
        markersMaxCount: 1,
        markerDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
      ),
      locale: 'zh_CN',
    );
  }

  Widget _buildDayDetail(HistoryState state) {
    final selectedDate = _selectedDay ?? DateTime.now();
    final dayHistory = state.historyList.where((h) =>
        h.date.year == selectedDate.year &&
        h.date.month == selectedDate.month &&
        h.date.day == selectedDate.day).toList()
      ..sort((a, b) => _mealTypeOrder(a.mealType).compareTo(_mealTypeOrder(b.mealType)));

    if (dayHistory.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: isDark ? AppColors.textTertiaryDark : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '${selectedDate.month}月${selectedDate.day}日暂无用餐记录',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayHistory.length,
      itemBuilder: (context, index) {
        return _MealHistoryCard(
          history: dayHistory[index],
          onRatingChanged: (recipeId, rating) {
            ref.read(historyProvider.notifier).updateRating(
              historyId: dayHistory[index].id,
              recipeId: recipeId,
              rating: rating,
            );
          },
        );
      },
    );
  }

  int _mealTypeOrder(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 0;
      case 'lunch':
        return 1;
      case 'dinner':
        return 2;
      case 'snacks':
        return 3;
      default:
        return 4;
    }
  }
}

class _MealHistoryCard extends StatelessWidget {
  final MealHistoryModel history;
  final Function(String recipeId, int? rating) onRatingChanged;

  const _MealHistoryCard({
    required this.history,
    required this.onRatingChanged,
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
            // 餐次标题
            Row(
              children: [
                _getMealIcon(history.mealType, isDark),
                const SizedBox(width: 8),
                Text(
                  history.mealTypeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : null,
                  ),
                ),
                const Spacer(),
                if (history.hasUnratedRecipes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: isDark ? Border.all(color: Colors.orange.withOpacity(0.4)) : null,
                    ),
                    child: Text(
                      '待评价',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.orange.shade300 : Colors.orange[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 菜品列表
            ...history.recipes.map((recipe) => _RecipeRatingItem(
              recipe: recipe,
              onRatingChanged: (rating) => onRatingChanged(recipe.recipeId, rating),
            )),
          ],
        ),
      ),
    );
  }

  Widget _getMealIcon(String type, bool isDark) {
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
        color = isDark ? Colors.indigo.shade300 : Colors.indigo;
        break;
      case 'snacks':
        icon = Icons.cake_outlined;
        color = Colors.pink;
        break;
      default:
        icon = Icons.restaurant;
        color = isDark ? AppColors.textTertiaryDark : Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _RecipeRatingItem extends StatelessWidget {
  final MealHistoryRecipeModel recipe;
  final Function(int? rating) onRatingChanged;

  const _RecipeRatingItem({
    required this.recipe,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.recipeName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : null,
                  ),
                ),
                if (recipe.rating != null)
                  Row(
                    children: [
                      Text(
                        recipe.ratingEmoji ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.ratingLabel ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 评分按钮
          _buildRatingButtons(context, isDark),
        ],
      ),
    );
  }

  Widget _buildRatingButtons(BuildContext context, bool isDark) {
    final primaryColor = isDark ? AppColors.primaryDark : Theme.of(context).primaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: RatingOptions.options.map((option) {
        final isSelected = recipe.rating == option['value'];
        return GestureDetector(
          onTap: () => onRatingChanged(
            isSelected ? null : option['value'] as int,
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(isDark ? 0.2 : 0.1)
                  : (isDark ? AppColors.inputBackgroundDark : Colors.grey[100]),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: primaryColor)
                  : (isDark ? Border.all(color: AppColors.borderDark) : null),
            ),
            child: Text(
              option['emoji'] as String,
              style: TextStyle(
                fontSize: isSelected ? 18 : 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
