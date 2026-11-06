import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/home_screen.dart';
import '../features/exercises/presentation/exercise_details_screen.dart';
import '../features/exercises/presentation/exercise_form_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/food/presentation/food_screen.dart';
import '../features/health/presentation/health_connect_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/edit_profile_screen.dart';
import '../features/share/presentation/share_progress_screen.dart';
import '../features/history_import/presentation/import_history_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/statistics/presentation/progress_screen.dart';
import '../features/dashboard/data/dashboard_providers.dart';
import '../features/workout/presentation/active_workout_screen.dart';
import '../features/workout/presentation/workout_actions.dart';
import '../features/workout/presentation/workout_hub_screen.dart';
import '../features/workout/presentation/workout_summary_screen.dart';
import 'theme/app_tokens.dart';

abstract final class Routes {
  static const home = '/home';
  static const workout = '/workout';
  static const food = '/food';

  /// Pushed from the Workout tab (no longer a tab of its own).
  static const history = '/history';
  static const progress = '/progress';
  static const profile = '/profile';

  /// Full-screen routes (pushed over the tab bar).
  static const exercises = '/exercises';
  static const newExercise = '/exercises/new';
  static const archivedExercises = '/exercises/archived';
  static String exerciseDetails(int id) => '/exercises/$id';
  static String editExercise(int id) => '/exercises/$id/edit';
  static const importHistory = '/import-history';
  static const healthConnect = '/health-connect';
  static const shareProgress = '/share';
  static const editProfile = '/about-you';

  /// The workout in progress (full screen, over the tabs).
  static const activeWorkout = '/session';
  static const pickExercises = '/session/add';
  static String workoutSummary(int id) => '/session/summary/$id';
  static String editWorkout(int id) => '/session/edit/$id';
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
          _branch(Routes.food, const FoodScreen()),
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
      GoRoute(
        path: Routes.importHistory,
        builder: (context, state) => const ImportHistoryScreen(),
      ),
      GoRoute(
        path: Routes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.shareProgress,
        builder: (context, state) => const ShareProgressScreen(),
      ),
      GoRoute(
        path: Routes.healthConnect,
        builder: (context, state) => const HealthConnectScreen(),
      ),
      GoRoute(
        path: Routes.activeWorkout,
        builder: (context, state) => const ActiveWorkoutScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) =>
                const ExerciseLibraryScreen(pickMode: true),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                WorkoutEditor(workoutId: _idParam(state) ?? -1, editing: true),
          ),
          GoRoute(
            path: 'summary/:id',
            builder: (context, state) =>
                WorkoutSummaryScreen(workoutId: _idParam(state) ?? -1),
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
      icon: Icon(Icons.restaurant_outlined),
      selectedIcon: Icon(Icons.restaurant_rounded),
      label: 'Food',
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutBar(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            destinations: _destinations,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              // Tapping the current tab again returns it to its root.
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini bar above the tabs while a workout is in progress (PRD v1.1 §4):
/// name + live elapsed time; tap to reopen.
class _ActiveWorkoutBar extends ConsumerStatefulWidget {
  const _ActiveWorkoutBar();

  @override
  ConsumerState<_ActiveWorkoutBar> createState() => _ActiveWorkoutBarState();
}

class _ActiveWorkoutBarState extends ConsumerState<_ActiveWorkoutBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(activeWorkoutProvider).value != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkoutProvider).value;
    if (active == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(active.startedAt);
    return Material(
      color: AppColors.surfaceHigh,
      child: InkWell(
        onTap: () => context.push(Routes.activeWorkout),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  active.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                formatClock(elapsed),
                style: AppText.metricM.copyWith(
                  fontSize: 17,
                  color: AppColors.time,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Resume',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
