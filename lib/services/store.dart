import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../timer_logic.dart';

const _uuid = Uuid();

/// 앱의 모든 데이터를 들고 있고 이 기기에 저장합니다.
/// 동기화가 켜져 있으면 [onLocalChange]로 바뀐 사실을 알려 서버에 올리게 합니다.
class AppStore extends ChangeNotifier {
  static const _kSubjects = 'subjects';
  static const _kSessions = 'sessions';
  static const _kTimer = 'timer';
  static const _kSettings = 'settings';
  static const _kThoughts = 'thoughts';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final Map<String, Subject> _subjects = {};
  final Map<String, StudySession> _sessions = {};
  TimerState _timer = TimerState.initial();
  Settings _settings = const Settings();
  final List<ThoughtNote> _thoughts = [];

  /// 사용자가 이 기기에서 무언가 바꿨을 때 호출됩니다.
  void Function()? onLocalChange;

  /// 타이머 단계가 바뀌었을 때 호출됩니다(알림 예약용).
  void Function(TimerState previous, TimerState next)? onTimerChanged;

  Timer? _ticker;

  AppStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _load();
  }

  DateTime get now => _clock();

  SharedPreferences get prefs => _prefs;

  List<Subject> get subjects =>
      _subjects.values.where((s) => !s.deleted).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Subject> get allSubjects => _subjects.values.toList();

  Subject? subject(String? id) => id == null ? null : _subjects[id];

  List<StudySession> get sessions =>
      _sessions.values.where((s) => !s.deleted).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  List<StudySession> get allSessions => _sessions.values.toList();

  TimerState get timer => _timer;

  Settings get settings => _settings;

  StudySession? session(String? id) => id == null ? null : _sessions[id];

  /// 딴생각 메모 (오래된 것부터).
  List<ThoughtNote> get thoughts => List.unmodifiable(_thoughts);
  List<ThoughtNote> get openThoughts =>
      _thoughts.where((t) => !t.done).toList();

  void _load() {
    final subj = _prefs.getString(_kSubjects);
    if (subj != null) {
      for (final j in jsonDecode(subj) as List) {
        final s = Subject.fromJson(j as Map<String, dynamic>);
        _subjects[s.id] = s;
      }
    }
    final sess = _prefs.getString(_kSessions);
    if (sess != null) {
      for (final j in jsonDecode(sess) as List) {
        final s = StudySession.fromJson(j as Map<String, dynamic>);
        _sessions[s.id] = s;
      }
    }
    final st = _prefs.getString(_kSettings);
    if (st != null) {
      _settings = Settings.fromJson(jsonDecode(st) as Map<String, dynamic>);
    }
    final th = _prefs.getString(_kThoughts);
    if (th != null) {
      _thoughts.addAll(
        (jsonDecode(th) as List).map(
          (j) => ThoughtNote.fromJson(j as Map<String, dynamic>),
        ),
      );
    }
    final t = _prefs.getString(_kTimer);
    if (t != null) {
      _timer = TimerState.fromJson(jsonDecode(t) as Map<String, dynamic>);
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _kSubjects,
      jsonEncode(_subjects.values.map((s) => s.toJson()).toList()),
    );
    await _prefs.setString(
      _kSessions,
      jsonEncode(_sessions.values.map((s) => s.toJson()).toList()),
    );
    await _prefs.setString(_kTimer, jsonEncode(_timer.toJson()));
    await _prefs.setString(_kSettings, jsonEncode(_settings.toJson()));
    await _prefs.setString(
      _kThoughts,
      jsonEncode(_thoughts.map((t) => t.toJson()).toList()),
    );
  }

  void _changed({bool local = true}) {
    _save();
    notifyListeners();
    if (local) onLocalChange?.call();
  }

  // ---------- 과목 ----------

  static const palette = [
    0xFF4E79A7,
    0xFFF28E2B,
    0xFFE15759,
    0xFF76B7B2,
    0xFF59A14F,
    0xFFEDC948,
    0xFFB07AA1,
    0xFF9C755F,
  ];

  Subject addSubject(String name) {
    final s = Subject(
      id: _uuid.v4(),
      name: name.trim(),
      color: palette[_subjects.length % palette.length],
      updatedAt: now,
    );
    _subjects[s.id] = s;
    _changed();
    return s;
  }

  void renameSubject(String id, String name) {
    final s = _subjects[id];
    if (s == null) return;
    _subjects[id] = s.copyWith(name: name.trim());
    _changed();
  }

  void setSubjectColor(String id, int color) {
    final s = _subjects[id];
    if (s == null) return;
    _subjects[id] = s.copyWith(color: color);
    _changed();
  }

  void deleteSubject(String id) {
    final s = _subjects[id];
    if (s == null) return;
    _subjects[id] = s.copyWith(deleted: true);
    _changed();
  }

  /// 기록을 직접 추가하거나 고칩니다. [id]가 없으면 새 기록.
  StudySession saveSession({
    String? id,
    required String subjectId,
    required DateTime startedAt,
    required int focusSeconds,
    int? focusRating,
    String recallNote = '',
  }) {
    final old = id == null ? null : _sessions[id];
    final start = startedAt.toUtc();
    final s = StudySession(
      id: id ?? _uuid.v4(),
      subjectId: subjectId,
      startedAt: start,
      endedAt: start.add(Duration(seconds: focusSeconds)),
      plannedMinutes: old?.plannedMinutes ?? 0,
      focusSeconds: focusSeconds,
      focusRating: focusRating,
      recallNote: recallNote,
      question: old?.question ?? '',
      restType: old?.restType,
      distractions: old?.distractions ?? 0,
      distractedSeconds: old?.distractedSeconds ?? 0,
      updatedAt: now,
    );
    _sessions[s.id] = s;
    _changed();
    return s;
  }

  /// 휴식 중 한 일을 방금 끝낸 블록에 적어 둡니다.
  void setRestType(RestType type) {
    final s = _sessions[_timer.lastSessionId];
    if (s == null) return;
    _sessions[s.id] = s.copyWith(restType: type.name);
    _changed();
  }

  void updateSettings(Settings settings) {
    _settings = settings;
    _changed(local: false);
  }

  // ---------- 딴생각 메모 ----------

  void addThought(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _thoughts.add(ThoughtNote(id: _uuid.v4(), text: t, createdAt: now));
    _changed(local: false);
  }

  void toggleThought(String id) {
    final i = _thoughts.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _thoughts[i] = _thoughts[i].copyWith(done: !_thoughts[i].done);
    _changed(local: false);
  }

  /// 처리한 메모를 모두 지웁니다.
  void clearDoneThoughts() {
    _thoughts.removeWhere((t) => t.done);
    _changed(local: false);
  }

  void deleteThought(String id) {
    _thoughts.removeWhere((t) => t.id == id);
    _changed(local: false);
  }

  void deleteSession(String id) {
    final s = _sessions[id];
    if (s == null) return;
    _sessions[id] = s.copyWith(deleted: true);
    _changed();
  }

  // ---------- 타이머 ----------

  void _setTimer(TimerState next, {bool local = true}) {
    final prev = _timer;
    _timer = next;
    onTimerChanged?.call(prev, next);
    _changed(local: local);
  }

  void startFocus(
    String subjectId,
    int presetIndex, {
    bool stopwatch = false,
  }) => _setTimer(
    TimerLogic.startFocus(
      _timer,
      subjectId: subjectId,
      presetIndex: presetIndex,
      preset: _settings.presetAt(presetIndex),
      sessionId: _uuid.v4(),
      now: now,
      stopwatch: stopwatch,
    ),
  );

  void pause() => _setTimer(TimerLogic.pause(_timer, now));
  void resume() => _setTimer(TimerLogic.resume(_timer, now));
  void finishFocus() => _setTimer(TimerLogic.finishFocus(_timer, now));
  void cancel() => _setTimer(TimerLogic.toIdle(_timer, now));
  void skipRest() => _setTimer(TimerLogic.toIdle(_timer, now));

  /// 맨 앞 앱이 바뀌었을 때 (Mac). 딴짓 앱 목록에 있으면 딴짓으로 셉니다.
  /// 새로 딴짓을 시작했으면 true (알림을 띄우는 데 씁니다).
  bool frontAppChanged(String appName) {
    final blocked =
        _settings.watchApps && _settings.blockedApps.contains(appName);
    final next = blocked
        ? TimerLogic.enterDistraction(_timer, now)
        : TimerLogic.leaveDistraction(_timer, now);
    if (identical(next, _timer)) return false;
    _setTimer(next);
    return blocked;
  }

  void submitRecall({int? rating, String note = ''}) {
    final (session, next) = TimerLogic.submitRecall(
      _timer,
      now: now,
      focusRating: rating,
      recallNote: note,
    );
    _sessions[session.id] = session;
    _setTimer(next);
  }

  /// 매초 호출해 시간이 다 된 단계를 넘깁니다.
  void startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    final next = TimerLogic.tick(_timer, now);
    if (!identical(next, _timer)) {
      _setTimer(next);
    } else if (_timer.isRunning) {
      notifyListeners(); // 남은 시간 표시 갱신
    }
  }

  // ---------- 동기화에서 받은 데이터 ----------

  /// 서버에서 받은 데이터를 합칩니다. 같은 항목은 더 최근에 바뀐 쪽이 이깁니다.
  void mergeRemote({
    Iterable<Subject> subjects = const [],
    Iterable<StudySession> sessions = const [],
    TimerState? timer,
  }) {
    var changed = false;
    for (final s in subjects) {
      final local = _subjects[s.id];
      if (local == null || s.updatedAt.isAfter(local.updatedAt)) {
        _subjects[s.id] = s;
        changed = true;
      }
    }
    for (final s in sessions) {
      final local = _sessions[s.id];
      if (local == null || s.updatedAt.isAfter(local.updatedAt)) {
        _sessions[s.id] = s;
        changed = true;
      }
    }
    if (timer != null && timer.updatedAt.isAfter(_timer.updatedAt)) {
      final prev = _timer;
      _timer = timer;
      onTimerChanged?.call(prev, timer);
      changed = true;
    }
    if (changed) _changed(local: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
