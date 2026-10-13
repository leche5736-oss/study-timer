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
              onReorderItem: (from, to) {
                final ids = subjects.map((s) => s.id).toList();
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
                        // 색 동그라미를 누르면 바로 색을 고릅니다.
                        IconButton(
                          tooltip: '색 바꾸기',
                          onPressed: () async {
                            final color = await _askColor(context, s);
                            if (color != null) {
                              store.setSubjectColor(s.id, color);
                            }
                          },
                          icon: CircleAvatar(
                            backgroundColor: s.colorValue,
                            radius: 10,
                          ),
                        ),
                      ],
                    ),
                    title: Text(s.name),
                    subtitle: s.books.isEmpty
                        ? null
                        : Text(
                            s.books.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.grey),
                          ),
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
                          tooltip: '책',
                          icon: const Icon(Icons.menu_book_outlined),
                          onPressed: () => _editBooks(context, s.id),
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

  /// 과목에서 쓰는 책 목록. 공부를 마칠 때 여기서 책을 골라 진도를 적습니다.
  Future<void> _editBooks(BuildContext context, String subjectId) {
    final add = TextEditingController();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.subject(subjectId);
          if (s == null) return const SizedBox.shrink();
          void submit() {
            final name = add.text.trim();
            if (name.isEmpty) return;
            store.setSubjectBooks(s.id, [...s.books, name]);
            add.clear();
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text(
                    '${s.name} 책',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '공부를 마칠 때 책을 고르고 어디까지 봤는지 적을 수 있어요.',
                    style: TextStyle(color: AppColors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final b in s.books)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(b),
                      trailing: IconButton(
                        tooltip: '빼기',
                        icon: const Icon(Icons.close),
                        onPressed: () => store.setSubjectBooks(
                          s.id,
                          s.books.where((x) => x != b).toList(),
                        ),
                      ),
                    ),
                  TextField(
                    key: const Key('book-add'),
                    controller: add,
                    decoration: InputDecoration(
                      hintText: '책 이름 (예: 민법의 맥 (윤동환))',
                      suffixIcon: IconButton(
                        tooltip: '추가',
                        icon: const Icon(Icons.add),
                        onPressed: submit,
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ),
          );
        },
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
