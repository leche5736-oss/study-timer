import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/posture_recorder.dart';

void main() {
  test('1분 미만이면 고개 각도를 기록하지 않는다', () {
    expect(summarizePosture([for (var i = 0; i < 59; i++) (i, -4.0)]), isNull);
  });

  test('바른 자세가 없으면 처음 2분이 기준이고, 5도 넘게 숙인 초를 센다', () {
    final samples = [
      for (var i = 0; i < 120; i++) (i, -4.0), // 바른 책 읽기
      for (var i = 120; i < 300; i++) (i, -10.0), // 구부정
      for (var i = 300; i < 360; i++) (i, -8.0), // 경계 (기준 -4 - 5 = -9 보다 위)
    ];
    final p = summarizePosture(samples)!;
    expect(p['base'], -4.0);
    expect(p['fixed'], false);
    expect(p['down'], 180);
    expect(p['secs'], 360);
    expect(p['min'], [-4.0, -4.0, -10.0, -10.0, -10.0, -8.0]);
  });

  test('저장한 바른 자세가 있으면 그것을 기준으로 쓴다', () {
    final samples = [for (var i = 0; i < 120; i++) (i, -8.0)];
    final p = summarizePosture(samples, base: 0, alerts: 2)!;
    expect(p['base'], 0.0);
    expect(p['fixed'], true);
    expect(p['down'], 120);
    expect(p['alerts'], 2);
  });

  test('5도 넘게 숙인 채 정한 시간이 지나야 한 번 알린다', () {
    final a = PostureAlarm();
    var rings = <int>[];
    for (var s = 0; s < 200; s++) {
      if (a.feed(s, -6, 0, 180)) rings.add(s);
    }
    expect(rings, [180]); // 계속 숙여도 한 번만

    // 고개를 들었다가 다시 숙이면 다시 세지만, 5분 안에는 알리지 않는다
    final b = PostureAlarm();
    rings = [];
    for (var s = 0; s < 1000; s++) {
      final down = !(s >= 190 && s < 200);
      if (b.feed(s, down ? -6 : 0, 0, 60)) rings.add(s);
    }
    expect(rings, [60, 360]);
  });

  test('잠깐 고개를 들면 처음부터 다시 센다', () {
    final a = PostureAlarm();
    final rings = <int>[];
    for (var s = 0; s < 400; s++) {
      if (a.feed(s, s == 100 ? 0 : -6, 0, 180)) rings.add(s);
    }
    expect(rings, [101 + 180]);
  });

  test('못 읽은 분은 null로 남긴다', () {
    final samples = [
      for (var i = 0; i < 60; i++) (i, -3.0),
      for (var i = 180; i < 240; i++) (i, -3.0),
    ];
    expect(summarizePosture(samples)!['min'], [-3.0, null, null, -3.0]);
  });

  test('기록 JSON에 고개 각도가 오가고, 없으면 칸을 보내지 않는다', () {
    final s = StudySession(
      id: 'a',
      subjectId: 'b',
      startedAt: DateTime.utc(2026, 10, 28),
      endedAt: DateTime.utc(2026, 10, 28, 1),
      plannedMinutes: 50,
      focusSeconds: 3000,
      updatedAt: DateTime.utc(2026, 10, 28, 1),
    );
    expect(s.toJson().containsKey('posture'), isFalse);
    final withP = s.copyWith(posture: {'down': 120});
    expect(StudySession.fromJson(withP.toJson()).posture, {'down': 120});
  });
}
