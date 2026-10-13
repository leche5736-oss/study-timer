import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import 'subjects_tab.dart';

/// 책 고르기 결과. [book]이 빈 칸이면 "책 안 적기".
typedef BookPick = ({String subjectId, String book});

/// 책 고르기 시트: 맨 위 검색, 이 과목 책(최근 쓴 순), 다른 과목 책(접혀 있음),
/// 맨 아래 "+ 새 책". 닫으면 null.
Future<BookPick?> pickBook(
  BuildContext context,
  AppStore store, {
  required String subjectId,
  String? current,
}) => showModalBottomSheet<BookPick>(
  context: context,
  isScrollControlled: true,
  builder: (c) =>
      _BookSheet(store: store, subjectId: subjectId, current: current),
);

class _BookSheet extends StatefulWidget {
  final AppStore store;
  final String subjectId;
  final String? current;
  const _BookSheet({
    required this.store,
    required this.subjectId,
    this.current,
  });

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  final _query = TextEditingController();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _match(String book) {
    final q = _query.text.trim().toLowerCase();
    return q.isEmpty || book.toLowerCase().contains(q);
  }

  Widget _book(Subject s, String b) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    title: Text(b),
    trailing: s.id == widget.subjectId && b == widget.current
        ? Icon(Icons.check, color: AppColors.accent)
        : null,
    onTap: () => Navigator.pop(context, (subjectId: s.id, book: b)),
  );

  Future<void> _addNew(Subject s) async {
    final typed = _query.text.trim();
    final name = typed.isNotEmpty ? typed : await askBookName(context, s.name);
    if (name == null || !mounted) return;
    if (!s.books.contains(name)) {
      store.setSubjectBooks(s.id, [...s.books, name]);
    }
    Navigator.pop(context, (subjectId: s.id, book: name));
  }

  @override
  Widget build(BuildContext context) {
    final subject = store.subject(widget.subjectId);
    if (subject == null) return const SizedBox.shrink();
    final searching = _query.text.trim().isNotEmpty;
    final mine = store.recentBooks(subject.id).where(_match).toList();
    final others = [
      for (final s in store.subjects)
        if (s.id != subject.id && s.books.any(_match)) s,
    ];
    const label = TextStyle(color: AppColors.grey, fontSize: 13);
    final typed = _query.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: TextField(
                  key: const Key('book-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '책 찾기',
                    prefixIcon: Icon(Icons.search, color: AppColors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(subject.name, style: label),
              ),
              for (final b in mine) _book(subject, b),
              if (others.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text('다른 과목', style: label),
                ),
                for (final s in others)
                  ExpansionTile(
                    // 찾는 중에는 펼쳐서 바로 보이게.
                    key: ValueKey('${s.id}-$searching'),
                    initiallyExpanded: searching,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: const Border(),
                    leading: CircleAvatar(
                      radius: 5,
                      backgroundColor: s.colorValue,
                    ),
                    title: Text(s.name),
                    children: [
                      for (final b in s.books)
                        if (_match(b)) _book(s, b),
                    ],
                  ),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.add, size: 20, color: AppColors.grey),
                minLeadingWidth: 12,
                title: Text(
                  typed.isEmpty ? '새 책' : '"$typed" 새 책으로 추가',
                  style: const TextStyle(color: AppColors.grey),
                ),
                onTap: () => _addNew(subject),
              ),
              if (widget.current != null)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: const Text(
                    '책 안 적기',
                    style: TextStyle(color: AppColors.grey),
                  ),
                  onTap: () =>
                      Navigator.pop(context, (subjectId: subject.id, book: '')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
