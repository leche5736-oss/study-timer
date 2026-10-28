import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'dock.dart';
import 'session_editor.dart';

/// 에어팟 고개 각도 기록이 있으면 " · 고개 숙임 N분" (1분 미만이면 빈 글자).
String _postureText(Map<String, dynamic>? p) {
  final down = (p?['down'] as num?)?.toInt() ?? 0;
  return down < 60 ? '' : ' · 고개 숙임 ${down ~/ 60}분';
}

String _formatDate(DateTime utc) {
  final d = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
}

class HistoryTab extends StatelessWidget {
  final AppStore store;
  const HistoryTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final sessions = store.sessions;
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '끝낸 집중 블록이 여기에 쌓여요.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openEditor(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('기록 추가'),
            ),
          ],
        ),
      );
    }
    // 목록을 아래로 당기면 기록 추가.
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => _openEditor(context, null),
      child: _list(context, sessions),
    );
  }

  void _openEditor(BuildContext context, StudySession? s) {
    if (store.subjects.isEmpty && s == null) {
      showDockSnack(context, '먼저 과목을 추가하세요.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionEditor(store: store, session: s),
      ),
    );
  }

  Widget _list(BuildContext context, List<StudySession> sessions) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sessions.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '↓ 당겨서 기록 추가',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.faint, fontSize: 12),
            ),
          );
        }
        final s = sessions[i - 1];
        final subject = store.subject(s.subjectId);
        return ExpansionTile(
          leading: CircleAvatar(
            radius: 8,
            backgroundColor: subject?.colorValue ?? Colors.grey,
          ),
          title: Text(
            '${subject?.name ?? '(삭제된 과목)'} · ${formatDuration(s.focusSeconds)}',
          ),
          subtitle: Text(
            '${_formatDate(s.startedAt)}'
            '${s.book.isEmpty ? '' : ' · ${s.book}${s.progress.isEmpty ? '' : ' ${s.progress}까지'}'}'
            '${s.focusRating == null ? '' : ' · 집중도 ${s.focusRating}'}'
            '${RestType.byName(s.restType) == null ? '' : ' · 휴식: ${RestType.byName(s.restType)!.label}'}'
            '${s.distractions == 0 ? '' : ' · 딴짓 ${s.distractions}회 ${formatDuration(s.distractedSeconds)}'}'
            '${_postureText(s.posture)}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.recallNote.isNotEmpty) ...[
              const Text(
                '정리 노트',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(s.recallNote),
              const SizedBox(height: 8),
            ],
            if (s.question.isNotEmpty) ...[
              const Text(
                '스스로 낸 문제',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(s.question),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openEditor(context, s),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('수정'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, s),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('이 기록 삭제'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, StudySession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) store.deleteSession(s.id);
  }
}
