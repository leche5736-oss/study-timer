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
  TrendUnit _trendUnit = TrendUnit.day;
  late DateTime _month; // 달력에 보이는 달
  DateTime? _selectedDay; // 달력에서 고른 날

  int get _h => widget.store.settings.dayStartHour;

  @override
  void initState() {
    super.initState();
    final today = studyDate(DateTime.now(), _h);
    _month = DateTime(today.year, today.month);
    _selectedDay = today;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final now = DateTime.now();
    final sessions = store.allSessions;
    final theme = Theme.of(context);

    ListView page(List<Widget> children) =>
        ListView(padding: const EdgeInsets.all(24), children: children);

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '요약'),
              Tab(text: '달력'),
              Tab(text: '패턴'),
              Tab(text: '분석'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                page([
                  _summary(theme, sessions, now),
                  const Divider(height: 48),
                  _section(theme, '과목별 공부 시간'),
                  _totals(theme, sessions, now),
                  const Divider(height: 48),
                  _section(theme, '추이'),
                  _trend(theme, sessions, now),
                ]),
                page([
                  _calendar(theme, sessions, now),
                  const Divider(height: 48),
                  _dayDetail(theme, sessions),
                ]),
                page([
                  _section(theme, '최근 14일 공부 시간대'),
                  _recentTimelines(theme, sessions, now),
                  const Divider(height: 48),
                  _section(theme, '공부 시작·종료 규칙성 (최근 14일)'),
                  _regularity(theme, sessions, now),
                  const Divider(height: 48),
                  _section(theme, '시간대별 집중도 (최근 30일)'),
                  _heatmap(theme, sessions, now),
                ]),
                page([
                  _section(theme, '딴짓·딴생각 (최근 7일)'),
                  _distractions(theme, sessions, now),
                  const Divider(height: 48),
                  _section(theme, '집중 길이별 집중도'),
                  _lengths(theme, sessions),
                  const Divider(height: 48),
                  _section(theme, '휴식 방식별 다음 블록 집중도'),
                  _rests(theme, sessions),
                  const Divider(height: 48),
                  _csvButton(sessions),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _csvButton(List<StudySession> sessions) => OutlinedButton.icon(
    icon: const Icon(Icons.download),
    label: const Text('기록 전체 내보내기 (CSV)'),
    onPressed: () async {
      final d = DateTime.now();
      final name =
          '공부기록_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.csv';
      final msg = await exportCsv(
        sessionsCsv(sessions, widget.store.subject),
        name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    },
  );

  // ---------- 요약 ----------

  Widget _summary(ThemeData theme, List<StudySession> sessions, DateTime now) {
    final sum = periodSummary(sessions, _range, now, dayStartHour: _h);
    final prevLabel = switch (_range) {
      StatsRange.day => '어제 같은 시각',
      StatsRange.week => '지난주 같은 시점',
      StatsRange.month => '지난달 같은 시점',
    };
    final diff = sum.diff;
    final big = theme.textTheme.headlineMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('총 시간', style: theme.textTheme.bodyMedium),
                  Text(formatHms(sum.total), style: big),
                ],
              ),
            ),
            if (_range != StatsRange.day)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '하루 평균 (${sum.days}일)',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(formatHms(sum.dailyAverage), style: big),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$prevLabel 대비 ${diff >= 0 ? '+' : '-'}${formatHms(diff.abs())} '
          '(그때 ${formatHms(sum.previous)})',
          style: TextStyle(color: diff >= 0 ? Colors.green[700] : Colors.red),
        ),
      ],
    );
  }

  // ---------- 달력 ----------

  Color _dayColor(ThemeData theme, int sec) {
    final hours = sec / 3600;
    if (sec == 0) return Colors.transparent;
    final base = theme.colorScheme.primary;
    final level = hours >= 7
        ? 0.9
        : hours >= 5
        ? 0.65
        : hours >= 3
        ? 0.45
        : hours >= 1
        ? 0.28
        : 0.14;
    return base.withValues(alpha: level);
  }

  Widget _calendar(ThemeData theme, List<StudySession> sessions, DateTime now) {
    final totals = dailyTotals(sessions, dayStartHour: _h);
    final today = studyDate(now, _h);
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 시작
    var monthSum = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      monthSum += totals[DateTime(first.year, first.month, d)] ?? 0;
    }
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final small = theme.textTheme.bodySmall;

    Widget cell(int day) {
      final date = DateTime(first.year, first.month, day);
      final sec = totals[date] ?? 0;
      final selected = date == _selectedDay;
      return InkWell(
        onTap: () => setState(() => _selectedDay = date),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: _dayColor(theme, sec),
            border: selected
                ? Border.all(color: theme.colorScheme.onSurface, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontWeight: date == today ? FontWeight.bold : null,
                  decoration: date == today ? TextDecoration.underline : null,
                ),
              ),
              if (sec > 0) Text(formatHm(sec), style: small),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
            ),
            Text(
              '${first.year}년 ${first.month}월',
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              tooltip: '다음 달',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
            ),
            const Spacer(),
            Text('이 달 ${formatHms(monthSum)}', style: small),
          ],
        ),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(w, textAlign: TextAlign.center, style: small),
              ),
          ],
        ),
        for (var row = 0; row * 7 < lead + daysInMonth; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final day = row * 7 + col - lead + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox(height: 54);
                      }
                      return cell(day);
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (label, sec) in [
              ('1시간+', 3600),
              ('3+', 3 * 3600),
              ('5+', 5 * 3600),
              ('7+', 7 * 3600),
            ])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: _dayColor(theme, sec),
                child: Text(label, style: small),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dayDetail(ThemeData theme, List<StudySession> sessions) {
    final store = widget.store;
    final day = _selectedDay;
    if (day == null) return const SizedBox.shrink();
    final segs = dayTimeline(sessions, day, dayStartHour: _h);
    final blocks =
        sessions
            .where((s) => !s.deleted && studyDate(s.startedAt, _h) == day)
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final total = blocks.fold<int>(0, (a, s) => a + s.focusSeconds);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${day.year}년 ${day.month}월 ${day.day}일 (${weekdays[day.weekday - 1]}) · ${formatHms(total)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          _empty(theme, '이날은 기록이 없어요.')
        else ...[
          _TimelineBar(store: store, segments: segs, dayStartHour: _h),
          _hourAxis(theme),
          const SizedBox(height: 12),
          for (final s in blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 5,
                    backgroundColor:
                        store.subject(s.subjectId)?.colorValue ?? Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_hm(s.startedAt)}~${_hm(s.endedAt)}  ',
                    style: theme.textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Text(store.subject(s.subjectId)?.name ?? '(삭제된 과목)'),
                  ),
                  Text(formatHms(s.focusSeconds)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _hm(DateTime utc) {
    final t = utc.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 하루 시작 시각부터 6시간 간격 눈금.
  Widget _hourAxis(ThemeData theme) => Row(
    children: [
      for (var i = 0; i < 4; i++)
        Expanded(
          child: Text(
            '${(_h + 6 * i) % 24}시',
            style: theme.textTheme.bodySmall,
          ),
        ),
    ],
  );

  // ---------- 패턴 ----------

  Widget _recentTimelines(
    ThemeData theme,
    List<StudySession> sessions,
    DateTime now,
  ) {
    final today = studyDate(now, _h);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final small = theme.textTheme.bodySmall;
    final rows = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      final segs = dayTimeline(sessions, d, dayStartHour: _h);
      final total = segs.fold<int>(0, (a, s) => a + s.endMin - s.startMin);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  '${d.month}/${d.day} (${weekdays[d.weekday - 1]})',
                  style: small,
                ),
              ),
              Expanded(
                child: _TimelineBar(
                  store: widget.store,
                  segments: segs,
                  dayStartHour: _h,
                  height: 18,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  total == 0 ? '' : formatHm(total * 60),
                  textAlign: TextAlign.right,
                  style: small,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ...rows,
        Row(
          children: [
            const SizedBox(width: 72),
            Expanded(child: _hourAxis(theme)),
            const SizedBox(width: 56),
          ],
        ),
      ],
    );
  }

  Widget _regularity(
    ThemeData theme,
    List<StudySession> sessions,
    DateTime now,
  ) {
    final r = studyRegularity(sessions, now, dayStartHour: _h);
    if (r == null) {
      return _empty(theme, '공부한 날이 이틀 이상 쌓이면 시작·종료 시각이 얼마나 일정한지 보여줘요.');
    }
    String clock(double m) => clockFromDayStart(m.round(), _h);
    String spread(double m) =>
        m < 60 ? '±${m.round()}분' : '±${(m / 60).toStringAsFixed(1)}시간';
    final small = theme.textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('평균 시작 ${clock(r.avgStart)} (${spread(r.startSpread)})'),
        Text('평균 종료 ${clock(r.avgEnd)} (${spread(r.endSpread)})'),
        const SizedBox(height: 4),
        Text(
          r.startSpread <= 30
              ? '시작 시각이 꽤 일정해요. 같은 시간에 시작하는 습관은 공부를 시작하는 부담을 줄여 줘요.'
              : '시작 시각이 들쭉날쭉해요. 매일 비슷한 시각에 시작하면 습관이 되기 쉬워요.',
          style: small,
        ),
        const SizedBox(height: 12),
        for (final d in r.days.reversed)
          Text(
            '${d.date.month}/${d.date.day}  ${clockFromDayStart(d.firstStartMin, _h)} ~ ${clockFromDayStart(d.lastEndMin, _h)}',
            style: small,
          ),
      ],
    );
  }

  // ---------- 딴짓 ----------

  Widget _distractions(
    ThemeData theme,
    List<StudySession> sessions,
    DateTime now,
  ) {
    final today = studyDate(now, _h);
    final since = dayStartOf(
      DateTime(today.year, today.month, today.day - 6),
      _h,
    );
    final d = distractionStat(sessions, widget.store.thoughts, since);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('딴짓 앱 ${d.count}회 · ${formatHms(d.seconds)}'),
        if (d.focusSeconds > 0)
          Text(
            '공부 1시간당 ${d.perHour.toStringAsFixed(1)}회',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 4),
        Text('딴생각 메모 ${d.thoughts}개'),
        const SizedBox(height: 4),
        _empty(theme, '딴짓 앱 감지는 Mac 앱에서 ⚙︎ 설정 > 딴짓 앱 감지에 앱을 추가하면 기록돼요.'),
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
    final totals = totalsBySubject(sessions, _range, now, dayStartHour: _h);
    final sum = totals.fold<int>(0, (a, t) => a + t.seconds);
    final max = totals.isEmpty ? 1 : totals.first.seconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        Text(
                          '${formatHms(t.seconds)} · ${sum == 0 ? 0 : (t.seconds * 100 / sum).round()}%',
                        ),
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
      count: switch (_trendUnit) {
        TrendUnit.day => 14,
        TrendUnit.week => 8,
        TrendUnit.month => 6,
      },
      dayStartHour: _h,
    );
    final maxTotal = periods.fold<int>(0, (m, p) => p.total > m ? p.total : m);
    final subjectIds = {for (final p in periods) ...p.secondsBySubject.keys}
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TrendUnit>(
          segments: const [
            ButtonSegment(value: TrendUnit.day, label: Text('일별 (14일)')),
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

/// 하루 24시간을 가로 막대로, 공부한 구간을 과목 색으로 칠합니다.
class _TimelineBar extends StatelessWidget {
  final AppStore store;
  final List<TimelineSegment> segments;
  final int dayStartHour;
  final double height;
  const _TimelineBar({
    required this.store,
    required this.segments,
    required this.dayStartHour,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Container(
          height: height,
          color: bg,
          child: Stack(
            children: [
              for (var i = 1; i < 4; i++)
                Positioned(
                  left: w * i / 4,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 1, color: Colors.black12),
                ),
              for (final s in segments)
                Positioned(
                  left: w * s.startMin / 1440,
                  width: (w * (s.endMin - s.startMin) / 1440).clamp(1.5, w),
                  top: 0,
                  bottom: 0,
                  child: Tooltip(
                    message:
                        '${store.subject(s.subjectId)?.name ?? '(삭제된 과목)'} '
                        '${clockFromDayStart(s.startMin, dayStartHour)}~${clockFromDayStart(s.endMin, dayStartHour)}',
                    child: Container(
                      color:
                          store.subject(s.subjectId)?.colorValue ?? Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
