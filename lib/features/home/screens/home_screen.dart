import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../shared/widgets/penguin_painter.dart';
import '../../../shared/widgets/rings_painter.dart';

/// Ekran główny - replika 1:1 tego co user widzi na zegarku.
/// Ringi (kroki + nawyki) → pingwinek w środku → streak pod spodem.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dzisiaj'), centerTitle: true),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (summary) => _HomeContent(summary: summary),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final DaySummary summary;
  const _HomeContent({required this.summary});

  PenguinMood _moodFor(double habits, double steps) {
    final avg = (habits + steps) / 2;
    if (avg >= 0.8) return PenguinMood.happy;
    if (avg >= 0.3) return PenguinMood.neutral;
    return PenguinMood.sad;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = _moodFor(summary.habitProgress, summary.stepProgress);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Sekcja "tarcza zegarka" - ringi + pingwinek.
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: RingsPainter(
                    stepsProgress: summary.stepProgress,
                    habitsProgress: summary.habitProgress,
                    strokeWidth: 20,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  heightFactor: 0.55,
                  child: AnimatedPenguin(mood: mood, size: 200),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Streak na środku, duży.
          _StreakBadge(days: summary.streakDays),

          const SizedBox(height: 24),

          // Dwie karty z liczbami.
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.directions_walk_rounded,
                  label: 'Kroki',
                  value: '${summary.steps}',
                  goal: '/ ${summary.stepGoal}',
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Nawyki',
                  value: '${summary.habitsDone}',
                  goal: '/ ${summary.habitsTotal}',
                  color: const Color(0xFF43A047),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Lista dzisiejszych nawyków - szczegóły pod ringami.
          _TodayHabitsList(summary: summary),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            '$days dni z rzędu',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String goal;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(goal, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayHabitsList extends ConsumerWidget {
  final DaySummary summary;
  const _TodayHabitsList({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);

    return habitsAsync.maybeWhen(
      data: (habits) {
        if (habits.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Dodaj pierwszy nawyk'),
              onTap: () => context.push('/habits/new'),
            ),
          );
        }

        // Mapa uuid → czy zaliczone dziś.
        final doneMap = {
          for (final e in summary.entries) e.habitUuid: e.completed,
        };

        return Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Dzisiejsze nawyki',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              ...habits.map((h) {
                final done = doneMap[h.uuid] ?? false;
                return ListTile(
                  leading: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: done ? Colors.green : null,
                  ),
                  title: Text(
                    h.name,
                    style: done
                        ? TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Text(h.shortName),
                  dense: true,
                );
              }),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
