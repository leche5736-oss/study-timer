import 'models.dart';

/// 타이머 상태 전환 규칙. 모두 순수 함수라 테스트하기 쉽습니다.
class TimerLogic {
  static TimerState startFocus(
    TimerState s, {
    required String subjectId,
    required int presetIndex,
    required String sessionId,
    required DateTime now,
  }) {
    return TimerState(
      phase: Phase.focus,
      subjectId: subjectId,
      presetIndex: presetIndex,
      blocksDone: s.blocksDone,
      sessionId: sessionId,
      sessionStartedAt: now,
      durationSec: presets[presetIndex].focusMin * 60,
      runningSince: now,
      updatedAt: now,
    );
  }

  static TimerState pause(TimerState s, DateTime now) {
    if (!s.isRunning) return s;
    return _copy(s, now, accumulatedSec: s.elapsedSec(now), clearRunning: true);
  }

  static TimerState resume(TimerState s, DateTime now) {
    if (s.isRunning || s.phase == Phase.idle || s.phase == Phase.recall) {
      return s;
    }
    return _copy(s, now, runningSince: now);
  }

  /// 집중을 마치고 회상 메모 단계로. 일찍 끝내도 실제 집중한 시간만 기록됩니다.
  static TimerState finishFocus(TimerState s, DateTime now) {
    if (s.phase != Phase.focus) return s;
    final focused = s.elapsedSec(now).clamp(0, s.durationSec);
    return TimerState(
      phase: Phase.recall,
      subjectId: s.subjectId,
      presetIndex: s.presetIndex,
      blocksDone: s.blocksDone,
      sessionId: s.sessionId,
      sessionStartedAt: s.sessionStartedAt,
      completedFocusSec: focused,
      updatedAt: now,
    );
  }

  /// 회상 메모를 저장하고 조용한 휴식을 시작합니다.
  static (StudySession, TimerState) submitRecall(
    TimerState s, {
    required DateTime now,
    int? focusRating,
    String recallNote = '',
    String question = '',
  }) {
    assert(s.phase == Phase.recall);
    final preset = presets[s.presetIndex];
    final blocks = s.blocksDone + 1;
    final longRest = blocks % blocksPerLongRest == 0;
    final session = StudySession(
      id: s.sessionId!,
      subjectId: s.subjectId!,
      startedAt: s.sessionStartedAt!,
      endedAt: now,
      plannedMinutes: preset.focusMin,
      focusSeconds: s.completedFocusSec ?? 0,
      focusRating: focusRating,
      recallNote: recallNote,
      question: question,
      updatedAt: now,
    );
    final next = TimerState(
      phase: Phase.rest,
      subjectId: s.subjectId,
      presetIndex: s.presetIndex,
      blocksDone: blocks,
      durationSec: (longRest ? preset.longRestMin : preset.restMin) * 60,
      runningSince: now,
      longRest: longRest,
      updatedAt: now,
    );
    return (session, next);
  }

  /// 휴식을 끝내거나 기록 없이 취소하면 대기 상태로 (과목과 프리셋은 유지).
  static TimerState toIdle(TimerState s, DateTime now) => TimerState(
    subjectId: s.subjectId,
    presetIndex: s.presetIndex,
    blocksDone: s.blocksDone,
    updatedAt: now,
  );

  /// 시간이 다 된 단계를 다음 단계로 넘깁니다. 변화가 없으면 같은 객체를 돌려줍니다.
  static TimerState tick(TimerState s, DateTime now) {
    if (!s.isRunning || s.remainingSec(now) > 0) return s;
    final at = s.endsAt()!;
    switch (s.phase) {
      case Phase.focus:
        return finishFocus(s, at);
      case Phase.rest:
        return toIdle(s, at);
      case Phase.idle:
      case Phase.recall:
        return s;
    }
  }

  static TimerState _copy(
    TimerState s,
    DateTime now, {
    int? accumulatedSec,
    DateTime? runningSince,
    bool clearRunning = false,
  }) => TimerState(
    phase: s.phase,
    subjectId: s.subjectId,
    presetIndex: s.presetIndex,
    blocksDone: s.blocksDone,
    sessionId: s.sessionId,
    sessionStartedAt: s.sessionStartedAt,
    durationSec: s.durationSec,
    accumulatedSec: accumulatedSec ?? s.accumulatedSec,
    runningSince: clearRunning ? null : (runningSince ?? s.runningSince),
    completedFocusSec: s.completedFocusSec,
    longRest: s.longRest,
    updatedAt: now,
  );
}
