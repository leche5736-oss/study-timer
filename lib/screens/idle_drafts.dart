import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../stats.dart';

/// 디자인 시안 (임시). 0 = 지금 화면, 1~3 = 시안 A~C.
/// 고른 시안만 남기고 나머지는 지웁니다.
class DesignDraft {
  static const _key = 'design_draft';
  static final value = ValueNotifier<int>(0);

  static void load(AppStore store) {
    value.value = store.prefs.getInt(_key) ?? (kIsWeb ? 1 : 0);
  }

  static void set(AppStore store, int v) {
    value.value = v;
    store.prefs.setInt(_key, v);
  }
}

/// 웹 미리보기에서만 보이는 시안 고르기 줄.
class DraftPicker extends StatelessWidget {
  final AppStore store;
  final bool dark;
  const DraftPicker({super.key, required this.store, this.dark = false});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    const labels = ['지금', 'A', 'B', 'C'];
    final fg = dark ? Colors.white54 : Colors.black45;
    return ValueListenableBuilder<int>(
      valueListenable: DesignDraft.value,
      builder: (context, v, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('시안', style: TextStyle(fontSize: 12, color: fg)),
          for (var i = 0; i < labels.length; i++)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: i == v
                    ? (dark ? Colors.white : Colors.black)
                    : fg,
                minimumSize: const Size(36, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => DesignDraft.set(store, i),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == v ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 시안들이 함께 쓰는 선택 상태: 과목, 길이, 타이머/스톱워치.
abstract class _DraftState<T extends StatefulWidget> extends State<T> {
  AppStore get store;

  String? _subjectId;
  late int preset = store.timer.presetIndex;
  late bool stopwatch = store.timer.stopwatch;

  Subject get subject {
    final list = store.subjects;
    return list.firstWhere(
      (s) => s.id == _subjectId,
      orElse: () => list.firstWhere(
        (s) => s.id == store.timer.subjectId,
        orElse: () => list.first,
      ),
    );
  }

  set subjectId(String id) => setState(() => _subjectId = id);

  Preset get presetValue => store.settings.presetAt(preset);

  String get lengthLabel => stopwatch
      ? '스톱워치'
      : '${presetValue.focusMin}분 집중 · ${presetValue.restMin}분 휴식';

  int get todaySec => todaySeconds(
    store.allSessions,
    DateTime.now(),
    dayStartHour: store.settings.dayStartHour,
  );

  void start([String? subjectId]) {
    Notifications.instance.requestWebPermission();
    store.startFocus(subjectId ?? subject.id, preset, stopwatch: stopwatch);
  }

  /// 과목 고르기.
  Future<void> pickSubject({bool dark = false}) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: dark ? const Color(0xFF1C1C1E) : null,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in store.subjects)
              ListTile(
                leading: CircleAvatar(radius: 6, backgroundColor: s.colorValue),
                title: Text(
                  s.name,
                  style: TextStyle(color: dark ? Colors.white : null),
                ),
                trailing: s.id == subject.id
                    ? Icon(Icons.check, color: dark ? Colors.white : null)
                    : null,
                onTap: () => Navigator.pop(c, s.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) subjectId = id;
  }

  /// 길이와 타이머/스톱워치 고르기.
  Future<void> pickLength({bool dark = false}) async {
    final fg = dark ? Colors.white : null;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? const Color(0xFF1C1C1E) : null,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i <= customPresetIndex; i++)
              ListTile(
                title: Text(
                  '${store.settings.presetAt(i).focusMin}분 집중 · '
                  '${store.settings.presetAt(i).restMin}분 휴식',
                  style: TextStyle(color: fg),
                ),
                trailing: !stopwatch && preset == i
                    ? Icon(Icons.check, color: fg)
                    : null,
                onTap: () {
                  setState(() {
                    preset = i;
                    stopwatch = false;
                  });
                  Navigator.pop(c);
                },
              ),
            ListTile(
              title: Text('스톱워치 (시간 제한 없이)', style: TextStyle(color: fg)),
              trailing: stopwatch ? Icon(Icons.check, color: fg) : null,
              onTap: () {
                setState(() => stopwatch = true);
                Navigator.pop(c);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 시안 A: 버튼 하나. 흰 화면 가운데 큰 동그란 시작 버튼, 그 위에 과목과 길이만.

class DraftA extends StatefulWidget {
  final AppStore store;
  const DraftA({super.key, required this.store});

  @override
  State<DraftA> createState() => _DraftAState();
}

class _DraftAState extends _DraftState<DraftA> {
  @override
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF8E8E93);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          DraftPicker(store: store),
          const SizedBox(height: 8),
          Text(
            '오늘 ${formatHms(todaySec)}',
            style: const TextStyle(color: grey, fontSize: 15),
          ),
          const Spacer(),
          GestureDetector(
            onTap: pickSubject,
            child: Text(
              subject.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: pickLength,
            child: Text(
              lengthLabel,
              style: const TextStyle(color: grey, fontSize: 15),
            ),
          ),
          const SizedBox(height: 48),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: start,
              child: const SizedBox(
                width: 168,
                height: 168,
                child: Center(
                  child: Text(
                    '시작',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 시안 B: 시계 중심. 검은 화면에 얇고 큰 시간, 과목은 글자만, 동그란 시작 버튼
// (Apple 시계 앱의 타이머 화면 느낌).

class DraftB extends StatefulWidget {
  final AppStore store;
  const DraftB({super.key, required this.store});

  @override
  State<DraftB> createState() => _DraftBState();
}

class _DraftBState extends _DraftState<DraftB> {
  @override
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF8E8E93);
    final subjects = store.subjects;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          DraftPicker(store: store, dark: true),
          const SizedBox(height: 8),
          Text(
            '오늘 ${formatHms(todaySec)}',
            style: const TextStyle(color: grey, fontSize: 15),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => pickLength(dark: true),
            child: Text(
              stopwatch ? '00:00' : formatClock(presetValue.focusMin * 60),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.w200,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => pickLength(dark: true),
            child: Text(
              stopwatch ? '스톱워치' : '휴식 ${presetValue.restMin}분',
              style: const TextStyle(color: grey, fontSize: 15),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final s in subjects)
                  GestureDetector(
                    onTap: () => subjectId = s.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 17,
                            color: s.id == subject.id
                                ? Colors.white
                                : const Color(0xFF48484A),
                            fontWeight: s.id == subject.id
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Material(
            color: const Color(0xFF0E3A1E),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: start,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: const Center(
                  child: Text(
                    '시작',
                    style: TextStyle(color: Color(0xFF30D158), fontSize: 17),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 시안 C: 목록형. 위에 오늘 공부 시간 하나, 아래 과목 목록. 과목을 누르면 바로 시작
// (Apple 미리 알림·건강 앱 느낌).

class DraftC extends StatefulWidget {
  final AppStore store;
  const DraftC({super.key, required this.store});

  @override
  State<DraftC> createState() => _DraftCState();
}

class _DraftCState extends _DraftState<DraftC> {
  @override
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF2F2F7);
    const grey = Color(0xFF8E8E93);
    final goal = store.settings.dailyGoalMin * 60;
    final today = todaySec;
    final subjects = store.subjects;
    return ColoredBox(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          DraftPicker(store: store),
          const SizedBox(height: 16),
          const Text('오늘', style: TextStyle(color: grey, fontSize: 15)),
          Text(
            formatHms(today),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (goal > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (today / goal).clamp(0, 1),
                minHeight: 4,
                color: Colors.black,
                backgroundColor: const Color(0xFFE5E5EA),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '목표 ${formatHm(goal)}',
              style: const TextStyle(color: grey, fontSize: 13),
            ),
          ],
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < subjects.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 44,
                      color: Color(0xFFE5E5EA),
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 6,
                      backgroundColor: subjects[i].colorValue,
                    ),
                    minLeadingWidth: 12,
                    title: Text(subjects[i].name),
                    trailing: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFFC7C7CC),
                    ),
                    onTap: () => start(subjects[i].id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: pickLength,
              style: TextButton.styleFrom(foregroundColor: grey),
              child: Text('$lengthLabel  ›'),
            ),
          ),
        ],
      ),
    );
  }
}
