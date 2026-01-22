import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../data/models/recipe_model.dart';
import '../../data/repositories/recipe_repository.dart';

class RecipeListScreen extends ConsumerWidget {
  /// 初始显示的 Tab 索引: 0 = 收藏菜谱, 1 = 全部菜谱
  final int initialTabIndex;

  const RecipeListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFamily = ref.watch(currentFamilyProvider);
    final familyId = currentFamily?.id;

    // 使用 key 强制 GoRouter 在不同路由间切换时重建 DefaultTabController
    return DefaultTabController(
      key: ValueKey('recipe_tabs_$initialTabIndex'),
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(initialTabIndex == 0 ? '我的收藏' : '菜谱库'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '收藏菜谱'),
              Tab(text: '全部菜谱'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FavoriteRecipeList(familyId: familyId),
            _AllRecipeList(familyId: familyId),
          ],
        ),
      ),
    );
  }
}

class _FavoriteRecipeList extends ConsumerWidget {
  final String? familyId;

  const _FavoriteRecipeList({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRecipesProvider(familyId));

    if (favorites.isEmpty) {
      return _EmptyRecipeList(
        icon: Icons.bookmark_border,
        title: '暂无收藏菜谱',
        subtitle: '生成菜单后可收藏喜欢的菜谱',
      );
    }

    return _RecipeGrid(recipes: favorites);
  }
}

class _AllRecipeList extends ConsumerWidget {
  final String? familyId;

  const _AllRecipeList({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecipes = ref.watch(allRecipesProvider);

    // Filter by family
    final recipes = allRecipes
        .where((r) => r.familyId == null || r.familyId == familyId)
        .toList();

    if (recipes.isEmpty) {
      return _EmptyRecipeList(
        icon: Icons.restaurant_menu,
        title: '暂无菜谱',
        subtitle: '生成菜单后，菜谱会自动保存在这里',
      );
    }

    return _RecipeGrid(recipes: recipes);
  }
}

class _RecipeGrid extends StatelessWidget {
  final List<RecipeModel> recipes;

  const _RecipeGrid({required this.recipes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式列数：根据屏幕宽度调整
        // 移动端 (<600): 2 列
        // 平板 (600-900): 3 列
        // 桌面 (900-1200): 4 列
        // 大屏 (>1200): 5 列
        final width = constraints.maxWidth;
        int crossAxisCount;
        double childAspectRatio;
        double spacing;

        if (width < 600) {
          crossAxisCount = 2;
          childAspectRatio = 0.85;
          spacing = 12;
        } else if (width < 900) {
          crossAxisCount = 3;
          childAspectRatio = 0.85;
          spacing = 16;
        } else if (width < 1200) {
          crossAxisCount = 4;
          childAspectRatio = 0.9;
          spacing = 20;
        } else {
          crossAxisCount = 5;
          childAspectRatio = 0.9;
          spacing = 24;
        }

        return GridView.builder(
          padding: EdgeInsets.all(width < 600 ? 16 : 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return _RecipeCard(recipe: recipe);
          },
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        context.push('${AppRoutes.recipes}/${recipe.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 13),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部图片或颜色条
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或渐变背景
                  if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                    Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildGradientBackground();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildGradientBackground();
                      },
                    )
                  else
                    _buildGradientBackground(),
                  // 收藏标记
                  if (recipe.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(77),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.textPrimaryDark : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.prepTime + recipe.cookTime}分钟',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings}人份',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getColorForRecipe(recipe),
            _getColorForRecipe(recipe).withAlpha(179),
          ],
        ),
      ),
      child: Center(
        child: Text(
          recipe.name.isNotEmpty ? recipe.name.substring(0, 1) : '菜',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white.withAlpha(230),
          ),
        ),
      ),
    );
  }

  Color _getColorForRecipe(RecipeModel recipe) {
    // Generate a color based on recipe name hash
    final hash = recipe.name.hashCode;
    final colors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF607D8B), // Blue Grey
    ];
    return colors[hash.abs() % colors.length];
  }
}

class _EmptyRecipeList extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyRecipeList({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
