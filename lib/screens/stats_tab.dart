import 'package:flutter/material.dart';

import '../services/store.dart';
import '../stats.dart';

class StatsTab extends StatefulWidget {
  final AppStore store;
  const StatsTab({super.key, required this.store});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  StatsRange _range = StatsRange.day;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final totals = totalsBySubject(store.allSessions, _range, DateTime.now());
    final sum = totals.fold<int>(0, (a, t) => a + t.seconds);
    final max = totals.isEmpty ? 1 : totals.first.seconds;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SegmentedButton<StatsRange>(
          segments: [
            for (final r in StatsRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          onSelectionChanged: (v) => setState(() => _range = v.first),
        ),
        const SizedBox(height: 24),
        Text(
          '${_range.label} 총 공부 시간',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          formatDuration(sum),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        if (totals.isEmpty) const Text('이 기간에는 아직 기록이 없어요.'),
        for (final t in totals) ...[
          Builder(
            builder: (context) {
              final subject = store.subject(t.subjectId);
              final rating = t.avgRating == null
                  ? ''
                  : ' · 집중도 평균 ${t.avgRating!.toStringAsFixed(1)}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(subject?.name ?? '(삭제된 과목)')),
                      Text(formatDuration(t.seconds)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: max == 0 ? 0 : t.seconds / max,
                    color: subject?.colorValue,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.sessions}블록$rating',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
