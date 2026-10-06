import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/stats.dart';

StudySession _s(DateTime startLocal, int sec, {int? rating, String? rest}) =>
    StudySession(
      id: startLocal.toIso8601String(),
      subjectId: 'a',
      startedAt: startLocal.toUtc(),
      endedAt: startLocal.add(Duration(seconds: sec)).toUtc(),
      plannedMinutes: 0,
      focusSeconds: sec,
      focusRating: rating,
      restType: rest,
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('분석을 열 기준', () {
    test('딴짓 분석은 최근 7일 중 3일 공부하면 열린다', () {
      final now = DateTime(2026, 10, 6, 12);
      final two = [
        _s(DateTime(2026, 10, 5, 20), 600),
        _s(DateTime(2026, 10, 6, 9), 600),
        _s(DateTime(2026, 9, 20, 9), 600), // 7일 밖
      ];
      final r = distractionReadiness(two, now);
      expect(r.have, 2);
      expect(r.ready, isFalse);
      final three = [...two, _s(DateTime(2026, 10, 1, 9), 600)];
      expect(distractionReadiness(three, now).ready, isTrue);
    });

    test('집중 길이 분석은 집중도를 남긴 5분 넘는 블록 10개', () {
      final base = DateTime(2026, 10, 1, 9);
      final list = [
        for (var i = 0; i < 9; i++)
          _s(base.add(Duration(hours: i)), 1500, rating: 4),
        _s(base.add(const Duration(days: 1)), 120, rating: 5), // 너무 짧음
        _s(base.add(const Duration(days: 2)), 1500), // 집중도 없음
      ];
      expect(lengthReadiness(list).have, 9);
      expect(lengthReadiness(list).progress, closeTo(0.9, 1e-9));
      list.add(_s(base.add(const Duration(days: 3)), 1500, rating: 3));
      expect(lengthReadiness(list).ready, isTrue);
    });

    test('휴식 비교는 휴식 뒤 이어서 공부한 블록 6번', () {
      final base = DateTime(2026, 10, 1, 9);
      final list = [
        for (var i = 0; i < 7; i++)
          _s(
            base.add(Duration(minutes: 40 * i)),
            1500,
            rating: 3,
            rest: 'walk',
          ),
      ];
      expect(restReadiness(list).have, 6);
      expect(restReadiness(list).ready, isTrue);
    });
  });

  test('과목 순서를 바꾸면 그 순서로 보이고 다시 열어도 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final a = store.addSubject('형법');
    final b = store.addSubject('상법');
    final c = store.addSubject('가족법');
    expect(store.subjects.map((s) => s.name), ['형법', '상법', '가족법']);
    store.reorderSubjects([c.id, a.id, b.id]);
    expect(store.subjects.map((s) => s.name), ['가족법', '형법', '상법']);
    await Future<void>.delayed(Duration.zero);
    expect(AppStore(prefs).subjects.map((s) => s.name), ['가족법', '형법', '상법']);
  });

  test('예전 진한 과목 색은 파스텔로 바뀐다', () async {
    SharedPreferences.setMockInitialValues({
      'subjects':
          '[{"id":"x","name":"형법","color":${0xFF4E79A7},"deleted":false,'
          '"updated_at":"2026-10-01T00:00:00.000Z"}]',
    });
    final store = AppStore(await SharedPreferences.getInstance());
    expect(store.subjects.single.color, AppStore.palette[0]);
  });
}
