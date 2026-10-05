import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';

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
      return const Center(child: Text('끝낸 집중 블록이 여기에 쌓여요.'));
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = sessions[i];
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
            '${_formatDate(s.startedAt)}${s.focusRating == null ? '' : ' · 집중도 ${s.focusRating}'}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.recallNote.isNotEmpty) ...[
              const Text('배운 것', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context, s),
                icon: const Icon(Icons.delete_outline),
                label: const Text('이 기록 삭제'),
              ),
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
