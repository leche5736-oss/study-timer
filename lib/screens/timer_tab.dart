import 'package:flutter/material.dart';

import '../models.dart';
import '../timer_logic.dart';
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
  final _progress = TextEditingController();
  int? _rating;
  String? _book; // 고른 책 (null = 안 적음)
  bool _bookInit = false;

  @override
  void dispose() {
    _note.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// 책 추가 창. 추가한 책은 과목에 저장되고 바로 골라집니다.
  Future<void> _addBook(Subject subject) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${subject.name} 책 추가'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 민법의 맥 (윤동환)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    final n = name?.trim() ?? '';
    if (n.isEmpty || !mounted) return;
    widget.store.setSubjectBooks(subject.id, [...subject.books, n]);
    setState(() => _book = n);
  }

  /// 어느 책을 어디까지 봤는지 (Claude가 진도를 보고 계획을 세울 때 씁니다).
  List<Widget> _bookSection(Subject subject, TextStyle grey) {
    final store = widget.store;
    if (!_bookInit) {
      _bookInit = true;
      final last = store.lastProgress(subject.id);
      if (last != null && subject.books.contains(last.book)) _book = last.book;
    }
    final last = _book == null
        ? null
        : store.lastProgress(subject.id, book: _book);
    return [
      Text('어디까지 봤나요', textAlign: TextAlign.center, style: grey),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final b in subject.books)
            ChoiceChip(
              label: Text(b),
              selected: _book == b,
              onSelected: (on) => setState(() => _book = on ? b : null),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('책 추가'),
            onPressed: () => _addBook(subject),
          ),
        ],
      ),
      if (_book != null) ...[
        const SizedBox(height: 8),
        TextField(
          key: const Key('recall-progress'),
          controller: _progress,
          decoration: InputDecoration(
            hintText: '어디까지 (예: 120쪽, 3장 2절)',
            hintStyle: const TextStyle(color: AppColors.grey),
            helperText: last == null || last.progress.isEmpty
                ? null
                : '지난번: ${last.progress}',
          ),
        ),
      ],
      const SizedBox(height: 24),
    ];
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
            if (subject != null) ..._bookSection(subject, grey),
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
                book: _book ?? '',
                progress: _book == null ? '' : _progress.text,
              ),
              child: Text(TimerLogic.restFollows(t) ? '저장하고 휴식' : '저장하고 마치기'),
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
      color: selected ? AppColors.accent : AppColors.fill,
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
