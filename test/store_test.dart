import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';

void main() {
  late DateTime clock;

  Future<AppStore> make() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore(prefs, clock: () => clock);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 10, 5, 9);
  });

  test('한 블록을 끝내면 기록이 저장되고 다시 열어도 남아 있다', () async {
    final store = await make();
    var localChanges = 0;
    store.onLocalChange = () => localChanges++;
    final math = store.addSubject('수학');
    store.startFocus(math.id, 0);
    clock = clock.add(const Duration(minutes: 26));
    store.tick();
    expect(store.timer.phase, Phase.recall);
    store.submitRecall(rating: 5, note: '미분 정의', question: '도함수란?');
    expect(store.timer.phase, Phase.rest);
    expect(localChanges, greaterThan(0));

    await Future<void>.delayed(Duration.zero);
    final reopened = await make();
    expect(reopened.subjects.single.name, '수학');
    expect(reopened.sessions.single.recallNote, '미분 정의');
    expect(reopened.sessions.single.focusSeconds, 25 * 60);
    expect(reopened.timer.phase, Phase.rest);
  });

  test('서버 데이터는 더 최근 것만 반영된다', () async {
    final store = await make();
    final s = store.addSubject('영어');
    store.mergeRemote(
      subjects: [
        Subject(
          id: s.id,
          name: '옛날 이름',
          color: 0,
          updatedAt: DateTime.utc(2020),
        ),
      ],
    );
    expect(store.subjects.single.name, '영어');
    store.mergeRemote(
      subjects: [
        Subject(
          id: s.id,
          name: '새 이름',
          color: 0,
          updatedAt: DateTime.utc(2030),
        ),
      ],
    );
    expect(store.subjects.single.name, '새 이름');
  });

  test('삭제한 과목은 목록에서 빠진다', () async {
    final store = await make();
    final s = store.addSubject('국어');
    store.deleteSubject(s.id);
    expect(store.subjects, isEmpty);
    expect(store.allSubjects.single.deleted, isTrue);
  });

  test('과목 색을 바꿀 수 있다', () async {
    final store = await make();
    final s = store.addSubject('과학');
    store.setSubjectColor(s.id, AppStore.palette[3]);
    expect(store.subjects.single.color, AppStore.palette[3]);
  });
}
