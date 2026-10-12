import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/stats.dart';

StudySession ses(String id, String subject, DateTime start, int min) =>
    StudySession(
      id: id,
      subjectId: subject,
      startedAt: start,
      endedAt: start.add(Duration(minutes: min)),
      plannedMinutes: 50,
      focusSeconds: min * 60,
      updatedAt: start,
    );

void main() {
  test('주간 리포트: 지난주 같은 기간과 비교하고 며칠째 안 한 과목을 찾는다', () {
    final now = DateTime(2026, 10, 14, 21); // 수요일 밤
    final sessions = [
      ses('1', '형법', DateTime(2026, 10, 12, 20), 120), // 이번 주 월
      ses('2', '상법', DateTime(2026, 10, 14, 19), 60), // 이번 주 수
      ses('3', '형법', DateTime(2026, 10, 6, 20), 90), // 지난주 화 (비교 기간 안)
      ses('4', '형법', DateTime(2026, 10, 9, 20), 300), // 지난주 금 (비교 기간 밖)
      ses('5', '민법', DateTime(2026, 10, 8, 20), 50), // 6일 전
    ];
    final r = weeklyReport(sessions, ['형법', '상법', '민법', '헌법'], now);
    expect(r.thisSec, 180 * 60);
    expect(r.lastSec, 90 * 60);
    expect(r.studyDays, 2);
    expect(r.daysElapsed, 3);
    expect(r.subjects.first.subjectId, '형법');
    expect(r.gaps.map((g) => (g.subjectId, g.days)), [('민법', 6)]);
  });
}
