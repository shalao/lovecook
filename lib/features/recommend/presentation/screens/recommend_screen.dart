import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../providers/recommend_provider.dart';

class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen> {
  @override
  void initState() {
    super.initState();
    // 首次加载时自动生成推荐
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(recommendProvider);
      if (!state.hasAnyRecommendation && !state.isAnyLoading) {
        ref.read(recommendProvider.notifier).generateTodayRecommendations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今天吃什么'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isAnyLoading
                ? null
                : () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
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
            Text('正在为你生成今日推荐...'),
          ],
        ),
      );
    }

    if (state.globalError != null && !state.hasAnyRecommendation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                state.globalError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(recommendProvider.notifier).generateTodayRecommendations(),
                icon: const Icon(Icons.refresh),
                label: const Text('重新生成'),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasAnyRecommendation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 24),
              Text(
                '点击下方按钮，获取今日推荐',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(recommendProvider.notifier).generateTodayRecommendations(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成今日推荐'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(recommendProvider.notifier).generateTodayRecommendations(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 问候语
          _buildGreeting(),
          const SizedBox(height: 24),

          // 早餐
          _buildMealSection(state.breakfast),
          const SizedBox(height: 20),

          // 午餐
          _buildMealSection(state.lunch),
          const SizedBox(height: 20),

          // 晚餐
          _buildMealSection(state.dinner),
          const SizedBox(height: 24),
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
          '$greeting，今天想吃点什么？',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(MealRecommend meal) {
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '暂无推荐',
          style: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildRecipeCards(List<RecipeModel> recipes) {
    return Row(
      children: recipes.map((recipe) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: recipe != recipes.last ? 12 : 0,
            ),
            child: _RecipeCard(recipe: recipe),
          ),
        );
      }).toList(),
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

    return GestureDetector(
      onTap: () {
        // 导航到菜谱详情（需要先保存菜谱）
        context.push('${AppRoutes.recipes}/${recipe.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部颜色条
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getColorForRecipe(recipe),
                    _getColorForRecipe(recipe).withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant_menu,
                  size: 36,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),

            // 内容
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // 时间
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.prepTime + recipe.cookTime}分钟',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 库存状态提示
                  if (hasAllIngredients)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '食材齐全',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '需买：${missingIngredients.take(2).join("、")}${missingIngredients.length > 2 ? "等" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
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
