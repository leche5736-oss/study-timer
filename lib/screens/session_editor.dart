import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';

/// 기록을 직접 추가하거나 고치는 화면. [session]이 없으면 새 기록.
class SessionEditor extends StatefulWidget {
  final AppStore store;
  final StudySession? session;
  const SessionEditor({super.key, required this.store, this.session});

  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  late String? _subjectId;
  late DateTime _start; // 로컬
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;
  late final TextEditingController _note;
  int? _rating;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    final subjects = widget.store.subjects;
    _subjectId =
        s?.subjectId ??
        widget.store.timer.subjectId ??
        (subjects.isEmpty ? null : subjects.first.id);
    final now = DateTime.now();
    _start =
        s?.startedAt.toLocal() ??
        DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
        ).subtract(const Duration(hours: 1));
    _minutes = TextEditingController(
      text: s == null ? '50' : '${s.focusSeconds ~/ 60}',
    );
    _seconds = TextEditingController(
      text: s == null ? '0' : '${s.focusSeconds % 60}',
    );
    _note = TextEditingController(text: s?.recallNote ?? '');
    _rating = s?.focusRating;
  }

  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(
        () => _start = DateTime(
          d.year,
          d.month,
          d.day,
          _start.hour,
          _start.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t != null) {
      setState(
        () => _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  void _save() {
    final m = int.tryParse(_minutes.text.trim()) ?? -1;
    final sec = int.tryParse(_seconds.text.trim()) ?? -1;
    final total = m * 60 + sec;
    if (_subjectId == null) {
      setState(() => _error = '과목을 고르세요.');
      return;
    }
    if (m < 0 || sec < 0 || sec > 59 || total <= 0 || total > 24 * 3600) {
      setState(() => _error = '공부 시간을 확인하세요 (분은 0 이상, 초는 0~59).');
      return;
    }
    widget.store.saveSession(
      id: widget.session?.id,
      subjectId: _subjectId!,
      startedAt: _start,
      focusSeconds: total,
      focusRating: _rating,
      recallNote: _note.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    // 지난 기록이 삭제된 과목이면 그 과목도 목록에 넣어 둡니다.
    final subjects = [
      ...store.subjects,
      if (_subjectId != null && !store.subjects.any((s) => s.id == _subjectId))
        ?store.subject(_subjectId),
    ];
    String two(int v) => v.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session == null ? '기록 추가' : '기록 수정'),
        actions: [TextButton(onPressed: _save, child: const Text('저장'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            decoration: const InputDecoration(labelText: '과목'),
            items: [
              for (final s in subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${_start.year}.${_start.month}.${_start.day}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text('${two(_start.hour)}:${two(_start.minute)} 시작'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '공부 시간 (분)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '초'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('집중도'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text('$i'),
                  selected: _rating == i,
                  onSelected: (sel) => setState(() => _rating = sel ? i : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '정리 노트',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
    );
  }
}
