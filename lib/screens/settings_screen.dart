import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/store.dart';
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
              const Divider(),
              ListTile(title: const Text('버전'), trailing: Text(appVersion)),
            ],
          );
        },
      ),
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
