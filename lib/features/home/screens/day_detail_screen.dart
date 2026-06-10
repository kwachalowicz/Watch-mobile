import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../shared/widgets/penguin_painter.dart';
import '../../../shared/widgets/rings_painter.dart';

class DayDetailScreen extends ConsumerWidget {
  final int dayKey;
  const DayDetailScreen({super.key, required this.dayKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(daySummaryProvider(dayKey));
    final habitsAsync = ref.watch(activeHabitsProvider);

    return Scaffold(
      appBar: AppBar(),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (s) => _DayDetail(summary: s, habits: habitsAsync.value ?? []),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DaySummary summary;
  final List habits;

  const _DayDetail({required this.summary, required this.habits});

  PenguinMood _mood() {
    final avg = (summary.habitProgress + summary.stepProgress) / 2;
    if (avg >= 0.8) return PenguinMood.happy;
    if (avg >= 0.3) return PenguinMood.neutral;
    return PenguinMood.sad;
  }

  String _formatDate(DateTime d) {
    return DateFormat('EEEE, d MMMM y', 'pl_PL').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final entriesByUuid = {for (final e in summary.entries) e.habitUuid: e};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _formatDate(summary.date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (summary.isToday)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Center(
                child: Chip(
                  label: Text('Dzisiaj'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Pingwinek + ringi.
          if (summary.hasData)
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
                      strokeWidth: 18,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.55,
                    heightFactor: 0.55,
                    child: AnimatedPenguin(mood: _mood()),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.sentiment_neutral_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Brak danych dla tego dnia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Statystyki w 2 kolumnach.
          _StatRow(
            icon: Icons.directions_walk_rounded,
            label: 'Kroki',
            value: '${summary.steps}',
            secondary: 'cel: ${summary.stepGoal}',
            color: const Color(0xFF1E88E5),
          ),
          _StatRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Nawyki zaliczone',
            value: '${summary.habitsDone} / ${summary.habitsTotal}',
            secondary: summary.habitsTotal > 0
                ? '${(summary.habitProgress * 100).round()}%'
                : '—',
            color: const Color(0xFF43A047),
          ),
          _StatRow(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '${summary.streakDays} dni',
            secondary: null,
            color: Colors.orange,
          ),

          const SizedBox(height: 24),
          if (habits.isNotEmpty) ...[
            Text(
              'Lista nawyków',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: habits.map((h) {
                  final entry = entriesByUuid[h.uuid];
                  final done = entry?.completed ?? false;
                  return ListTile(
                    leading: Icon(
                      done ? Icons.check_circle_rounded : Icons.cancel_outlined,
                      color: done ? Colors.green : Colors.grey,
                    ),
                    title: Text(h.name),
                    subtitle: entry?.completedAt != null
                        ? Text(
                            'Zaliczone o ${DateFormat.Hm().format(entry!.completedAt!)} '
                            '· ${entry.source}',
                          )
                        : const Text('Niezaliczone'),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? secondary;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.secondary,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (secondary != null)
              Text(secondary!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
