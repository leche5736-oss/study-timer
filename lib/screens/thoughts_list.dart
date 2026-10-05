import 'package:flutter/material.dart';

import '../services/store.dart';

/// 집중 중 적어 둔 딴생각 메모. 처리하면 체크하고, 다 지울 수 있습니다.
class ThoughtsList extends StatelessWidget {
  final AppStore store;

  /// 휴식 화면처럼 어두운 배경 위에 그릴 때 쓰는 글자색.
  final Color? textColor;
  const ThoughtsList({super.key, required this.store, this.textColor});

  @override
  Widget build(BuildContext context) {
    final notes = store.thoughts;
    if (notes.isEmpty) return const SizedBox.shrink();
    final open = notes.where((n) => !n.done).length;
    final style = TextStyle(color: textColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '딴생각 메모 ($open개 남음)',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: textColor),
              ),
            ),
            if (open < notes.length)
              TextButton(
                onPressed: store.clearDoneThoughts,
                child: Text('처리한 것 지우기', style: style),
              ),
          ],
        ),
        for (final n in notes)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: n.done,
            onChanged: (_) => store.toggleThought(n.id),
            title: Text(
              n.text,
              style: style.copyWith(
                decoration: n.done ? TextDecoration.lineThrough : null,
              ),
            ),
            secondary: IconButton(
              tooltip: '메모 삭제',
              icon: Icon(Icons.close, size: 18, color: textColor),
              onPressed: () => store.deleteThought(n.id),
            ),
          ),
      ],
    );
  }
}
