import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';

void main() {
  late DateTime clock;
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 12, 20); // 로컬 저녁 8시
    store = AppStore(await SharedPreferences.getInstance(), clock: () => clock);
  });

  void fullBlock(String id) {
    store.startFocus(id, 0);
    clock = clock.add(const Duration(minutes: 25));
    store.tick();
    store.submitRecall();
    store.skipRest();
  }

  test('블록 완료 수는 오늘 것만 보이고, 다음 날 0부터 센다', () {
    final s = store.addSubject('형법');
    fullBlock(s.id);
    fullBlock(s.id);
    expect(store.blocksToday, 2);
    clock = DateTime(2026, 10, 13, 9); // 다음 날 아침
    expect(store.blocksToday, 0);
    fullBlock(s.id);
    expect(store.blocksToday, 1);
  });

  test('블록을 다 채우지 못하면 휴식 없이 끝난다', () {
    final s = store.addSubject('상법');
    store.startFocus(s.id, 0);
    clock = clock.add(const Duration(minutes: 10));
    store.finishFocus();
    store.submitRecall();
    expect(store.timer.phase, Phase.idle);
    expect(store.sessions.single.focusSeconds, 600);
  });

  test('스톱워치는 그대로 휴식이 온다', () {
    final s = store.addSubject('민법');
    store.startFocus(s.id, 0, stopwatch: true);
    clock = clock.add(const Duration(minutes: 30));
    store.finishFocus();
    store.submitRecall();
    expect(store.timer.phase, Phase.rest);
  });
}
