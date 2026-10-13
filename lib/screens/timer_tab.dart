import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../timer_logic.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'book_picker.dart';
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

  /// 다른 과목 책을 고르고 과목도 바꾸기로 했을 때 그 과목.
  String? _subjectId;

  @override
  void dispose() {
    _note.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _pickBook(Subject subject) async {
    final store = widget.store;
    final picked = await pickBook(
      context,
      store,
      subjectId: subject.id,
      current: _book,
    );
    if (picked == null || !mounted) return;
    var switchTo = _subjectId;
    if (picked.book.isNotEmpty && picked.subjectId != subject.id) {
      final other = store.subject(picked.subjectId);
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('이번 공부를 ${other?.name ?? ''}(으)로 바꿀까요?'),
          content: Text('"${picked.book}"은 ${other?.name ?? ''} 책이에요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('${subject.name} 그대로'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      );
      if (yes == null || !mounted) return;
      if (yes) switchTo = picked.subjectId;
    }
    setState(() {
      _subjectId = switchTo;
      _book = picked.book.isEmpty ? null : picked.book;
    });
  }

  /// 어느 책을 어디까지 봤는지 (Claude가 진도를 보고 계획을 세울 때 씁니다).
  /// 한 줄: [책 ▾ | 어디까지]. 숫자만 적으면 "쪽"이 붙습니다.
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
      Container(
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('recall-book'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickBook(subject),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.book,
                        size: 18,
                        color: AppColors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _book ?? '책 고르기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _book == null
                                ? AppColors.grey
                                : AppColors.ink,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_book != null) ...[
              Container(width: 1, height: 24, color: AppColors.line),
              SizedBox(
                width: 120,
                child: TextField(
                  key: const Key('recall-progress'),
                  controller: _progress,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '어디까지',
                    hintStyle: TextStyle(color: AppColors.grey),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onTapOutside: (_) => _autoPage(),
                  onSubmitted: (_) => _autoPage(),
                ),
              ),
            ],
          ],
        ),
      ),
      if (last != null && last.progress.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Text(
            '지난번 ${last.progress}',
            textAlign: TextAlign.right,
            style: grey.copyWith(fontSize: 13),
          ),
        ),
      const SizedBox(height: 24),
    ];
  }

  /// 숫자만 적었으면 "쪽"을 붙여 보여 줍니다.
  void _autoPage() {
    final v = normalizeProgress(_progress.text);
    if (v != _progress.text) _progress.text = v;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.store.timer;
    final subject = widget.store.subject(_subjectId ?? t.subjectId);
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
                subjectId: _subjectId,
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
