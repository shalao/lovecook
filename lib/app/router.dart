import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/family/presentation/screens/family_list_screen.dart';
import '../features/family/presentation/screens/family_detail_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/inventory/presentation/screens/add_ingredient_screen.dart';
import '../features/menu/presentation/screens/menu_screen.dart';
import '../features/menu/presentation/screens/generate_menu_screen.dart';
import '../features/recipe/presentation/screens/recipe_list_screen.dart';
import '../features/recipe/presentation/screens/recipe_detail_screen.dart';
import '../features/cooking/presentation/screens/cooking_mode_screen.dart';
import '../features/shopping/presentation/screens/shopping_list_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/recommend/presentation/screens/recommend_screen.dart';
import '../features/recommend/presentation/screens/mood_chat_screen.dart';
import '../features/history/presentation/screens/meal_calendar_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../core/widgets/main_scaffold.dart';

// Route paths
class AppRoutes {
  static const String home = '/';
  static const String recommend = '/';
  static const String moodChat = '/mood-chat';
  static const String mealCalendar = '/meal-calendar';
  static const String favorites = '/favorites';
  static const String shopping = '/shopping';
  static const String profile = '/profile';
  static const String family = '/family';
  static const String familyDetail = '/family/:id';
  static const String inventory = '/inventory';
  static const String addIngredient = '/inventory/add';
  static const String menu = '/menu';
  static const String generateMenu = '/menu/generate';
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipes/:id';
  static const String settings = '/settings';
  static const String cookingMode = '/cooking';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // 主导航页面
          GoRoute(
            path: AppRoutes.recommend,
            builder: (context, state) => const RecommendScreen(),
          ),
          GoRoute(
            path: AppRoutes.moodChat,
            builder: (context, state) => const MoodChatScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealCalendar,
            builder: (context, state) => const MealCalendarScreen(),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            builder: (context, state) => const RecipeListScreen(),
          ),
          GoRoute(
            path: AppRoutes.shopping,
            builder: (context, state) => const ShoppingListScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          // 子页面
          GoRoute(
            path: AppRoutes.family,
            builder: (context, state) => const FamilyListScreen(),
          ),
          GoRoute(
            path: AppRoutes.familyDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return FamilyDetailScreen(familyId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.addIngredient,
            builder: (context, state) => const AddIngredientScreen(),
          ),
          GoRoute(
            path: AppRoutes.menu,
            builder: (context, state) => const MenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.generateMenu,
            builder: (context, state) => const GenerateMenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.recipes,
            builder: (context, state) => const RecipeListScreen(),
          ),
          GoRoute(
            path: AppRoutes.recipeDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return RecipeDetailScreen(recipeId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.cookingMode,
            builder: (context, state) {
              final recipe = state.extra as dynamic;
              return CookingModeScreen(recipe: recipe);
            },
          ),
        ],
      ),
    ],
  );
});
