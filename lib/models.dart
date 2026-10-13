import 'package:flutter/material.dart';

DateTime? _parse(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

class Subject {
  final String id;
  final String name;
  final int color;
  final int order; // 과목 목록 순서 (작을수록 위)
  final List<String> books; // 이 과목에서 쓰는 책 이름
  final bool deleted;
  final DateTime updatedAt;

  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.order = 0,
    this.books = const [],
    this.deleted = false,
    required this.updatedAt,
  });

  Color get colorValue => Color(color);

  Subject copyWith({
    String? name,
    int? color,
    int? order,
    List<String>? books,
    bool? deleted,
  }) => Subject(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    order: order ?? this.order,
    books: books ?? this.books,
    deleted: deleted ?? this.deleted,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'sort_order': order,
    'books': books,
    'deleted': deleted,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: j['id'] as String,
    name: j['name'] as String,
    color: (j['color'] as num).toInt(),
    order: (j['sort_order'] as num?)?.toInt() ?? 0,
    books: (j['books'] as List?)?.cast<String>() ?? const [],
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
  final int distractions; // 딴짓 앱으로 넘어간 횟수
  final int distractedSeconds; // 딴짓 앱에 머문 시간
  final String book; // 이 블록에서 본 책 ('' = 안 적음)
  final String progress; // 어디까지 봤는지 (예: "120쪽", "3장 2절")
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
    this.distractions = 0,
    this.distractedSeconds = 0,
    this.book = '',
    this.progress = '',
    this.deleted = false,
    required this.updatedAt,
  });

  StudySession copyWith({
    String? subjectId,
    bool? deleted,
    String? restType,
    String? book,
    String? progress,
  }) => StudySession(
    id: id,
    subjectId: subjectId ?? this.subjectId,
    startedAt: startedAt,
    endedAt: endedAt,
    plannedMinutes: plannedMinutes,
    focusSeconds: focusSeconds,
    focusRating: focusRating,
    recallNote: recallNote,
    question: question,
    restType: restType ?? this.restType,
    distractions: distractions,
    distractedSeconds: distractedSeconds,
    book: book ?? this.book,
    progress: progress ?? this.progress,
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
    'distractions': distractions,
    'distracted_seconds': distractedSeconds,
    'book': book,
    'progress': progress,
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
    distractions: (j['distractions'] as num?)?.toInt() ?? 0,
    distractedSeconds: (j['distracted_seconds'] as num?)?.toInt() ?? 0,
    book: j['book'] as String? ?? '',
    progress: j['progress'] as String? ?? '',
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

/// 긴 시간을 한 번에 재는 타이머 (예: 3시간 30분). 휴식 단계가 없습니다.
const timerPresetIndex = 4;

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
  final int dayStartHour; // 하루가 바뀌는 시각 (새벽 공부를 전날로 묶기)
  final bool watchApps; // Mac: 집중 중 딴짓 앱 감지
  final List<String> blockedApps; // 딴짓 앱 이름 목록
  final bool menuBar; // Mac: 메뉴 막대에 남은 시간 표시
  final String colorTheme; // 앱 색 테마 (theme.dart의 colorThemes id)
  final int timerMin; // 타이머 모드 길이 (분)
  /// 기기끼리 맞추는 설정(목표·길이·하루 시작 시각)을 마지막으로 바꾼 시각.
  final DateTime? sharedUpdatedAt;

  const Settings({
    this.dailyGoalMin = 180,
    this.customFocusMin = 40,
    this.customRestMin = 8,
    this.customLongRestMin = 20,
    this.sound = true,
    this.bringToFront = true,
    this.dayStartHour = 5,
    this.watchApps = true,
    this.blockedApps = const [],
    this.menuBar = true,
    this.colorTheme = 'blue',
    this.timerMin = 210,
    this.sharedUpdatedAt,
  });

  Preset get customPreset => Preset(
    '직접 설정 $customFocusMin/$customRestMin',
    customFocusMin,
    customRestMin,
    customLongRestMin,
  );

  Preset presetAt(int index) => switch (index) {
    customPresetIndex => customPreset,
    timerPresetIndex => Preset('타이머', timerMin, 0, 0),
    _ => presets[index.clamp(0, presets.length - 1)],
  };

  Settings copyWith({
    int? dailyGoalMin,
    int? customFocusMin,
    int? customRestMin,
    int? customLongRestMin,
    bool? sound,
    bool? bringToFront,
    int? dayStartHour,
    bool? watchApps,
    List<String>? blockedApps,
    bool? menuBar,
    String? colorTheme,
    int? timerMin,
    DateTime? sharedUpdatedAt,
  }) => Settings(
    dailyGoalMin: dailyGoalMin ?? this.dailyGoalMin,
    customFocusMin: customFocusMin ?? this.customFocusMin,
    customRestMin: customRestMin ?? this.customRestMin,
    customLongRestMin: customLongRestMin ?? this.customLongRestMin,
    sound: sound ?? this.sound,
    bringToFront: bringToFront ?? this.bringToFront,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    watchApps: watchApps ?? this.watchApps,
    blockedApps: blockedApps ?? this.blockedApps,
    menuBar: menuBar ?? this.menuBar,
    colorTheme: colorTheme ?? this.colorTheme,
    timerMin: timerMin ?? this.timerMin,
    sharedUpdatedAt: sharedUpdatedAt ?? this.sharedUpdatedAt,
  );

  /// 기기끼리 맞추는 설정만 (동기화용).
  Map<String, dynamic> sharedJson() => {
    'daily_goal_min': dailyGoalMin,
    'custom_focus_min': customFocusMin,
    'custom_rest_min': customRestMin,
    'custom_long_rest_min': customLongRestMin,
    'day_start_hour': dayStartHour,
    'timer_min': timerMin,
    'shared_updated_at': sharedUpdatedAt?.toIso8601String(),
  };

  /// 다른 기기에서 받은 공유 설정을 덮어씁니다. 이 기기 전용 설정은 그대로.
  Settings withShared(Map<String, dynamic> j) {
    final r = Settings.fromJson({...toJson(), ...j});
    return copyWith(
      dailyGoalMin: r.dailyGoalMin,
      customFocusMin: r.customFocusMin,
      customRestMin: r.customRestMin,
      customLongRestMin: r.customLongRestMin,
      dayStartHour: r.dayStartHour,
      timerMin: r.timerMin,
      sharedUpdatedAt: r.sharedUpdatedAt,
    );
  }

  /// 공유 설정 중 하나라도 다르면 true.
  bool sharedDiffers(Settings o) {
    final a = sharedJson()..remove('shared_updated_at');
    final b = o.sharedJson()..remove('shared_updated_at');
    return a.toString() != b.toString();
  }

  Map<String, dynamic> toJson() => {
    'daily_goal_min': dailyGoalMin,
    'custom_focus_min': customFocusMin,
    'custom_rest_min': customRestMin,
    'custom_long_rest_min': customLongRestMin,
    'sound': sound,
    'bring_to_front': bringToFront,
    'day_start_hour': dayStartHour,
    'watch_apps': watchApps,
    'blocked_apps': blockedApps,
    'menu_bar': menuBar,
    'color_theme': colorTheme,
    'timer_min': timerMin,
    'shared_updated_at': sharedUpdatedAt?.toIso8601String(),
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
      dayStartHour: (j['day_start_hour'] as num?)?.toInt() ?? d.dayStartHour,
      watchApps: j['watch_apps'] as bool? ?? d.watchApps,
      blockedApps:
          (j['blocked_apps'] as List?)?.cast<String>() ?? d.blockedApps,
      menuBar: j['menu_bar'] as bool? ?? d.menuBar,
      colorTheme: j['color_theme'] as String? ?? d.colorTheme,
      timerMin: (j['timer_min'] as num?)?.toInt() ?? d.timerMin,
      sharedUpdatedAt: DateTime.tryParse(
        j['shared_updated_at'] as String? ?? '',
      ),
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
  final int blocksDone; // 정한 시간을 끝까지 채운 집중 블록 수
  final String? blocksDay; // blocksDone을 센 공부 날짜 (yyyy-mm-dd). 날이 바뀌면 0부터
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
  final int distractions; // 이번 블록에서 딴짓 앱으로 넘어간 횟수
  final int distractedSec; // 이번 블록에서 딴짓 앱에 머문 시간 (끝난 것만)
  final DateTime? distractedSince; // 지금 딴짓 앱에 있으면 그 시작 시각
  /// 블록 중간에 과목을 바꿨을 때, 앞 과목으로 이미 기록한 집중 시간.
  /// 지금 과목의 기록은 이 시간을 뺀 나머지입니다.
  final int blockPriorSec;
  final DateTime updatedAt;

  const TimerState({
    this.phase = Phase.idle,
    this.subjectId,
    this.presetIndex = 0,
    this.blocksDone = 0,
    this.blocksDay,
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
    this.distractions = 0,
    this.distractedSec = 0,
    this.distractedSince,
    this.blockPriorSec = 0,
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
    'blocks_day': blocksDay,
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
    'distractions': distractions,
    'distracted_sec': distractedSec,
    'distracted_since': distractedSince?.toIso8601String(),
    'block_prior_sec': blockPriorSec,
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
      blocksDay: j['blocks_day'] as String?,
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
      distractions: (j['distractions'] as num?)?.toInt() ?? 0,
      distractedSec: (j['distracted_sec'] as num?)?.toInt() ?? 0,
      distractedSince: _parse(j['distracted_since']),
      blockPriorSec: (j['block_prior_sec'] as num?)?.toInt() ?? 0,
      updatedAt: _parse(j['updated_at'])!,
    );
  }
}

/// 집중 중 떠오른 딴생각 한 줄. 적어 두고 휴식 때 처리합니다.
/// 이 기기에만 저장합니다.
class ThoughtNote {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool done;

  const ThoughtNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.done = false,
  });

  ThoughtNote copyWith({bool? done}) => ThoughtNote(
    id: id,
    text: text,
    createdAt: createdAt,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'done': done,
  };

  factory ThoughtNote.fromJson(Map<String, dynamic> j) => ThoughtNote(
    id: j['id'] as String,
    text: j['text'] as String,
    createdAt: _parse(j['created_at'])!,
    done: j['done'] as bool? ?? false,
  );
}

