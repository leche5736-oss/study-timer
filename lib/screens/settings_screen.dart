import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/store.dart';
import '../services/window.dart';
import '../version.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final isMac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          return ListView(
            children: [
              const _Header('오늘 목표'),
              _MinutesTile(
                title: '하루 목표 공부 시간',
                subtitle: s.dailyGoalMin == 0 ? '목표 없음' : null,
                minutes: s.dailyGoalMin,
                min: 0,
                max: 960,
                step: 30,
                onChanged: (v) =>
                    store.updateSettings(s.copyWith(dailyGoalMin: v)),
              ),
              ListTile(
                title: const Text('하루가 바뀌는 시각'),
                subtitle: Text(
                  '새벽 ${s.dayStartHour}시 전 공부는 전날 기록으로 셉니다 (통계, 오늘 목표)',
                ),
                trailing: DropdownButton<int>(
                  value: s.dayStartHour,
                  items: [
                    for (var h = 0; h <= 8; h++)
                      DropdownMenuItem(
                        value: h,
                        child: Text(h == 0 ? '자정' : '새벽 $h시'),
                      ),
                  ],
                  onChanged: (v) =>
                      store.updateSettings(s.copyWith(dayStartHour: v)),
                ),
              ),
              const _Header('직접 설정 타이머 길이'),
              _MinutesTile(
                title: '집중',
                minutes: s.customFocusMin,
                min: 5,
                max: 180,
                step: 5,
                onChanged: (v) =>
                    store.updateSettings(s.copyWith(customFocusMin: v)),
              ),
              _MinutesTile(
                title: '휴식',
                minutes: s.customRestMin,
                min: 1,
                max: 60,
                step: 1,
                onChanged: (v) =>
                    store.updateSettings(s.copyWith(customRestMin: v)),
              ),
              _MinutesTile(
                title: '긴 휴식 (4블록마다)',
                minutes: s.customLongRestMin,
                min: 5,
                max: 60,
                step: 5,
                onChanged: (v) =>
                    store.updateSettings(s.copyWith(customLongRestMin: v)),
              ),
              const _Header('알림'),
              SwitchListTile(
                title: const Text('알림 소리'),
                value: s.sound,
                onChanged: (v) {
                  Notifications.instance.sound = v;
                  store.updateSettings(s.copyWith(sound: v));
                },
              ),
              if (isMac)
                SwitchListTile(
                  title: const Text('시간이 다 되면 앱 창을 앞으로'),
                  subtitle: const Text('다른 앱을 보고 있어도 타이머 창이 맨 앞에 나와요'),
                  value: s.bringToFront,
                  onChanged: (v) =>
                      store.updateSettings(s.copyWith(bringToFront: v)),
                ),
              if (isMac) ...[
                const _Header('딴짓 앱 감지'),
                SwitchListTile(
                  title: const Text('집중 중 딴짓 앱을 열면 알려 주기'),
                  subtitle: const Text(
                    '아래 앱이 맨 앞에 오면 알림을 띄우고 딴짓 횟수·시간을 기록해요. '
                    '브라우저는 앱 단위라 사이트(유튜브 등)는 구분하지 못해요.',
                  ),
                  value: s.watchApps,
                  onChanged: (v) =>
                      store.updateSettings(s.copyWith(watchApps: v)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final app in s.blockedApps)
                        InputChip(
                          label: Text(app),
                          onDeleted: () => store.updateSettings(
                            s.copyWith(
                              blockedApps: [
                                for (final a in s.blockedApps)
                                  if (a != app) a,
                              ],
                            ),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('딴짓 앱 추가'),
                        onPressed: () => _addApps(context),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              ListTile(title: const Text('버전'), trailing: Text(appVersion)),
            ],
          );
        },
      ),
    );
  }
}

extension on SettingsScreen {
  /// 켜져 있는 앱 중에서 고르거나 이름을 직접 적어 딴짓 앱으로 추가합니다.
  Future<void> _addApps(BuildContext context) async {
    final running = await AppWindow.runningApps();
    if (!context.mounted) return;
    final current = store.settings.blockedApps;
    final picked = <String>{};
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('딴짓 앱 추가'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('지금 켜져 있는 앱'),
                for (final app in running)
                  if (!current.contains(app))
                    CheckboxListTile(
                      dense: true,
                      title: Text(app),
                      value: picked.contains(app),
                      onChanged: (v) => setState(
                        () => v == true ? picked.add(app) : picked.remove(app),
                      ),
                    ),
                const SizedBox(height: 12),
                TextField(
                  controller: typed,
                  decoration: const InputDecoration(
                    labelText: '목록에 없으면 앱 이름 직접 입력',
                    hintText: '예: KakaoTalk',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
    final name = typed.text.trim();
    typed.dispose();
    if (ok != true) return;
    if (name.isNotEmpty) picked.add(name);
    final s = store.settings;
    store.updateSettings(
      s.copyWith(blockedApps: {...s.blockedApps, ...picked}.toList()),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// −/+ 버튼으로 분 단위 값을 바꾸는 줄.
class _MinutesTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int minutes;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _MinutesTile({
    required this.title,
    this.subtitle,
    required this.minutes,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final h = minutes ~/ 60, m = minutes % 60;
    final label = h > 0 ? (m > 0 ? '$h시간 $m분' : '$h시간') : '$m분';
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '$title 줄이기',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: minutes <= min
                ? null
                : () => onChanged((minutes - step).clamp(min, max)),
          ),
          SizedBox(width: 72, child: Text(label, textAlign: TextAlign.center)),
          IconButton(
            tooltip: '$title 늘리기',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: minutes >= max
                ? null
                : () => onChanged((minutes + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}
