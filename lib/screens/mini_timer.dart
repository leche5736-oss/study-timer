import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';

/// 작은 창에 띄우는 타이머. Mac에서는 다른 창들 위에 떠 있습니다.
class MiniTimer extends StatelessWidget {
  final AppStore store;
  final VoidCallback onExpand;
  const MiniTimer({super.key, required this.store, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final t = store.timer;
    final now = store.now;
    final subject = store.subject(t.subjectId);
    final rest = t.phase == Phase.rest;
    final shown = t.stopwatch && !rest
        ? t.elapsedSec(now)
        : t.remainingSec(now);
    final label = rest
        ? (t.longRest ? '긴 휴식' : '휴식')
        : '${subject?.name ?? ''}${t.isRunning ? '' : ' · 일시정지'}';
    final fg = rest ? const Color(0xFF8A8F98) : null;

    return Scaffold(
      backgroundColor: rest ? Colors.black : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (!rest)
                  CircleAvatar(
                    radius: 5,
                    backgroundColor: subject?.colorValue ?? Colors.grey,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg),
                  ),
                ),
                if (t.distractions > 0 && !rest)
                  Text(
                    '딴짓 ${t.distractions}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
            Expanded(
              child: FittedBox(
                child: Text(
                  formatClock(shown),
                  style: TextStyle(
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!rest)
                  IconButton(
                    tooltip: t.isRunning ? '일시정지' : '계속',
                    icon: Icon(t.isRunning ? Icons.pause : Icons.play_arrow),
                    onPressed: t.isRunning ? store.pause : store.resume,
                  ),
                if (!rest)
                  IconButton(
                    tooltip: '끝내기',
                    icon: const Icon(Icons.flag),
                    onPressed: store.finishFocus,
                  ),
                IconButton(
                  tooltip: '크게 보기',
                  icon: Icon(Icons.open_in_full, color: fg),
                  onPressed: onExpand,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
