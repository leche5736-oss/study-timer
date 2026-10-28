import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/posture_recorder.dart';

void main() {
  test('1분 미만이면 고개 각도를 기록하지 않는다', () {
    expect(summarizePosture([for (var i = 0; i < 59; i++) (i, -4.0)]), isNull);
  });

  test('처음 2분이 기준 자세이고, 기준보다 4도 넘게 숙인 초를 센다', () {
    final samples = [
      for (var i = 0; i < 120; i++) (i, -4.0), // 바른 책 읽기
      for (var i = 120; i < 300; i++) (i, -9.0), // 구부정
      for (var i = 300; i < 360; i++) (i, -7.0), // 경계 (기준 -4 - 4 = -8 보다 위)
    ];
    final p = summarizePosture(samples)!;
    expect(p['base'], -4.0);
    expect(p['down'], 180);
    expect(p['secs'], 360);
    expect(p['min'], [-4.0, -4.0, -9.0, -9.0, -9.0, -7.0]);
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
