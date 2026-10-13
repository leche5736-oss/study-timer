import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';

void main() {
  late DateTime clock;
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 10, 13, 11);
    store = AppStore(await SharedPreferences.getInstance(), clock: () => clock);
  });

  test('과목별 책 목록: 빈 이름과 중복은 빠지고 동기화 JSON에 실린다', () {
    final s = store.addSubject('민사법');
    store.setSubjectBooks(s.id, [' 민법의 맥 ', '', '민사소송법의 맥', '민법의 맥']);
    final books = store.subject(s.id)!.books;
    expect(books, ['민법의 맥', '민사소송법의 맥']);
    expect(Subject.fromJson(store.subject(s.id)!.toJson()).books, books);
  });

  test('공부를 마칠 때 적은 책과 진도가 기록되고 다음에 "지난번"으로 나온다', () {
    final s = store.addSubject('민사법');
    store.setSubjectBooks(s.id, ['민법의 맥', '민법사례연습']);
    store.startFocus(s.id, 0);
    clock = clock.add(const Duration(minutes: 25));
    store.tick();
    store.submitRecall(book: '민법의 맥', progress: ' 120쪽 ');
    final saved = store.sessions.single;
    expect(saved.book, '민법의 맥');
    expect(saved.progress, '120쪽');
    expect(StudySession.fromJson(saved.toJson()).progress, '120쪽');
    expect(store.lastProgress(s.id)?.progress, '120쪽');
    expect(store.lastProgress(s.id, book: '민법사례연습'), isNull);
  });
}
