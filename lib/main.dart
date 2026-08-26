import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const GymSetTracker());

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.target,
    this.done = 0,
    this.weight,
  });
  final String id;
  final String name;
  final int target;
  final int done;
  final String? weight;
  int get left => target - done;
  String get weightLabel =>
      weight == null || weight!.isEmpty ? '' : '$weight kg';
  Exercise copyWith({String? name, int? target, int? done, String? weight}) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        target: target ?? this.target,
        done: done ?? this.done,
        weight: weight ?? this.weight,
      );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'done': done,
    'weight': weight,
  };
  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    target: (json['target'] as num).toInt(),
    done: (json['done'] as num?)?.toInt() ?? 0,
    weight: json['weight'] as String?,
  );
}

class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.name,
    this.exercises = const [],
  });
  final String id;
  final String name;
  final List<Exercise> exercises;
  int get done => exercises.fold(0, (total, item) => total + item.done);
  int get target => exercises.fold(0, (total, item) => total + item.target);
  WorkoutDay copyWith({String? name, List<Exercise>? exercises}) => WorkoutDay(
    id: id,
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((item) => item.toJson()).toList(),
  };
  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises: (json['exercises'] as List<dynamic>? ?? [])
        .map(
          (item) => Exercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class WorkoutLog {
  const WorkoutLog({required this.date, required this.title});

  /// Stored as YYYY-MM-DD so it remains tied to the user's calendar date.
  final String date;
  final String title;

  Map<String, String> toJson() => {'date': date, 'title': title};

  factory WorkoutLog.fromJson(Map<String, dynamic> json) =>
      WorkoutLog(date: json['date'] as String, title: json['title'] as String);
}

class BodyWeightEntry {
  const BodyWeightEntry({required this.date, required this.kilograms});

  final String date;
  final double kilograms;

  Map<String, Object> toJson() => {'date': date, 'kilograms': kilograms};

  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) =>
      BodyWeightEntry(
        date: json['date'] as String,
        kilograms: (json['kilograms'] as num).toDouble(),
      );
}

class GymSetTracker extends StatelessWidget {
  const GymSetTracker({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Setwise',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff8066ff),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff111117),
    ),
    home: const TrackerHome(),
  );
}

class TrackerHome extends StatefulWidget {
  const TrackerHome({super.key});
  @override
  State<TrackerHome> createState() => _TrackerHomeState();
}

class _TrackerHomeState extends State<TrackerHome> {
  static const _workoutsKey = 'gym_workout_days_v2';
  static const _activeKey = 'gym_active_workout_day_v2';
  static const _calendarKey = 'gym_calendar_logs_v1';
  static const _bodyWeightKey = 'gym_body_weight_entries_v1';
  List<WorkoutDay> _days = [];
  List<WorkoutLog> _logs = [];
  List<BodyWeightEntry> _bodyWeights = [];
  String? _activeDayId;
  bool _loading = true;
  int _tab = 0;

