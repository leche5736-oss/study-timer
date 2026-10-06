import 'models.dart';

/// 타이머 상태 전환 규칙. 모두 순수 함수라 테스트하기 쉽습니다.
class TimerLogic {
  /// 집중을 시작합니다. [stopwatch]면 시간 제한 없이 위로 셉니다.
  static TimerState startFocus(
    TimerState s, {
    required String subjectId,
    required int presetIndex,
    required Preset preset,
    required String sessionId,
    required DateTime now,
    bool stopwatch = false,
  }) {
    return TimerState(
      phase: Phase.focus,
      subjectId: subjectId,
      presetIndex: presetIndex,
      blocksDone: s.blocksDone,
      sessionId: sessionId,
      sessionStartedAt: now,
      durationSec: stopwatch ? 0 : preset.focusMin * 60,
      runningSince: now,
      stopwatch: stopwatch,
      focusMin: stopwatch ? 0 : preset.focusMin,
      restMin: preset.restMin,
      longRestMin: preset.longRestMin,
      updatedAt: now,
    );
  }

  static TimerState pause(TimerState s, DateTime now) {
    if (!s.isRunning) return s;
    return _copy(
      leaveDistraction(s, now),
      now,
      accumulatedSec: s.elapsedSec(now),
      clearRunning: true,
    );
  }

  /// 집중 중에 딴짓 앱으로 넘어갔을 때. 횟수를 세고 머문 시간을 재기 시작합니다.
  static TimerState enterDistraction(TimerState s, DateTime now) {
    if (s.phase != Phase.focus || !s.isRunning || s.distractedSince != null) {
      return s;
    }
    return _copy(
      s,
      now,
      distractions: s.distractions + 1,
      distractedSince: now,
    );
  }

  /// 딴짓 앱에서 벗어났을 때. 머문 시간을 더합니다.
  static TimerState leaveDistraction(TimerState s, DateTime now) {
    final since = s.distractedSince;
    if (since == null) return s;
    final sec = now.difference(since).inSeconds;
    return _copy(
      s,
      now,
      distractedSec: s.distractedSec + (sec < 0 ? 0 : sec),
      clearDistractedSince: true,
    );
  }

  static TimerState resume(TimerState s, DateTime now) {
    if (s.isRunning || s.phase == Phase.idle || s.phase == Phase.recall) {
      return s;
    }
    return _copy(s, now, runningSince: now);
  }

  /// 집중을 마치고 정리 노트 단계로. 일찍 끝내도 실제 집중한 시간만 기록됩니다.
  static TimerState finishFocus(TimerState s, DateTime now) {
    if (s.phase != Phase.focus) return s;
    s = leaveDistraction(s, now);
    final elapsed = s.elapsedSec(now);
    final focused = s.stopwatch ? elapsed : elapsed.clamp(0, s.durationSec);
    return TimerState(
      phase: Phase.recall,
      subjectId: s.subjectId,
      presetIndex: s.presetIndex,
      blocksDone: s.blocksDone,
      sessionId: s.sessionId,
      sessionStartedAt: s.sessionStartedAt,
      completedFocusSec: focused,
      stopwatch: s.stopwatch,
      focusMin: s.focusMin,
      restMin: s.restMin,
      longRestMin: s.longRestMin,
      distractions: s.distractions,
      distractedSec: s.distractedSec,
      updatedAt: now,
    );
  }

  /// 정리 노트를 저장하고 조용한 휴식을 시작합니다.
  static (StudySession, TimerState) submitRecall(
    TimerState s, {
    required DateTime now,
    int? focusRating,
    String recallNote = '',
  }) {
    assert(s.phase == Phase.recall);
    final focused = s.completedFocusSec ?? 0;
    // 정한 집중 시간을 끝까지 채운 블록만 셉니다 (스톱워치·일찍 끝낸 블록은 제외).
    final full = !s.stopwatch && focused >= s.focusMin * 60;
    final blocks = s.blocksDone + (full ? 1 : 0);
    final longRest = full && blocks % blocksPerLongRest == 0;
    final restMin = s.stopwatch
        ? stopwatchRestMin(focused)
        : (longRest ? s.longRestMin : s.restMin);
    final session = StudySession(
      id: s.sessionId!,
      subjectId: s.subjectId!,
      startedAt: s.sessionStartedAt!,
      endedAt: now,
      plannedMinutes: s.focusMin,
      focusSeconds: focused,
      focusRating: focusRating,
      recallNote: recallNote,
      distractions: s.distractions,
      distractedSeconds: s.distractedSec,
      updatedAt: now,
    );
    final next = TimerState(
      phase: Phase.rest,
      subjectId: s.subjectId,
      presetIndex: s.presetIndex,
      blocksDone: blocks,
      durationSec: restMin * 60,
      runningSince: now,
      longRest: longRest,
      stopwatch: s.stopwatch,
      focusMin: s.focusMin,
      restMin: s.restMin,
      longRestMin: s.longRestMin,
      lastSessionId: session.id,
      updatedAt: now,
    );
    return (session, next);
  }

  /// 휴식을 끝내거나 기록 없이 취소하면 대기 상태로 (과목, 프리셋, 모드는 유지).
  static TimerState toIdle(TimerState s, DateTime now) => TimerState(
    subjectId: s.subjectId,
    presetIndex: s.presetIndex,
    blocksDone: s.blocksDone,
    stopwatch: s.stopwatch,
    focusMin: s.focusMin,
    restMin: s.restMin,
    longRestMin: s.longRestMin,
    updatedAt: now,
  );

  /// 시간이 다 된 단계를 다음 단계로 넘깁니다. 변화가 없으면 같은 객체를 돌려줍니다.
  static TimerState tick(TimerState s, DateTime now) {
    final end = s.endsAt();
    if (end == null || now.isBefore(end)) return s;
    switch (s.phase) {
      case Phase.focus:
        return finishFocus(s, end);
      case Phase.rest:
        return toIdle(s, end);
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
    int? distractions,
    int? distractedSec,
    DateTime? distractedSince,
    bool clearDistractedSince = false,
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
    stopwatch: s.stopwatch,
    focusMin: s.focusMin,
    restMin: s.restMin,
    longRestMin: s.longRestMin,
    lastSessionId: s.lastSessionId,
    distractions: distractions ?? s.distractions,
    distractedSec: distractedSec ?? s.distractedSec,
    distractedSince: clearDistractedSince
        ? null
        : (distractedSince ?? s.distractedSince),
    updatedAt: now,
  );
}