/// 진도에 숫자만 적으면 쪽수로 봅니다. "120" → "120쪽".
String normalizeProgress(String text) {
  final t = text.trim();
  return RegExp(r'^\d+$').hasMatch(t) ? '$t쪽' : t;
}

/// 오늘 공부 계획 한 줄. COSMOS(Claude) 같은 바깥 계획 도구가 Supabase의
/// daily_plans 표에 써 넣고, 앱은 읽어서 보여 주기만 합니다.
class PlanItem {
  final String subject; // 과목 이름 (앱의 과목과 이름으로 맞춥니다)
  final String task; // 할 일 (예: 형법 45강)
  final int minutes; // 목표 시간(분), 0이면 시간 목표 없음
  final String book; // 책 (없으면 빈 칸)
  final String target; // 어디까지 (예: p.58)

  const PlanItem({
    required this.subject,
    this.task = '',
    this.minutes = 0,
    this.book = '',
    this.target = '',
  });

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    subject: '${j['subject'] ?? ''}'.trim(),
    task: '${j['task'] ?? ''}'.trim(),
    minutes: (j['minutes'] as num?)?.round() ?? 0,
    book: '${j['book'] ?? ''}'.trim(),
    target: '${j['target'] ?? ''}'.trim(),
  );

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'task': task,
    'minutes': minutes,
    'book': book,
    'target': target,
  };
}

class DailyPlan {
  final String day; // 공부 날짜 YYYY-MM-DD (하루가 바뀌는 시각 기준)
  final List<PlanItem> items;
  final String note; // 한 줄 메모 (예: 오늘의 원씽)

  const DailyPlan({required this.day, this.items = const [], this.note = ''});

  int get totalMinutes => items.fold(0, (sum, i) => sum + i.minutes);

  factory DailyPlan.fromJson(Map<String, dynamic> j) => DailyPlan(
    day: '${j['day']}'.substring(0, 10),
    items: [
      for (final i in (j['items'] as List? ?? const []))
        if (i is Map<String, dynamic>) PlanItem.fromJson(i),
    ].where((i) => i.subject.isNotEmpty || i.task.isNotEmpty).toList(),
    note: '${j['note'] ?? ''}'.trim(),
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'items': [for (final i in items) i.toJson()],
    'note': note,
  };
}
