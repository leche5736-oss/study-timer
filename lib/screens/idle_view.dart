import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../services/updater.dart';
import '../stats.dart';
import '../theme.dart';
import 'space_key.dart';
import 'subject_picker.dart';
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
  bool get _timerMode => !_stopwatch && _preset == timerPresetIndex;

  /// 시작을 누르면 과목을 고르고 바로 시작합니다. 과목이 하나면 바로 시작.
  Future<void> _start() async {
    Notifications.instance.requestWebPermission();
    final subjects = store.subjects;
    final id = subjects.length == 1
        ? subjects.single.id
        : await pickSubject(context, subjects, markId: store.timer.subjectId);
    if (id == null || !mounted) return;
    store.startFocus(id, _preset, stopwatch: _stopwatch);
  }

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

    final clock = <Widget>[
      GestureDetector(
        onTap: _pickLength,
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
      ),
      GestureDetector(
        onTap: _pickLength,
        child: Text(
          [
            _stopwatch
                ? '스톱워치'
                : _timerMode
                ? '타이머 · 휴식 없이'
                : '휴식 ${_length.restMin}분',
            if (blocks > 0) '$blocks블록 완료',
          ].join(' · '),
          style: grey,
        ),
      ),
    ];
    final start = Material(
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
    );
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height && size.height < 520;

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
          // Mac 앱: 새 버전이 나오면 알려 줍니다.
          ValueListenableBuilder(
            valueListenable: Updater.available,
            builder: (context, update, _) => update == null
                ? const SizedBox.shrink()
                : TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    onPressed: Updater.openDownload,
                    child: Text('새 버전 ${update.version} 받기'),
                  ),
          ),
          if (open > 0)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.grey),
              onPressed: _showThoughts,
              child: Text('딴생각 메모 $open개'),
            ),
          const Spacer(),
          // 가로 화면(폰을 눕힘)에서는 시간과 시작 버튼을 옆으로 나란히.
          if (landscape)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: clock),
                const SizedBox(width: 64),
                start,
              ],
            )
          else ...[
            ...clock,
            const SizedBox(height: 56),
            start,
          ],
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
              title: const Text('타이머'),
              subtitle: Text(
                '${_hm(settings.timerMin)} · 휴식 없이 한 번에 (눌러서 길이 바꾸기)',
              ),
              trailing: _timerMode
                  ? Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () {
                Navigator.pop(c);
                _pickTimerLength();
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

  static String _hm(int min) => [
    if (min >= 60) '${min ~/ 60}시간',
    if (min % 60 > 0 || min < 60) '${min % 60}분',
  ].join(' ');

  /// 타이머 길이 고르기 (시간·분 돌림판).
  Future<void> _pickTimerLength() async {
    var picked = Duration(minutes: store.settings.timerMin);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 216,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: picked,
                onTimerDurationChanged: (d) => picked = d,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                key: const Key('timer-length-ok'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('이 길이로'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final min = picked.inMinutes.clamp(1, 12 * 60);
    store.updateSettings(store.settings.copyWith(timerMin: min));
    setState(() {
      _preset = timerPresetIndex;
      _stopwatch = false;
    });
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
