import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import 'dock.dart';

class SubjectsTab extends StatelessWidget {
  final AppStore store;
  const SubjectsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final subjects = store.subjects;
    // 꾹 눌러 끌면 순서가 바뀌고, 왼쪽으로 밀면 삭제, 오른쪽으로 밀면 책.
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) {
        final ids = subjects.map((s) => s.id).toList();
        ids.insert(to, ids.removeAt(from));
        store.reorderSubjects(ids);
      },
      footer: _AddRow(
        label: '과목 추가',
        onTap: () async {
          final name = await _askName(context, title: '과목 추가');
          if (name != null) store.addSubject(name);
        },
      ),
      children: [
        for (final (i, s) in subjects.indexed)
          ReorderableDelayedDragStartListener(
            key: ValueKey(s.id),
            index: i,
            child: _row(context, s),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Subject s) {
    // 왼쪽으로 밀면 삭제. 책·이름은 줄을 눌러 여는 창에서 고칩니다.
    return Dismissible(
      key: ValueKey('swipe-${s.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: Container(
        color: const Color(0xFFE5484D),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Text(
          '삭제',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      onDismissed: (_) => _delete(context, s),
      child: GestureDetector(
        // Mac: 오른쪽 클릭 메뉴
        onSecondaryTapUp: (d) => _menu(context, s, d.globalPosition),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 24),
          // 색 동그라미를 누르면 바로 옆에 색이 펼쳐집니다.
          leading: Builder(
            builder: (dotContext) => InkResponse(
              key: ValueKey('dot-${s.id}'),
              radius: 20,
              onTap: () => _pickColor(dotContext, s),
              child: SizedBox(
                width: 32,
                height: 40,
                child: Center(
                  child: CircleAvatar(radius: 7, backgroundColor: s.colorValue),
                ),
              ),
            ),
          ),
          minLeadingWidth: 32,
          horizontalTitleGap: 8,
          title: Text(s.name, style: const TextStyle(fontSize: 17)),
          trailing: s.books.isEmpty
              ? null
              : Text(
                  '책 ${s.books.length}',
                  style: const TextStyle(color: AppColors.faint, fontSize: 13),
                ),
          onTap: () => openSubjectSheet(context, store, s.id),
        ),
      ),
    );
  }

  /// 동그라미 옆에 색 줄을 띄우고, 고르면 바로 바뀝니다.
  Future<void> _pickColor(BuildContext dotContext, Subject s) async {
    final box = dotContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(dotContext).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final color = await showMenu<int>(
      context: dotContext,
      position: RelativeRect.fromLTRB(
        topLeft.dx + box.size.width,
        topLeft.dy,
        overlay.size.width - topLeft.dx - box.size.width,
        overlay.size.height - topLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      items: [_ColorStrip(selected: s.color)],
    );
    if (color != null) store.setSubjectColor(s.id, color);
  }

  /// 지우고 바로 되돌릴 수 있게 알려 줍니다.
  void _delete(BuildContext context, Subject s) {
    store.deleteSubject(s.id);
    showDockSnack(
      context,
      '"${s.name}" 삭제함 · 지난 기록은 통계에 남아요',
      actionLabel: '되돌리기',
      onAction: () => store.restoreSubject(s.id),
    );
  }

  Future<void> _menu(BuildContext context, Subject s, Offset at) async {
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: const [
        PopupMenuItem(value: 'books', child: Text('책 · 이름')),
        PopupMenuItem(value: 'delete', child: Text('삭제')),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case 'books':
        openSubjectSheet(context, store, s.id);
      case 'delete':
        _delete(context, s);
    }
  }
}

/// 과목 시트: 이름과 책을 고칩니다 (색은 목록의 동그라미에서).
Future<void> openSubjectSheet(
  BuildContext context,
  AppStore store,
  String subjectId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _SubjectSheet(store: store, subjectId: subjectId),
  );
}

class _SubjectSheet extends StatefulWidget {
  final AppStore store;
  final String subjectId;
  const _SubjectSheet({required this.store, required this.subjectId});

  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet> {
  AppStore get store => widget.store;
  late final _name = TextEditingController(
    text: store.subject(widget.subjectId)?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    final n = _name.text.trim();
    final s = store.subject(widget.subjectId);
    if (s != null && n.isNotEmpty && n != s.name) store.renameSubject(s.id, n);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.subject(widget.subjectId);
        if (s == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              children: [
                TextField(
                  key: const Key('subject-name'),
                  controller: _name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '과목 이름',
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _saveName(),
                  onTapOutside: (_) => _saveName(),
                ),
                const SizedBox(height: 24),
                const Text(
                  '책',
                  style: TextStyle(color: AppColors.grey, fontSize: 13),
                ),
                for (final b in s.books)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(b),
                    trailing: IconButton(
                      tooltip: '빼기',
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.faint,
                      onPressed: () => store.setSubjectBooks(
                        s.id,
                        s.books.where((x) => x != b).toList(),
                      ),
                    ),
                  ),
                _AddRow(
                  label: '새 책',
                  padding: EdgeInsets.zero,
                  onTap: () async {
                    final name = await askBookName(context, s.name);
                    if (name != null) {
                      store.setSubjectBooks(s.id, [...s.books, name]);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 목록 맨 아래의 옅은 "+ 추가" 줄.
class _AddRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final EdgeInsets padding;
  const _AddRow({
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: padding,
    leading: const Icon(Icons.add, size: 20, color: AppColors.grey),
    minLeadingWidth: 12,
    title: Text(label, style: const TextStyle(color: AppColors.grey)),
    onTap: onTap,
  );
}

/// 책 이름 묻기. 빈 칸이면 null.
Future<String?> askBookName(BuildContext context, String subjectName) async {
  final c = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$subjectName 새 책'),
      content: TextField(
        key: const Key('book-add'),
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
  return n.isEmpty ? null : n;
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

/// 색 고르기 줄: 동그라미 여러 개를 한 줄(넘치면 두 줄)로.
class _ColorStrip extends PopupMenuEntry<int> {
  final int selected;
  const _ColorStrip({required this.selected});

  @override
  double get height => 48;

  @override
  bool represents(int? value) => false;

  @override
  State<_ColorStrip> createState() => _ColorStripState();
}

class _ColorStripState extends State<_ColorStrip> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final color in AppStore.palette)
            InkResponse(
              key: ValueKey('color-$color'),
              radius: 18,
              onTap: () => Navigator.pop(context, color),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Color(color),
                child: color == widget.selected
                    ? const Icon(Icons.check, size: 16, color: AppColors.ink)
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}
