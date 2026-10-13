import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'space_key.dart';
import 'subject_picker.dart';

/// 타이머 첫 화면. 오늘 목표 고리 안에 시간만 보입니다.
/// 고리를 누르면 길이를, 고리 밖을 누르면 과목을 골라 시작합니다.
class IdleView extends StatefulWidget {
  final AppStore store;
  final VoidCallback onGoToSubjects;
  const IdleView({
    super.key,
    required this.store,
    required this.onGoToSubjects,
  });

  @override
  State<IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<IdleView> with SpaceKeyShortcut {
  /// 스페이스 키 = 시작
  @override
  void onSpace() {
    if (store.timer.phase == Phase.idle && store.subjects.isNotEmpty) _start();
  }

  late int _preset = widget.store.timer.presetIndex;
  late bool _stopwatch = widget.store.timer.stopwatch;

  AppStore get store => widget.store;

  Preset get _length => store.settings.presetAt(_preset);
  bool get _timerMode => !_stopwatch && _preset == timerPresetIndex;

  /// 시작을 누르면 과목을 고르고 바로 시작합니다. 과목이 하나면 바로 시작.
  /// [subjectId]가 있으면(오늘 계획 줄을 누름) 그 과목으로 바로 시작.
  Future<void> _start([String? subjectId]) async {
    Notifications.instance.requestWebPermission();
    final subjects = store.subjects;
    final id =
        subjectId ??
        (subjects.length == 1
            ? subjects.single.id
            : await pickSubject(
                context,
                subjects,
                markId: store.timer.subjectId,
              ));
    if (id == null || !mounted) return;
    store.startFocus(id, _preset, stopwatch: _stopwatch);
  }

  /// 오늘 계획 (COSMOS 등이 써 넣은 것). 줄을 누르면 그 과목으로 바로 시작.
  Widget _planList(DailyPlan plan) {
    final done = {
      for (final t in totalsBySubject(
        store.allSessions,
        StatsRange.day,
        DateTime.now(),
        dayStartHour: store.settings.dayStartHour,
      ))
        t.subjectId: t.seconds,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plan.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                plan.note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
          for (final item in plan.items) _planRow(item, done),
        ],
      ),
    );
  }

  Widget _planRow(PlanItem item, Map<String, int> done) {
    final subject = store.subjectNamed(item.subject);
    final studied = subject == null ? 0 : (done[subject.id] ?? 0);
    final finished = item.minutes > 0 && studied >= item.minutes * 60;
    final title = [
      item.subject,
      if (item.task.isNotEmpty && item.task != item.subject) item.task,
    ].join(' · ');
    final detail = [
      if (item.book.isNotEmpty) item.book,
      if (item.target.isNotEmpty) item.target,
    ].join(' ');
    return InkWell(
      key: ValueKey('plan-${item.subject}-${item.task}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _start(subject?.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 4,
              backgroundColor: subject?.colorValue ?? AppColors.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: finished ? AppColors.faint : AppColors.ink,
                      decoration: finished ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (item.minutes > 0)
              Text(
                '${formatHm(studied)} / ${formatHm(item.minutes * 60)}',
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (store.subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '공부할 과목을 먼저 추가하세요',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onGoToSubjects,
              child: const Text('과목 추가'),
            ),
          ],
        ),
      );
    }

    final today = todaySeconds(
      store.allSessions,
      DateTime.now(),
      dayStartHour: store.settings.dayStartHour,
    );
    final goal = store.goalMinutes * 60;
    final plan = store.todayPlan;
    final blocks = store.blocksToday;
    const grey = TextStyle(color: AppColors.grey, fontSize: 15);
    final size = MediaQuery.sizeOf(context);
    final ring = (size.shortestSide * 0.72).clamp(180.0, 320.0);

    // 고리 = 오늘 목표까지 얼마나 왔는지. 고리 안을 누르면 길이를,
    // 고리 밖 아무 데나 누르면 과목을 고르고 바로 시작합니다.
    return GestureDetector(
      key: const Key('idle-start'),
      behavior: HitTestBehavior.opaque,
      onTap: _start,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickLength,
                onLongPress: _pickLength,
                child: SizedBox.square(
                  dimension: ring,
                  child: CustomPaint(
                    painter: _GoalRing(
                      progress: goal > 0 ? today / goal : 0,
                      color: AppColors.accent,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(ring * 0.14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _stopwatch
                                  ? '00:00'
                                  : formatClock(_length.focusMin * 60),
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 64,
                                fontWeight: FontWeight.w200,
                                letterSpacing: -1.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Text(
                            [
                              _stopwatch
                                  ? '스톱워치'
                                  : _timerMode
                                  ? '타이머'
                                  : '휴식 ${_length.restMin}분',
                              if (blocks > 0) '$blocks블록 완료',
                            ].join(' · '),
                            textAlign: TextAlign.center,
                            style: grey.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                goal > 0
                    ? '오늘 ${formatHms(today)} / ${formatHm(goal)}'
                    : '오늘 ${formatHms(today)}',
                style: grey.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (plan != null) ...[
                const SizedBox(height: 16),
                _planList(plan),
              ],
              // 처음 몇 번만 쓰는 법을 알려 줍니다.
              if (store.allSessions.length < 3) ...[
                const SizedBox(height: 6),
                const Text(
                  '고리 밖을 누르면 시작 · 고리를 누르면 길이 바꾸기',
                  style: TextStyle(color: AppColors.faint, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 길이와 타이머/스톱워치 고르기.
  Future<void> _pickLength() async {
    final settings = store.settings;
    final recommend = recommendLength(store.allSessions);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i <= customPresetIndex; i++)
              ListTile(
                title: Text(
                  '${settings.presetAt(i).focusMin}분 집중 · '
                  '${settings.presetAt(i).restMin}분 휴식',
                ),
                subtitle: i == customPresetIndex
                    ? const Text('길이는 설정에서 바꿔요')
                    : null,
                trailing: !_stopwatch && _preset == i
                    ? Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  setState(() {
                    _preset = i;
                    _stopwatch = false;
                  });
                  Navigator.pop(c);
                },
              ),
            ListTile(
              title: const Text('타이머'),
              subtitle: Text(
                '${_hm(settings.timerMin)} · 휴식 없이 한 번에 (눌러서 길이 바꾸기)',
              ),
              trailing: _timerMode
                  ? Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () {
                Navigator.pop(c);
                _pickTimerLength();
              },
            ),
            ListTile(
              title: const Text('스톱워치'),
              subtitle: const Text('시간 제한 없이, 집중한 시간의 1/5만큼 휴식'),
              trailing: _stopwatch
                  ? Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () {
                setState(() => _stopwatch = true);
                Navigator.pop(c);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                [
                  '$blocksPerLongRest블록마다 긴 휴식',
                  if (recommend != null)
                    '집중도가 가장 높았던 길이: ${recommend.bucket.label}',
                ].join('\n'),
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hm(int min) => [
    if (min >= 60) '${min ~/ 60}시간',
    if (min % 60 > 0 || min < 60) '${min % 60}분',
  ].join(' ');

  /// 타이머 길이 고르기 (시간·분 돌림판).
  Future<void> _pickTimerLength() async {
    var picked = Duration(minutes: store.settings.timerMin);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 216,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: picked,
                onTimerDurationChanged: (d) => picked = d,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                key: const Key('timer-length-ok'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('이 길이로'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final min = picked.inMinutes.clamp(1, 12 * 60);
    store.updateSettings(store.settings.copyWith(timerMin: min));
    setState(() {
      _preset = timerPresetIndex;
      _stopwatch = false;
    });
  }
}

/// 오늘 목표 고리. 옅은 바탕 고리 위에 지금까지 한 만큼 색이 찹니다.
class _GoalRing extends CustomPainter {
  final double progress;
  final Color color;
  const _GoalRing({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = AppColors.line);
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * p, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_GoalRing old) =>
      old.progress != progress || old.color != color;
}