  WorkoutDay? get _activeDay {
    for (final day in _days) {
      if (day.id == _activeDayId) return day;
    }
    return _days.isEmpty ? null : _days.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_workoutsKey) ?? prefs.getString('gym_exercises_v1');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        if (decoded.isNotEmpty &&
            (decoded.first as Map).containsKey('target')) {
          _days = [
            WorkoutDay(
              id: 'migrated-workout',
              name: 'My workout',
              exercises: decoded
                  .map(
                    (item) => Exercise.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ),
                  )
                  .toList(),
            ),
          ];
        } else {
          _days = decoded
              .map(
                (item) =>
                    WorkoutDay.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();
        }
      } catch (_) {}
    }
    _activeDayId =
        prefs.getString(_activeKey) ?? (_days.isEmpty ? null : _days.first.id);
    final savedLogs = prefs.getString(_calendarKey);
    if (savedLogs != null) {
      try {
        _logs = (jsonDecode(savedLogs) as List<dynamic>)
            .map(
              (item) =>
                  WorkoutLog.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      } catch (_) {}
    }
    final savedWeights = prefs.getString(_bodyWeightKey);
    if (savedWeights != null) {
      try {
        _bodyWeights = (jsonDecode(savedWeights) as List<dynamic>)
            .map(
              (item) => BodyWeightEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _workoutsKey,
      jsonEncode(_days.map((day) => day.toJson()).toList()),
    );
    if (_activeDayId != null) await prefs.setString(_activeKey, _activeDayId!);
    await prefs.setString(
      _calendarKey,
      jsonEncode(_logs.map((log) => log.toJson()).toList()),
    );
    await prefs.setString(
      _bodyWeightKey,
      jsonEncode(_bodyWeights.map((entry) => entry.toJson()).toList()),
    );
  }

  void _updateDay(WorkoutDay day) {
    setState(
      () =>
          _days = _days.map((item) => item.id == day.id ? day : item).toList(),
    );
    _save();
  }

  void _setActiveDay(String id) {
    setState(() => _activeDayId = id);
    _save();
  }

  Future<void> _editDay([WorkoutDay? day]) async {
    final result = await showModalBottomSheet<WorkoutDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkoutDayEditor(day: day),
    );
    if (result == null) return;
    setState(() {
      if (day == null) {
        _days = [..._days, result];
        _activeDayId = result.id;
      } else {
        _days = _days
            .map((item) => item.id == result.id ? result : item)
            .toList();
      }
    });
    _save();
  }

  void _deleteDay(WorkoutDay day) {
    setState(() {
      _days = _days.where((item) => item.id != day.id).toList();
      if (_activeDayId == day.id) {
        _activeDayId = _days.isEmpty ? null : _days.first.id;
      }
    });
    _save();
  }

  Future<void> _openDay(WorkoutDay day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayExercisesPage(
          day: day,
          onDayUpdated: _updateDay,
          onDayDeleted: _deleteDay,
        ),
      ),
    );
  }

  void _resetDay(WorkoutDay day) => _updateDay(
    day.copyWith(
      exercises: day.exercises.map((item) => item.copyWith(done: 0)).toList(),
    ),
  );

  void _addLog(WorkoutLog log) {
    if (_logs.any((item) => item.date == log.date && item.title == log.title)) {
      return;
    }
    setState(() => _logs = [..._logs, log]);
    _save();
  }

  void _deleteLog(WorkoutLog log) {
    setState(() => _logs = _logs.where((item) => item != log).toList());
    _save();
  }

  void _saveBodyWeight(BodyWeightEntry entry) {
    setState(() {
      _bodyWeights = [
        ..._bodyWeights.where((item) => item.date != entry.date),
        entry,
      ];
    });
    _save();
  }

  void _deleteBodyWeight(BodyWeightEntry entry) {
    setState(
      () => _bodyWeights = _bodyWeights
          .where((item) => item.date != entry.date)
          .toList(),
    );
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: switch (_tab) {
          0 => WorkoutPage(
            days: _days,
            activeDay: _activeDay,
            onSelectDay: _setActiveDay,
            onDayUpdated: _updateDay,
            onReset: _resetDay,
          ),
          1 => PlanPage(
            days: _days,
            onOpen: _openDay,
            onAdd: () => _editDay(),
            onEdit: _editDay,
            onDelete: _deleteDay,
          ),
          _ => CalendarPage(
            days: _days,
            logs: _logs,
            bodyWeights: _bodyWeights,
            onAddLog: _addLog,
            onDeleteLog: _deleteLog,
            onSaveBodyWeight: _saveBodyWeight,
            onDeleteBodyWeight: _deleteBodyWeight,
          ),
        },
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _editDay(),
              icon: const Icon(Icons.add),
              label: const Text('Add workout day'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Plan'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({
    super.key,
    required this.days,
    required this.activeDay,
    required this.onSelectDay,
    required this.onDayUpdated,
    required this.onReset,
  });
  final List<WorkoutDay> days;
  final WorkoutDay? activeDay;
  final ValueChanged<String> onSelectDay;
  final ValueChanged<WorkoutDay> onDayUpdated;
  final ValueChanged<WorkoutDay> onReset;

  @override
  Widget build(BuildContext context) {
    if (activeDay == null) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Create your first workout day',
        description: 'Open Plan, then add a day such as Chest, Back, or Legs.',
      );
    }
    final day = activeDay!;
    final left = day.target - day.done;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s workout',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose a workout day',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final item = days[index];
                      return ChoiceChip(
                        label: Text(item.name),
                        selected: item.id == day.id,
                        onSelected: (_) => onSelectDay(item.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xff6c4dff),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.name} · $left sets left',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${day.done} of ${day.target} sets completed'),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: day.target == 0 ? 0 : day.done / day.target,
                          minHeight: 9,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (day.done > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onReset(day),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Start over'),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text('Tap an exercise card after each finished set.'),
              ],
            ),
          ),
        ),
        if (day.exercises.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.add_task_outlined,
              title: 'No exercises in this day',
              description: 'Open Plan and add exercises to this workout day.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            sliver: SliverList.separated(
              itemCount: day.exercises.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final exercise = day.exercises[index];
                return WorkoutCard(
                  item: exercise,
                  onChange: (replacement) => onDayUpdated(
                    day.copyWith(
                      exercises: day.exercises
                          .map(
                            (item) =>
                                item.id == replacement.id ? replacement : item,
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({super.key, required this.item, required this.onChange});
  final Exercise item;
  final ValueChanged<Exercise> onChange;
  @override
  Widget build(BuildContext context) {
    final complete = item.left == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: complete ? const Color(0xff1d362d) : const Color(0xff20202a),
      child: InkWell(
        onTap: complete
            ? null
            : () => onChange(item.copyWith(done: item.done + 1)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${item.left} left',
                    style: TextStyle(
                      color: complete ? const Color(0xff75e5b3) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                item.weightLabel.isEmpty
                    ? '${item.done} done of ${item.target} sets'
                    : '${item.weightLabel} · ${item.done} done of ${item.target} sets',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(item.target, (index) {
                  final checked = index < item.done;
                  return Semantics(
                    label: 'Set ${index + 1}',
                    checked: checked,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: checked
                            ? const Color(0xff6c4dff)
                            : Colors.transparent,
                        border: Border.all(
                          color: checked
                              ? const Color(0xff6c4dff)
                              : Colors.white38,
                          width: 2,
                        ),
                      ),
                      child: checked
                          ? const Icon(Icons.check, size: 20)
                          : Text('${index + 1}'),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: item.done == 0
                      ? null
                      : () => onChange(item.copyWith(done: item.done - 1)),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo last set'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.days,
    required this.onOpen,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<WorkoutDay> days;
  final ValueChanged<WorkoutDay> onOpen;
  final VoidCallback onAdd;
  final ValueChanged<WorkoutDay> onEdit;
  final ValueChanged<WorkoutDay> onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 6),
        child: Text(
          'Workout days',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Create days such as Chest, Back, or Legs, then add their exercises.',
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: days.isEmpty
            ? EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No workout days yet',
                description:
                    'Create a day such as Chest to start building your plan.',
                action: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add workout day'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: days.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final day = days[index];
                  return Card(
                    color: const Color(0xff20202a),
                    child: ListTile(
                      onTap: () => onOpen(day),
                      leading: const CircleAvatar(
                        child: Icon(Icons.calendar_today),
                      ),
                      title: Text(day.name),
                      subtitle: Text(
                        '${day.exercises.length} exercises · ${day.target} planned sets',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit ${day.name}',
                            onPressed: () => onEdit(day),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete ${day.name}',
                            onPressed: () => onDelete(day),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

class DayExercisesPage extends StatefulWidget {
  const DayExercisesPage({
    super.key,
    required this.day,
    required this.onDayUpdated,
    required this.onDayDeleted,
  });
  final WorkoutDay day;
  final ValueChanged<WorkoutDay> onDayUpdated;
  final ValueChanged<WorkoutDay> onDayDeleted;
  @override
  State<DayExercisesPage> createState() => _DayExercisesPageState();
}

class _DayExercisesPageState extends State<DayExercisesPage> {
  late WorkoutDay _day;
  @override
  void initState() {
    super.initState();
    _day = widget.day;
  }

  void _save(WorkoutDay day) {
    setState(() => _day = day);
    widget.onDayUpdated(day);
  }

  Future<void> _editDay() async {
    final result = await showModalBottomSheet<WorkoutDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkoutDayEditor(day: _day),
    );
    if (result != null) _save(result);
  }

  Future<void> _editExercise([Exercise? exercise]) async {
    final result = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExerciseEditor(exercise: exercise),
    );
    if (result == null) return;
    _save(
      _day.copyWith(
        exercises: exercise == null
            ? [..._day.exercises, result]
            : _day.exercises
                  .map((item) => item.id == result.id ? result : item)
                  .toList(),
      ),
    );
  }

  void _deleteExercise(Exercise exercise) => _save(
    _day.copyWith(
      exercises: _day.exercises
          .where((item) => item.id != exercise.id)
          .toList(),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_day.name),
      actions: [
        IconButton(
          tooltip: 'Edit workout day',
          onPressed: _editDay,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete workout day',
          onPressed: () {
            widget.onDayDeleted(_day);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editExercise(),
      icon: const Icon(Icons.add),
      label: const Text('Add exercise'),
    ),
    body: _day.exercises.isEmpty
        ? const EmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'No exercises yet',
            description:
                'Add the exercises you want to perform on this workout day.',
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _day.exercises.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final exercise = _day.exercises[index];
              return Card(
                color: const Color(0xff20202a),
                child: ListTile(
                  onTap: () => _editExercise(exercise),
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(
                    exercise.weightLabel.isEmpty
                        ? '${exercise.target} planned sets · ${exercise.done} completed'
                        : '${exercise.weightLabel} · ${exercise.target} planned sets · ${exercise.done} completed',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete ${exercise.name}',
                    onPressed: () => _deleteExercise(exercise),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            },
          ),
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.days,
    required this.logs,
    required this.bodyWeights,
    required this.onAddLog,
    required this.onDeleteLog,
    required this.onSaveBodyWeight,
    required this.onDeleteBodyWeight,
  });

  final List<WorkoutDay> days;
  final List<WorkoutLog> logs;
  final List<BodyWeightEntry> bodyWeights;
  final ValueChanged<WorkoutLog> onAddLog;
  final ValueChanged<WorkoutLog> onDeleteLog;
  final ValueChanged<BodyWeightEntry> onSaveBodyWeight;
  final ValueChanged<BodyWeightEntry> onDeleteBodyWeight;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _today = DateTime.now();
  late DateTime _shownMonth = DateTime(_today.year, _today.month);
  late DateTime _selectedDate = _today;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  List<WorkoutLog> _logsFor(DateTime date) =>
      widget.logs.where((log) => log.date == _dateKey(date)).toList();

  BodyWeightEntry? _weightFor(DateTime date) {
    for (final entry in widget.bodyWeights) {
      if (entry.date == _dateKey(date)) return entry;
    }
    return null;
  }

  Future<void> _addWorkout() async {
    if (widget.days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a workout day in Plan first.')),
      );
      return;
    }
    final title = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('What workout did you do?'),
              subtitle: Text('Choose one of your workout-day titles.'),
            ),
            ...widget.days.map(
              (day) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: Text(day.name),
                onTap: () => Navigator.pop(context, day.name),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (title != null) {
      widget.onAddLog(WorkoutLog(date: _dateKey(_selectedDate), title: title));
    }
  }

  Future<void> _recordBodyWeight() async {
    final existing = _weightFor(_selectedDate);
    final controller = TextEditingController(
      text: existing == null ? '' : existing.kilograms.toString(),
    );
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录体重'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('建议在刚睡醒、上厕所后，并且进食或喝水前测量。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '体重',
                suffixText: 'kg',
                hintText: '例如 68.5',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null) return;
    final kilograms = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (kilograms == null || kilograms <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入有效的体重数值。')));
      }
      return;
    }
    widget.onSaveBodyWeight(
      BodyWeightEntry(date: _dateKey(_selectedDate), kilograms: kilograms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstOffset =
        (DateTime(_shownMonth.year, _shownMonth.month).weekday + 6) % 7;
    final daysInMonth = DateTime(
      _shownMonth.year,
      _shownMonth.month + 1,
      0,
    ).day;
    final cellCount = ((firstOffset + daysInMonth + 6) ~/ 7) * 7;
    final selectedLogs = _logsFor(_selectedDate);
    final selectedWeight = _weightFor(_selectedDate);
    final monthTitle =
        '${_monthNames[_shownMonth.month - 1]} ${_shownMonth.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Workout calendar',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Tap a date to record the workout you completed.'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => _shownMonth = DateTime(
                  _shownMonth.year,
                  _shownMonth.month - 1,
                ),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                monthTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(
                () => _shownMonth = DateTime(
                  _shownMonth.year,
                  _shownMonth.month + 1,
                ),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: _weekdays
              .map(
                (day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.82,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - firstOffset + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(
              _shownMonth.year,
              _shownMonth.month,
              dayNumber,
            );
            final logs = _logsFor(date);
            final weight = _weightFor(date);
            final selected = _sameDate(date, _selectedDate);
            final isToday = _sameDate(date, _today);
            return Material(
              color: selected
                  ? const Color(0xff3e347d)
                  : const Color(0xff20202a),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => setState(() => _selectedDate = date),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: const Color(0xff6c4dff),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(
                            dayNumber.toString(),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      if (weight != null)
                        Text(
                          '${weight.kilograms.toStringAsFixed(1)} kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff75e5b3),
                          ),
                        ),
                      ...logs
                          .take(2)
                          .map(
                            (log) => Text(
                              log.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xffbbaeff),
                              ),
                            ),
                          ),
                      if (logs.length > 2)
                        Text(
                          '+${logs.length - 2}',
                          style: const TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          color: const Color(0xff20202a),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body weight',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  selectedWeight == null
                      ? 'No weight recorded for this date.'
                      : '${selectedWeight.kilograms.toStringAsFixed(1)} kg',
                  style: selectedWeight == null
                      ? const TextStyle(color: Colors.white60)
                      : Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Best measured just after waking up, after using the bathroom, before food or water.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (selectedWeight != null)
                      IconButton(
                        tooltip: 'Remove body weight',
                        onPressed: () =>
                            widget.onDeleteBodyWeight(selectedWeight),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: _recordBodyWeight,
                      icon: const Icon(Icons.monitor_weight_outlined),
                      label: Text(
                        selectedWeight == null
                            ? 'Record weight'
                            : 'Update weight',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected: ${_dateKey(_selectedDate)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: _addWorkout,
              icon: const Icon(Icons.add),
              label: const Text('Log workout'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No workout recorded on this day.',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          ...selectedLogs.map(
            (log) => Card(
              color: const Color(0xff20202a),
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xff75e5b3),
                ),
                title: Text(log.title),
                trailing: IconButton(
                  tooltip: 'Remove ${log.title}',
                  onPressed: () => widget.onDeleteLog(log),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Colors.white54),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class WorkoutDayEditor extends StatefulWidget {
  const WorkoutDayEditor({super.key, this.day});
  final WorkoutDay? day;
  @override
  State<WorkoutDayEditor> createState() => _WorkoutDayEditorState();
}

class _WorkoutDayEditorState extends State<WorkoutDayEditor> {
  late final TextEditingController _name;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.day?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final old = widget.day;
    Navigator.pop(
      context,
      WorkoutDay(
        id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        exercises: old?.exercises ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.day == null ? 'Add workout day' : 'Edit workout day',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Workout day name',
            hintText: 'e.g. Chest',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: Text(
              widget.day == null ? 'Create workout day' : 'Save workout day',
            ),
          ),
        ),
      ],
    ),
  );
}

class ExerciseEditor extends StatefulWidget {
  const ExerciseEditor({super.key, this.exercise});
  final Exercise? exercise;
  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late int _sets;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise?.name ?? '');
    _weight = TextEditingController(text: widget.exercise?.weight ?? '');
    _sets = widget.exercise?.target ?? 3;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final weight = _weight.text.trim();
    final old = widget.exercise;
    Navigator.pop(
      context,
      Exercise(
        id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        target: _sets,
        done: (old?.done ?? 0).clamp(0, _sets).toInt(),
        weight: weight.isEmpty ? null : weight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.exercise == null ? 'Add exercise' : 'Edit exercise',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Exercise name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (optional)',
            suffixText: 'kg',
            hintText: 'e.g. 20',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        Text('Target sets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: _sets > 1 ? () => setState(() => _sets--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '$_sets',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton.outlined(
              onPressed: _sets < 20 ? () => setState(() => _sets++) : null,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            const Text('sets'),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Save exercise'),
          ),
        ),
      ],
    ),
  );
}
