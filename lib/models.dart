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
  final String question; // 스스로 낸 문제 1개
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
    this.deleted = false,
    required this.updatedAt,
  });

  StudySession copyWith({bool? deleted}) => StudySession(
    id: id,
    subjectId: subjectId,
    startedAt: startedAt,
    endedAt: endedAt,
    plannedMinutes: plannedMinutes,
    focusSeconds: focusSeconds,
    focusRating: focusRating,
    recallNote: recallNote,
    question: question,
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

  /// 진행 중일 때 이 단계가 끝나는 시각.
  DateTime? endsAt() =>
      runningSince?.add(Duration(seconds: durationSec - accumulatedSec));

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
    'updated_at': updatedAt.toIso8601String(),
  };

  factory TimerState.fromJson(Map<String, dynamic> j) => TimerState(
    phase: Phase.values.firstWhere(
      (p) => p.name == j['phase'],
      orElse: () => Phase.idle,
    ),
    subjectId: j['subject_id'] as String?,
    presetIndex: (j['preset_index'] as num?)?.toInt() ?? 0,
    blocksDone: (j['blocks_done'] as num?)?.toInt() ?? 0,
    sessionId: j['session_id'] as String?,
    sessionStartedAt: _parse(j['session_started_at']),
    durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
    accumulatedSec: (j['accumulated_sec'] as num?)?.toInt() ?? 0,
    runningSince: _parse(j['running_since']),
    completedFocusSec: (j['completed_focus_sec'] as num?)?.toInt(),
    longRest: j['long_rest'] as bool? ?? false,
    updatedAt: _parse(j['updated_at'])!,
  );
}
