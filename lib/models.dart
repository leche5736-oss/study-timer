import 'package:flutter/material.dart';

DateTime? _parse(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

class Subject {
  final String id;
  final String name;
  final int color;
  final bool deleted;
  final DateTime updatedAt;

  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.deleted = false,
    required this.updatedAt,
  });

  Color get colorValue => Color(color);

  Subject copyWith({String? name, int? color, bool? deleted}) => Subject(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    deleted: deleted ?? this.deleted,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'deleted': deleted,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: j['id'] as String,
    name: j['name'] as String,
    color: (j['color'] as num).toInt(),
    deleted: j['deleted'] as bool? ?? false,
    updatedAt: _parse(j['updated_at'])!,
  );
}

/// 끝난 집중 블록 1개의 기록.
class StudySession {
  final String id;
  final String subjectId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedMinutes;
  final int focusSeconds;
  final int? focusRating; // 1~5
  final String recallNote; // 방금 배운 것 3줄
  final String question; // 예전 버전에서 쓰던 "스스로 낸 문제" (지금은 입력 안 받음)
  final String? restType; // 이 블록 뒤 휴식 중 한 일 (RestType.name)
  final bool deleted;
  final DateTime updatedAt;

  const StudySession({
    required this.id,
    required this.subjectId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedMinutes,
    required this.focusSeconds,
    this.focusRating,
    this.recallNote = '',
    this.question = '',
    this.restType,
    this.deleted = false,
    required this.updatedAt,
  });

  StudySession copyWith({bool? deleted, String? restType}) => StudySession(
    id: id,
    subjectId: subjectId,
    startedAt: startedAt,
    endedAt: endedAt,
    plannedMinutes: plannedMinutes,
    focusSeconds: focusSeconds,
    focusRating: focusRating,
    recallNote: recallNote,
    question: question,
    restType: restType ?? this.restType,
    deleted: deleted ?? this.deleted,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject_id': subjectId,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt.toIso8601String(),
    'planned_minutes': plannedMinutes,
    'focus_seconds': focusSeconds,
    'focus_rating': focusRating,
    'recall_note': recallNote,
    'question': question,
    'rest_type': restType,
    'deleted': deleted,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
    id: j['id'] as String,
    subjectId: j['subject_id'] as String,
    startedAt: _parse(j['started_at'])!,
    endedAt: _parse(j['ended_at'])!,
    plannedMinutes: (j['planned_minutes'] as num).toInt(),
    focusSeconds: (j['focus_seconds'] as num).toInt(),
    focusRating: (j['focus_rating'] as num?)?.toInt(),
    recallNote: j['recall_note'] as String? ?? '',
    question: j['question'] as String? ?? '',
    restType: j['rest_type'] as String?,
    deleted: j['deleted'] as bool? ?? false,
    updatedAt: _parse(j['updated_at'])!,
  );
}

class Preset {
  final String label;
  final int focusMin;
  final int restMin;
  final int longRestMin;
  const Preset(this.label, this.focusMin, this.restMin, this.longRestMin);
}

const presets = [
  Preset('25/5 입문', 25, 5, 15),
  Preset('50/10 숙련', 50, 10, 30),
  Preset('90/20 깊은 몰입', 90, 20, 30),
];

/// 설정 화면에서 정한 길이를 쓰는 프리셋 번호.
const customPresetIndex = 3;

/// 스톱워치 모드의 휴식 길이: 집중한 시간의 1/5, 5~30분.
int stopwatchRestMin(int focusedSec) =>
    (focusedSec / 60 / 5).round().clamp(5, 30);

/// 휴식 중 한 일. 다음 블록 집중도와 비교하는 데 씁니다.
enum RestType {
  quiet('조용히 쉼'),
  phone('폰/영상'),
  walk('걷기/스트레칭'),
  other('기타');

  final String label;
  const RestType(this.label);

  static RestType? byName(String? name) =>
      RestType.values.where((t) => t.name == name).firstOrNull;
}

/// 이 기기에만 저장하는 설정.
class Settings {
  final int dailyGoalMin; // 0이면 목표 없음
  final int customFocusMin;
  final int customRestMin;
  final int customLongRestMin;
  final bool sound;
  final bool bringToFront; // Mac: 시간이 다 되면 앱 창을 앞으로

  const Settings({
    this.dailyGoalMin = 180,
    this.customFocusMin = 40,
    this.customRestMin = 8,
    this.customLongRestMin = 20,
    this.sound = true,
    this.bringToFront = true,
  });

  Preset get customPreset => Preset(
    '직접 설정 $customFocusMin/$customRestMin',
    customFocusMin,
    customRestMin,
    customLongRestMin,
  );

  Preset presetAt(int index) =>
      index == customPresetIndex ? customPreset : presets[index];

  Settings copyWith({
    int? dailyGoalMin,
    int? customFocusMin,
    int? customRestMin,
    int? customLongRestMin,
    bool? sound,
    bool? bringToFront,
  }) => Settings(
    dailyGoalMin: dailyGoalMin ?? this.dailyGoalMin,
    customFocusMin: customFocusMin ?? this.customFocusMin,
    customRestMin: customRestMin ?? this.customRestMin,
    customLongRestMin: customLongRestMin ?? this.customLongRestMin,
    sound: sound ?? this.sound,
    bringToFront: bringToFront ?? this.bringToFront,
  );

