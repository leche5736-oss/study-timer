import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';

class SubjectsTab extends StatelessWidget {
  final AppStore store;
  const SubjectsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final subjects = store.subjects;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _askName(context, title: '과목 추가');
          if (name != null) store.addSubject(name);
        },
        icon: const Icon(Icons.add),
        label: const Text('과목 추가'),
      ),
      body: subjects.isEmpty
          ? const Center(child: Text('아직 과목이 없어요. 아래 버튼으로 추가하세요.'))
          // 왼쪽 손잡이를 잡고 끌어서 순서를 바꿉니다.
          : ReorderableListView(
              buildDefaultDragHandles: false,
              onReorder: (from, to) {
                final ids = subjects.map((s) => s.id).toList();
                if (to > from) to--;
                ids.insert(to, ids.removeAt(from));
                store.reorderSubjects(ids);
              },
              children: [
                for (final (i, s) in subjects.indexed)
                  ListTile(
                    key: ValueKey(s.id),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: AppColors.faint,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(backgroundColor: s.colorValue, radius: 10),
                      ],
                    ),
                    title: Text(s.name),
                    onTap: () async {
                      final name = await _askName(
                        context,
                        title: '이름 바꾸기',
                        initial: s.name,
                      );
                      if (name != null) store.renameSubject(s.id, name);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '색 바꾸기',
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () async {
                            final color = await _askColor(context, s);
                            if (color != null) {
                              store.setSubjectColor(s.id, color);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: '삭제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, s),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Subject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('"${s.name}" 과목을 삭제할까요?'),
        content: const Text('지난 기록은 통계에 그대로 남습니다.'),
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
    if (ok == true) store.deleteSubject(s.id);
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) {
      void submit() {
        final v = controller.text.trim();
        if (v.isNotEmpty) Navigator.pop(c, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 영어, 수학'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          FilledButton(onPressed: submit, child: const Text('저장')),
        ],
      );
    },
  );
}

Future<int?> _askColor(BuildContext context, Subject s) {
  return showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('"${s.name}" 색 고르기'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final color in AppStore.palette)
            InkWell(
              key: ValueKey('color-$color'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(c, color),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(color),
                child: color == s.color
                    ? const Icon(Icons.check, color: AppColors.ink)
                    : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ],
    ),
  );
}
