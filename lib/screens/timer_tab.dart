import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'idle_view.dart';

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
      Phase.idle => IdleView(store: store, onGoToSubjects: onGoToSubjects),
      Phase.focus => const SizedBox.shrink(), // HomeScreen이 집중 화면을 보여줌
      Phase.recall => _RecallView(store: store),
      Phase.rest => const SizedBox.shrink(), // HomeScreen이 휴식 화면을 보여줌
    };
  }
}

/// 세션 종료 인출: 방금 공부한 것을 보지 않고 정리하면 기억이 더 단단해집니다.
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
    const grey = TextStyle(color: AppColors.grey, fontSize: 15);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${subject?.name ?? ''} · ${formatHms(t.completedFocusSec ?? 0)}',
              textAlign: TextAlign.center,
              style: grey,
            ),
            const SizedBox(height: 8),
            const Text(
              '수고했어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _note,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '정리 노트\n책을 덮고, 방금 공부한 내용을 떠올려 적어 보세요.',
                hintStyle: TextStyle(color: AppColors.grey),
              ),
            ),
            const SizedBox(height: 32),
            const Text('집중도', textAlign: TextAlign.center, style: grey),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _RatingDot(
                      value: i,
                      selected: _rating == i,
                      onTap: () =>
                          setState(() => _rating = _rating == i ? null : i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => widget.store.submitRecall(
                rating: _rating,
                note: _note.text.trim(),
              ),
              child: const Text('저장하고 휴식'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingDot extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _RatingDot({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.fill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 17,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
