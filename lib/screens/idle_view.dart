import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'space_key.dart';
import 'thoughts_list.dart';

/// 타이머 첫 화면. 밝은 바탕에 큰 시간, 과목 이름, 시작 버튼만 보입니다.
/// 시간을 누르면 길이를, 과목 이름을 누르면 과목을 바꿉니다.
class IdleView extends StatefulWidget {
  final AppStore store;
  final VoidCallback onGoToSubjects;
  const IdleView({
    super.key,
    required this.store,
    required this.onGoToSubjects,
  });

  @override
  State<IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<IdleView> with SpaceKeyShortcut {
  /// 스페이스 키 = 시작
  @override
  void onSpace() {
    if (store.timer.phase == Phase.idle && store.subjects.isNotEmpty) _start();
  }

  late int _preset = widget.store.timer.presetIndex;
  late bool _stopwatch = widget.store.timer.stopwatch;

  AppStore get store => widget.store;

  Preset get _length => store.settings.presetAt(_preset);

  /// 시작을 누르면 과목을 고르고 바로 시작합니다. 과목이 하나면 바로 시작.
  Future<void> _start() async {
    Notifications.instance.requestWebPermission();
    final subjects = store.subjects;
    final id = subjects.length == 1
        ? subjects.single.id
        : await _pickSubject(subjects);
    if (id == null || !mounted) return;
    store.startFocus(id, _preset, stopwatch: _stopwatch);
  }

  Future<String?> _pickSubject(
    List<Subject> subjects,
  ) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '무엇을 공부할까요?',
                style: TextStyle(color: AppColors.grey, fontSize: 15),
              ),
            ),
            for (final s in subjects)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: CircleAvatar(radius: 7, backgroundColor: s.colorValue),
                minLeadingWidth: 14,
                title: Text(s.name, style: const TextStyle(fontSize: 17)),
                // 지난번에 공부한 과목 표시
                trailing: s.id == store.timer.subjectId
                    ? const Text(
                        '지난번',
                        style: TextStyle(color: AppColors.grey, fontSize: 13),
                      )
                    : null,
                onTap: () => Navigator.pop(c, s.id),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (store.subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '공부할 과목을 먼저 추가하세요',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onGoToSubjects,
              child: const Text('과목 추가'),
            ),
          ],
        ),
      );
    }

    final today = todaySeconds(
      store.allSessions,
      DateTime.now(),
      dayStartHour: store.settings.dayStartHour,
    );
    final goal = store.settings.dailyGoalMin * 60;
    final open = store.openThoughts.length;
    final blocks = store.timer.blocksDone;
    const grey = TextStyle(color: AppColors.grey, fontSize: 15);

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            goal > 0
                ? '오늘 ${formatHms(today)} / ${formatHm(goal)}'
                : '오늘 ${formatHms(today)}',
            style: grey.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (open > 0)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.grey),
              onPressed: _showThoughts,
              child: Text('딴생각 메모 $open개'),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _pickLength,
            child: Text(
              _stopwatch ? '00:00' : formatClock(_length.focusMin * 60),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 96,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickLength,
            child: Text(
              [
                _stopwatch ? '스톱워치' : '휴식 ${_length.restMin}분',
                if (blocks > 0) '$blocks블록 완료',
              ].join(' · '),
              style: grey,
            ),
          ),
          const SizedBox(height: 56),
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _start,
              child: const SizedBox(
                width: 88,
                height: 88,
                child: Center(
                  child: Text(
                    '시작',
                    style: TextStyle(color: Colors.white, fontSize: 17),
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

  /// 길이와 타이머/스톱워치 고르기.
  Future<void> _pickLength() async {
    final settings = store.settings;
    final recommend = recommendLength(store.allSessions);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i <= customPresetIndex; i++)
              ListTile(
                title: Text(
                  '${settings.presetAt(i).focusMin}분 집중 · '
                  '${settings.presetAt(i).restMin}분 휴식',
                ),
                subtitle: i == customPresetIndex
                    ? const Text('길이는 설정에서 바꿔요')
                    : null,
                trailing: !_stopwatch && _preset == i
                    ? Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  setState(() {
                    _preset = i;
                    _stopwatch = false;
                  });
                  Navigator.pop(c);
                },
              ),
            ListTile(
              title: const Text('스톱워치'),
              subtitle: const Text('시간 제한 없이, 집중한 시간의 1/5만큼 휴식'),
              trailing: _stopwatch
                  ? Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () {
                setState(() => _stopwatch = true);
                Navigator.pop(c);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                [
                  '$blocksPerLongRest블록마다 긴 휴식',
                  if (recommend != null)
                    '집중도가 가장 높았던 길이: ${recommend.bucket.label}',
                ].join('\n'),
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThoughts() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => ListenableBuilder(
      listenable: store,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ThoughtsList(store: store),
        ),
      ),
    ),
  );
}
