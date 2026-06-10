import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/habit.dart';

class HabitEditScreen extends ConsumerStatefulWidget {
  final String? habitUuid;
  const HabitEditScreen({super.key, required this.habitUuid});

  @override
  ConsumerState<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends ConsumerState<HabitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  Habit? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.habitUuid != null) {
      final repo = ref.read(habitRepositoryProvider);
      _existing = await repo.getByUuid(widget.habitUuid!);
      if (_existing != null) {
        _nameCtrl.text = _existing!.name;
        _shortNameCtrl.text = _existing!.shortName;
      }
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(habitRepositoryProvider);

    if (_existing == null) {
      await repo.create(
        name: _nameCtrl.text.trim(),
        shortName: _shortNameCtrl.text.trim(),
      );
    } else {
      _existing!
        ..name = _nameCtrl.text.trim()
        ..shortName = _shortNameCtrl.text.trim();
      await repo.update(_existing!);
    }

    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć nawyk?'),
        content: Text(
          'Nawyk "${existing.name}" zostanie ukryty. '
          'Historia wykonania pozostanie zachowana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(habitRepositoryProvider).softDelete(existing);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nowy nawyk' : 'Edycja nawyku'),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              tooltip: 'Usuń',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pełna nazwa',
                helperText: 'Wyświetlana w aplikacji',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wymagane' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Skrót na zegarek',
                helperText: 'Max 12 znaków - widoczne na ekranie 176px',
                border: OutlineInputBorder(),
              ),
              maxLength: 12,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wymagane' : null,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_existing == null ? 'Dodaj' : 'Zapisz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
