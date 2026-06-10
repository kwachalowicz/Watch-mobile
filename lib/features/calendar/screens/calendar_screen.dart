import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/day_key.dart';
import '../../../core/providers.dart';
import '../../../data/repositories/habit_repository.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<int, DaySummary> _monthData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loading = true);
    final repo = ref.read(habitRepositoryProvider);
    final data = await repo.getMonthSummary(month.year, month.month);
    if (!mounted) return;
    setState(() {
      _monthData = data;
      _loading = false;
    });
  }

  Color? _colorForDay(DateTime day) {
    final summary = _monthData[DayKey.fromDate(day)];
    if (summary == null || !summary.hasData) return null;

    final progress = summary.habitProgress;
    if (progress >= 0.99) {
      return Colors.green.withValues(alpha: 0.7); // pełen sukces
    }
    if (progress >= 0.5) {
      return Colors.lightGreen.withValues(alpha: 0.5);
    }
    if (progress > 0) {
      return Colors.amber.withValues(alpha: 0.5); // częściowo
    }
    return Colors.grey.withValues(alpha: 0.25); // dzień miniony, nic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalendarz'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: TableCalendar<DaySummary>(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Miesiąc'},
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
                _loadMonth(focused);
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (ctx, day, _) => _DayCell(
                  day: day,
                  color: _colorForDay(day),
                ),
                todayBuilder: (ctx, day, _) => _DayCell(
                  day: day,
                  color: _colorForDay(day),
                  isToday: true,
                ),
                selectedBuilder: (ctx, day, _) => _DayCell(
                  day: day,
                  color: _colorForDay(day),
                  isSelected: true,
                ),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          const _Legend(),
          if (_selectedDay != null)
            Expanded(
              child: _SelectedDayPreview(
                dayKey: DayKey.fromDate(_selectedDay!),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Color? color;
  final bool isToday;
  final bool isSelected;

  const _DayCell({
    required this.day,
    this.color,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : isToday
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontWeight: isToday || isSelected ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _LegendDot(color: Colors.green.withValues(alpha: 0.7), label: 'Wszystko'),
          _LegendDot(
            color: Colors.lightGreen.withValues(alpha: 0.5),
            label: '≥ 50%',
          ),
          _LegendDot(color: Colors.amber.withValues(alpha: 0.5), label: 'Trochę'),
          _LegendDot(color: Colors.grey.withValues(alpha: 0.25), label: 'Nic'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Karta podglądu zaznaczonego dnia + przycisk do pełnego ekranu szczegółów.
class _SelectedDayPreview extends ConsumerWidget {
  final int dayKey;
  const _SelectedDayPreview({required this.dayKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(daySummaryProvider(dayKey));

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: Text(
                  '${s.date.day}.${s.date.month.toString().padLeft(2, '0')}',
                ),
                subtitle: Text(
                  s.hasData
                      ? '${s.habitsDone}/${s.habitsTotal} nawyków · '
                          '${s.steps} kroków'
                      : 'Brak danych',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/day/$dayKey'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
