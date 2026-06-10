import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/device/screens/device_screen.dart';
import 'features/habits/screens/habit_edit_screen.dart';
import 'features/habits/screens/habits_screen.dart';
import 'features/home/screens/day_detail_screen.dart';
import 'features/home/screens/home_screen.dart';

class PenguinTrackerApp extends ConsumerWidget {
  const PenguinTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aktywuje listener BLE state → auto start/stop sync coordinator (foreground
    // fallback). ProviderScope trzyma go żywego dopóki app żyje.
    ref.watch(bleAutoSyncProvider);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => _RootShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(
                path: '/calendar', builder: (_, _) => const CalendarScreen()),
            GoRoute(path: '/habits', builder: (_, _) => const HabitsScreen()),
            GoRoute(path: '/device', builder: (_, _) => const DeviceScreen()),
          ],
        ),
        GoRoute(
          path: '/day/:dayKey',
          builder: (_, state) => DayDetailScreen(
            dayKey: int.parse(state.pathParameters['dayKey']!),
          ),
        ),
        GoRoute(
          path: '/habits/edit/:uuid',
          builder: (_, state) => HabitEditScreen(
            habitUuid: state.pathParameters['uuid'],
          ),
        ),
        GoRoute(
          path: '/habits/new',
          builder: (_, _) => const HabitEditScreen(habitUuid: null),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Penguin Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
    );
  }
}

/// Bottom nav z 4 zakładkami: Home, Kalendarz, Nawyki, Zegarek.
class _RootShell extends StatelessWidget {
  final Widget child;
  const _RootShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = switch (location) {
      _ when location.startsWith('/calendar') => 1,
      _ when location.startsWith('/habits') => 2,
      _ when location.startsWith('/device') => 3,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/calendar');
            case 2:
              context.go('/habits');
            case 3:
              context.go('/device');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Główny',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Kalendarz',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Nawyki',
          ),
          NavigationDestination(
            icon: Icon(Icons.watch_outlined),
            selectedIcon: Icon(Icons.watch_rounded),
            label: 'Zegarek',
          ),
        ],
      ),
    );
  }
}
