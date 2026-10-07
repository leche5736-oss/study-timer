import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/stats.dart';

TimerState _focus({bool running = true, bool stopwatch = false}) => TimerState(
  phase: Phase.focus,
  durationSec: 1500,
  accumulatedSec: running ? 0 : 60,
  runningSince: running ? DateTime.utc(2026, 10, 5, 9) : null,
  stopwatch: stopwatch,
  updatedAt: DateTime.utc(2026, 10, 5, 9),
);

List<String> _ids(List<Map<String, Object>> items) => [
  for (final i in items)
    if (i['separator'] != true) i['id'] as String,
];

void main() {
  final now = DateTime.utc(2026, 10, 5, 9);
  final subjects = [
    Subject(id: 'a', name: '형법', color: 0, updatedAt: now),
    Subject(id: 'b', name: '상법', color: 0, updatedAt: now),
  ];

  test('공부하지 않을 때는 오늘 공부 시간을 보여준다', () {
    expect(
      menuBarText(TimerState.initial(), now, todaySec: 3 * 3600 + 25 * 60),
      '오늘 3:25',
    );
    expect(menuBarText(_focus(), now), '집중 25:00');
    expect(menuBarText(_focus(running: false), now), '일시정지 24:00');
  });

  test('대기 중에는 과목마다 시작 항목이 있다', () {
    final items = menuBarItems(
      TimerState.initial(),
      subjects,
      todaySec: 600,
      goalSec: 10800,
    );
    expect(_ids(items), ['info', 'start:a', 'start:b', 'open']);
    expect(items.first['title'], '오늘 0:10:00 / 목표 3:00');
    expect(items.first['enabled'], isFalse);
    expect(items[2]['title'], '▶ 형법 집중 시작');
  });

  test('과목이 없으면 앱을 열라고 안내한다', () {
    expect(_ids(menuBarItems(TimerState.initial(), [])), [
      'info',
      'open',
      'open',
    ]);
  });

  test('집중 중에는 일시정지와 끝내기, 휴식 중에는 건너뛰기', () {
    expect(_ids(menuBarItems(_focus(), subjects)), [
      'info',
      'pause',
      'finish',
      'open',
    ]);
    expect(_ids(menuBarItems(_focus(running: false), subjects)), [
      'info',
      'resume',
      'finish',
      'open',
    ]);
    final rest = TimerState(
      phase: Phase.rest,
      durationSec: 300,
      runningSince: now,
      updatedAt: now,
    );
    expect(_ids(menuBarItems(rest, subjects)), ['info', 'skipRest', 'open']);
  });

  test('스톱워치는 끝내기 이름이 다르다', () {
    final items = menuBarItems(_focus(stopwatch: true), subjects);
    expect(items[3]['title'], '끝내기');
  });

  test('정리 노트 단계', () {
    final recall = TimerState(phase: Phase.recall, updatedAt: now);
    expect(menuBarText(recall, now), '정리 노트');
    expect(_ids(menuBarItems(recall, subjects)), ['info', 'open', 'open']);
  });
}