  Map<String, dynamic> toJson() => {
    'daily_goal_min': dailyGoalMin,
    'custom_focus_min': customFocusMin,
    'custom_rest_min': customRestMin,
    'custom_long_rest_min': customLongRestMin,
    'sound': sound,
    'bring_to_front': bringToFront,
  };

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    return Settings(
      dailyGoalMin: (j['daily_goal_min'] as num?)?.toInt() ?? d.dailyGoalMin,
      customFocusMin:
          (j['custom_focus_min'] as num?)?.toInt() ?? d.customFocusMin,
      customRestMin: (j['custom_rest_min'] as num?)?.toInt() ?? d.customRestMin,
      customLongRestMin:
          (j['custom_long_rest_min'] as num?)?.toInt() ?? d.customLongRestMin,
      sound: j['sound'] as bool? ?? d.sound,
      bringToFront: j['bring_to_front'] as bool? ?? d.bringToFront,
    );
  }
}

/// 4블록마다 긴 휴식.
const blocksPerLongRest = 4;

enum Phase { idle, focus, recall, rest }

/// 타이머 상태. 매초 숫자를 세는 대신 "언제부터 몇 초 동안"을 저장하므로
/// 앱을 껐다 켜거나 다른 기기에서 받아도 남은 시간이 정확합니다.
class TimerState {
  final Phase phase;
  final String? subjectId;
  final int presetIndex;
  final int blocksDone; // 오늘 이어서 끝낸 집중 블록 수
  final String? sessionId; // 진행 중인 집중 블록의 기록 id
  final DateTime? sessionStartedAt;
  final int durationSec; // 현재 단계의 목표 길이
  final int accumulatedSec; // 일시정지 전까지 흐른 시간
  final DateTime? runningSince; // null 이면 일시정지
  final int? completedFocusSec; // recall 단계에서 실제 집중한 시간
  final bool longRest;
  final bool stopwatch; // true면 시간 제한 없이 위로 셈
  final int focusMin; // 이번 블록 목표 집중 시간 (스톱워치면 0)
  final int restMin;
  final int longRestMin;
  final String? lastSessionId; // 휴식 단계: 방금 끝낸 블록 (휴식 방식 기록용)
  final DateTime updatedAt;

  const TimerState({
    this.phase = Phase.idle,
    this.subjectId,
    this.presetIndex = 0,
    this.blocksDone = 0,
    this.sessionId,
    this.sessionStartedAt,
    this.durationSec = 0,
    this.accumulatedSec = 0,
    this.runningSince,
    this.completedFocusSec,
    this.longRest = false,
    this.stopwatch = false,
    this.focusMin = 25,
    this.restMin = 5,
    this.longRestMin = 15,
    this.lastSessionId,
    required this.updatedAt,
  });

  factory TimerState.initial() => TimerState(
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  bool get isRunning => runningSince != null;

  int elapsedSec(DateTime now) {
    final running = runningSince == null
        ? 0
        : now.difference(runningSince!).inSeconds;
    return accumulatedSec + (running < 0 ? 0 : running);
  }

  int remainingSec(DateTime now) => durationSec - elapsedSec(now);

  /// 진행 중일 때 이 단계가 끝나는 시각. 스톱워치 집중은 끝이 없어 null.
  DateTime? endsAt() => stopwatch && phase == Phase.focus
      ? null
      : runningSince?.add(Duration(seconds: durationSec - accumulatedSec));

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'subject_id': subjectId,
    'preset_index': presetIndex,
    'blocks_done': blocksDone,
    'session_id': sessionId,
    'session_started_at': sessionStartedAt?.toIso8601String(),
    'duration_sec': durationSec,
    'accumulated_sec': accumulatedSec,
    'running_since': runningSince?.toIso8601String(),
    'completed_focus_sec': completedFocusSec,
    'long_rest': longRest,
    'stopwatch': stopwatch,
    'focus_min': focusMin,
    'rest_min': restMin,
    'long_rest_min': longRestMin,
    'last_session_id': lastSessionId,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TimerState.fromJson(Map<String, dynamic> j) {
    final presetIndex = (j['preset_index'] as num?)?.toInt() ?? 0;
    // 0.2.0 이전에 저장된 상태에는 길이가 없으므로 프리셋에서 가져옵니다.
    final fallback = presets[presetIndex.clamp(0, presets.length - 1)];
    return TimerState(
      phase: Phase.values.firstWhere(
        (p) => p.name == j['phase'],
        orElse: () => Phase.idle,
      ),
      subjectId: j['subject_id'] as String?,
      presetIndex: presetIndex,
      blocksDone: (j['blocks_done'] as num?)?.toInt() ?? 0,
      sessionId: j['session_id'] as String?,
      sessionStartedAt: _parse(j['session_started_at']),
      durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
      accumulatedSec: (j['accumulated_sec'] as num?)?.toInt() ?? 0,
      runningSince: _parse(j['running_since']),
      completedFocusSec: (j['completed_focus_sec'] as num?)?.toInt(),
      longRest: j['long_rest'] as bool? ?? false,
      stopwatch: j['stopwatch'] as bool? ?? false,
      focusMin: (j['focus_min'] as num?)?.toInt() ?? fallback.focusMin,
      restMin: (j['rest_min'] as num?)?.toInt() ?? fallback.restMin,
      longRestMin:
          (j['long_rest_min'] as num?)?.toInt() ?? fallback.longRestMin,
      lastSessionId: j['last_session_id'] as String?,
      updatedAt: _parse(j['updated_at'])!,
    );
  }
}
