import 'package:flutter/material.dart';

import '../models.dart';
import '../services/export.dart';
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
  bool _heatRating = false; // false: 공부량, true: 집중도
  TrendUnit _trendUnit = TrendUnit.week;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final now = DateTime.now();
    final sessions = store.allSessions;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _section(theme, '과목별 공부 시간'),
        _totals(theme, sessions, now),
        const Divider(height: 48),
        _section(theme, '시간대별 집중도 (최근 30일)'),
        _heatmap(theme, sessions, now),
        const Divider(height: 48),
        _section(theme, '과목별 추이'),
        _trend(theme, sessions, now),
        const Divider(height: 48),
        _section(theme, '집중 길이별 집중도'),
        _lengths(theme, sessions),
        const Divider(height: 48),
        _section(theme, '휴식 방식별 다음 블록 집중도'),
        _rests(theme, sessions),
        const Divider(height: 48),
        OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('기록 전체 내보내기 (CSV)'),
          onPressed: () async {
            final d = DateTime.now();
            final name =
                '공부기록_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.csv';
            final msg = await exportCsv(
              sessionsCsv(sessions, store.subject),
              name,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        ),
      ],
    );
  }

  Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: theme.textTheme.titleMedium),
  );

  Widget _empty(ThemeData theme, String text) =>
      Text(text, style: theme.textTheme.bodySmall);

  // ---------- 기간별 합계 ----------

  Widget _totals(ThemeData theme, List<StudySession> sessions, DateTime now) {
    final store = widget.store;
    final totals = totalsBySubject(sessions, _range, now);
    final sum = totals.fold<int>(0, (a, t) => a + t.seconds);
    final max = totals.isEmpty ? 1 : totals.first.seconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<StatsRange>(
          segments: [
            for (final r in StatsRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          onSelectionChanged: (v) => setState(() => _range = v.first),
        ),
        const SizedBox(height: 16),
        Text('${_range.label} 총 공부 시간', style: theme.textTheme.bodyMedium),
        Text(formatDuration(sum), style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (totals.isEmpty) _empty(theme, '이 기간에는 아직 기록이 없어요.'),
        for (final t in totals)
          Builder(
            builder: (context) {
              final subject = store.subject(t.subjectId);
              final rating = t.avgRating == null
                  ? ''
                  : ' · 집중도 평균 ${t.avgRating!.toStringAsFixed(1)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
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
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ---------- 히트맵 ----------

  Widget _heatmap(ThemeData theme, List<StudySession> sessions, DateTime now) {
    final since = DateTime(now.year, now.month, now.day - 29);
    final map = buildHeatmap(sessions, since);
    final maxSec = map.maxSeconds;
    final best = bestFocusWindow(map);
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final base = theme.colorScheme.primary;

    Color colorFor(HeatCell c) {
      if (c.seconds == 0) return theme.colorScheme.surfaceContainerHighest;
      if (_heatRating) {
        final r = c.avgRating;
        if (r == null) return theme.colorScheme.surfaceContainerHighest;
        // 집중도 1 → 빨강, 3 → 노랑, 5 → 초록
        return Color.lerp(
          const Color(0xFFE15759),
          const Color(0xFF59A14F),
          (r - 1) / 4,
        )!;
      }
      return base.withValues(alpha: 0.15 + 0.85 * c.seconds / maxSec);
    }

    String tip(int d, int h, HeatCell c) {
      final rating = c.avgRating == null
          ? ''
          : ', 집중도 ${c.avgRating!.toStringAsFixed(1)}';
      return '${days[d]} $h시: ${formatDuration(c.seconds)}$rating';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('공부량')),
            ButtonSegment(value: true, label: Text('집중도')),
          ],
          selected: {_heatRating},
          onSelectionChanged: (v) => setState(() => _heatRating = v.first),
        ),
        const SizedBox(height: 12),
        if (maxSec == 0)
          _empty(theme, '최근 30일 기록이 쌓이면 요일·시간대별로 보여줘요.')
        else
          LayoutBuilder(
            builder: (context, box) {
              const labelW = 20.0;
              final cell = ((box.maxWidth - labelW) / 24).clamp(6.0, 28.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var d = 0; d < 7; d++)
                    Row(
                      children: [
                        SizedBox(
                          width: labelW,
                          child: Text(
                            days[d],
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        for (var h = 0; h < 24; h++)
                          Tooltip(
                            message: tip(d, h, map.cells[d][h]),
                            child: Container(
                              width: cell - 1,
                              height: cell - 1,
                              margin: const EdgeInsets.all(0.5),
                              color: colorFor(map.cells[d][h]),
                            ),
                          ),
                      ],
                    ),
                  Row(
                    children: [
                      const SizedBox(width: labelW),
                      for (final h in [0, 6, 12, 18])
                        SizedBox(
                          width: cell * 6,
                          child: Text('$h시', style: theme.textTheme.bodySmall),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        if (best != null)
          Text(
            '${best.startHour}~${best.startHour + 2}시에 집중도가 가장 높아요 '
            '(평균 ${best.avgRating.toStringAsFixed(1)}). 어려운 과목을 이때 해 보세요.',
          )
        else if (maxSec > 0)
          _empty(theme, '집중도를 남긴 기록이 시간대별로 더 쌓이면 가장 집중 잘 되는 시간을 알려 드려요.'),
      ],
    );
  }

  // ---------- 추이 ----------

  Widget _trend(ThemeData theme, List<StudySession> sessions, DateTime now) {
    final store = widget.store;
    final periods = buildTrend(
      sessions,
      _trendUnit,
      now,
      count: _trendUnit == TrendUnit.week ? 8 : 6,
    );
    final maxTotal = periods.fold<int>(0, (m, p) => p.total > m ? p.total : m);
    final subjectIds = {for (final p in periods) ...p.secondsBySubject.keys}
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TrendUnit>(
          segments: const [
            ButtonSegment(value: TrendUnit.week, label: Text('주별 (8주)')),
            ButtonSegment(value: TrendUnit.month, label: Text('월별 (6개월)')),
          ],
          selected: {_trendUnit},
          onSelectionChanged: (v) => setState(() => _trendUnit = v.first),
        ),
        const SizedBox(height: 12),
        if (maxTotal == 0)
          _empty(theme, '이 기간에는 아직 기록이 없어요.')
        else ...[
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in periods)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${p.label}: ${formatDuration(p.total)}\n${p.secondsBySubject.entries.map((e) => '${store.subject(e.key)?.name ?? '(삭제된 과목)'} ${formatDuration(e.value)}').join('\n')}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final id in subjectIds)
                              if ((p.secondsBySubject[id] ?? 0) > 0)
                                Container(
                                  height:
                                      140 * p.secondsBySubject[id]! / maxTotal,
                                  color:
                                      store.subject(id)?.colorValue ??
                                      Colors.grey,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              for (final p in periods)
                Expanded(
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final id in subjectIds)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor:
                          store.subject(id)?.colorValue ?? Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      store.subject(id)?.name ?? '(삭제된 과목)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ---------- 집중 길이 ----------

  Widget _lengths(ThemeData theme, List<StudySession> sessions) {
    final stats = focusByLength(sessions);
    final rec = recommendLength(sessions);
    if (stats.isEmpty) {
      return _empty(theme, '집중도를 남긴 기록이 쌓이면 어떤 길이가 나에게 맞는지 보여줘요.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in stats)
          _ratingRow(theme, b.bucket.label, b.avgRating, b.count),
        const SizedBox(height: 8),
        Text(
          rec == null
              ? '길이별로 3번 이상 기록이 쌓이면 추천해 드려요.'
              : '추천: ${rec.bucket.label} 블록(예: ${rec.bucket.suggestMin}분)에서 집중이 가장 잘 됐어요.',
        ),
      ],
    );
  }

  // ---------- 휴식 방식 ----------

  Widget _rests(ThemeData theme, List<StudySession> sessions) {
    final stats = restComparison(sessions);
    if (stats.isEmpty) {
      return _empty(theme, '휴식 화면에서 "휴식 중 한 일"을 눌러 두면, 그다음 블록의 집중도와 비교해 보여줘요.');
    }
    return Column(
      children: [
        for (final r in stats)
          _ratingRow(theme, r.type.label, r.avgNextRating, r.count),
      ],
    );
  }

  Widget _ratingRow(ThemeData theme, String label, double avg, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(value: avg / 5, minHeight: 8),
          ),
          const SizedBox(width: 8),
          Text(
            '${avg.toStringAsFixed(1)} ($count번)',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
