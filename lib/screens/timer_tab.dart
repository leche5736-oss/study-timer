import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../stats.dart';

class TimerTab extends StatelessWidget {
  final AppStore store;
  final VoidCallback onGoToSubjects;
  const TimerTab({
    super.key,
    required this.store,
    required this.onGoToSubjects,
  });

  @override
  Widget build(BuildContext context) {
    return switch (store.timer.phase) {
      Phase.idle => _IdleView(store: store, onGoToSubjects: onGoToSubjects),
      Phase.focus => _FocusView(store: store),
      Phase.recall => _RecallView(store: store),
      Phase.rest => const SizedBox.shrink(), // HomeScreen이 휴식 화면을 보여줌
    };
  }
}

class _IdleView extends StatefulWidget {
  final AppStore store;
  final VoidCallback onGoToSubjects;
  const _IdleView({required this.store, required this.onGoToSubjects});

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  String? _subjectId;
  late int _preset = widget.store.timer.presetIndex;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final subjects = store.subjects;
    if (subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('먼저 공부할 과목을 추가하세요.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onGoToSubjects,
              child: const Text('과목 추가하러 가기'),
            ),
          ],
        ),
      );
    }
    final selected = subjects.any((s) => s.id == _subjectId)
        ? _subjectId!
        : subjects.any((s) => s.id == store.timer.subjectId)
        ? store.timer.subjectId!
        : subjects.first.id;
    final blocks = store.timer.blocksDone;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('과목'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected,
          items: [
            for (final s in subjects)
              DropdownMenuItem(
                value: s.id,
                child: Row(
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: s.colorValue),
                    const SizedBox(width: 8),
                    Text(s.name),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _subjectId = v),
        ),
        const SizedBox(height: 24),
        const Text('집중/휴식 길이 (분)'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < presets.length; i++)
              ButtonSegment(value: i, label: Text(presets[i].label)),
          ],
          selected: {_preset},
          onSelectionChanged: (v) => setState(() => _preset = v.first),
        ),
        const SizedBox(height: 8),
        Text(
          '$blocksPerLongRest블록마다 긴 휴식(${presets[_preset].longRestMin}분). '
          '지금까지 이어서 $blocks블록 완료.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.play_arrow),
          label: Text(blocks == 0 ? '집중 시작' : '다음 블록 시작'),
          onPressed: () {
            Notifications.instance.requestWebPermission();
            store.startFocus(selected, _preset);
          },
        ),
      ],
    );
  }
}

class _FocusView extends StatelessWidget {
  final AppStore store;
  const _FocusView({required this.store});

  @override
  Widget build(BuildContext context) {
    final t = store.timer;
    final now = store.now;
    final subject = store.subject(t.subjectId);
    final remaining = t.remainingSec(now);
    final progress = t.durationSec == 0
        ? 0.0
        : t.elapsedSec(now) / t.durationSec;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '집중 중 · ${subject?.name ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              formatClock(remaining),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            const SizedBox(height: 8),
            Text(
              t.isRunning ? '휴대폰은 잠시 멀리 두세요.' : '일시정지됨',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (t.isRunning)
                  OutlinedButton.icon(
                    onPressed: store.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('일시정지'),
                  )
                else
                  FilledButton.icon(
                    onPressed: store.resume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('계속'),
                  ),
                OutlinedButton.icon(
                  onPressed: store.finishFocus,
                  icon: const Icon(Icons.flag),
                  label: const Text('지금 끝내기'),
                ),
                TextButton(
                  onPressed: () => _confirmCancel(context),
                  child: const Text('취소 (기록 안 함)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이 블록을 기록하지 않고 취소할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (ok == true) store.cancel();
  }
}

/// 세션 종료 인출: 방금 배운 것을 떠올려 적으면 기억이 더 단단해집니다.
class _RecallView extends StatefulWidget {
  final AppStore store;
  const _RecallView({required this.store});

  @override
  State<_RecallView> createState() => _RecallViewState();
}

class _RecallViewState extends State<_RecallView> {
  final _note = TextEditingController();
  int? _rating;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.store.timer;
    final subject = widget.store.subject(t.subjectId);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '수고했어요! ${subject?.name ?? ''} ${formatDuration(t.completedFocusSec ?? 0)} 집중',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text('책을 덮고, 방금 배운 것을 보지 않고 떠올려 적어 보세요. 짧아도 괜찮아요.'),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '떠올린 것',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('이번 블록 집중도'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 1; i <= 5; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: _rating == i,
                onSelected: (_) => setState(() => _rating = i),
              ),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => widget.store.submitRecall(
            rating: _rating,
            note: _note.text.trim(),
          ),
          child: const Text('저장하고 조용한 휴식 시작'),
        ),
      ],
    );
  }
}
