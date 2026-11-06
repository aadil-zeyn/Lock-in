import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/home_screen.dart';
import '../features/exercises/presentation/exercise_details_screen.dart';
import '../features/exercises/presentation/exercise_form_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/statistics/presentation/progress_screen.dart';
import '../features/workout/presentation/workout_hub_screen.dart';
import 'theme/app_tokens.dart';

abstract final class Routes {
  static const home = '/home';
  static const workout = '/workout';
  static const history = '/history';
  static const progress = '/progress';
  static const profile = '/profile';

  /// Full-screen routes (pushed over the tab bar).
  static const exercises = '/exercises';
  static const newExercise = '/exercises/new';
  static const archivedExercises = '/exercises/archived';
  static String exerciseDetails(int id) => '/exercises/$id';
  static String editExercise(int id) => '/exercises/$id/edit';
}

int? _idParam(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(Routes.workout, const WorkoutHubScreen()),
          _branch(Routes.history, const HistoryScreen()),
          _branch(Routes.progress, const ProgressScreen()),
          _branch(Routes.profile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: Routes.exercises,
        builder: (context, state) => const ExerciseLibraryScreen(),
        routes: [
          // Literal paths first so they aren't captured by ':id'.
          GoRoute(
            path: 'new',
            builder: (context, state) => const ExerciseFormScreen(),
          ),
          GoRoute(
            path: 'archived',
            builder: (context, state) =>
                const ExerciseLibraryScreen(archived: true),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ExerciseDetailsScreen(exerciseId: _idParam(state) ?? -1),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    ExerciseFormScreen(exerciseId: _idParam(state) ?? -1),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

/// Bottom-navigation shell. Each tab keeps its own navigation stack.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center_rounded),
      label: 'Workout',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the current tab again returns it to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
