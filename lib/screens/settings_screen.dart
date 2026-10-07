import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import '../services/sync_config.dart';
import '../services/window.dart';
import '../theme.dart';
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
              const _Header('색 테마'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    for (final t in colorThemes)
                      _ThemeChoice(
                        theme: t,
                        selected: t.id == colorThemeById(s.colorTheme).id,
                        onTap: () =>
                            store.updateSettings(s.copyWith(colorTheme: t.id)),
                      ),
                  ],
                ),
              ),
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
                SwitchListTile(
                  title: const Text('메뉴 막대에 항상 표시'),
                  subtitle: const Text(
                    '화면 맨 위에 오늘 공부 시간(공부 중에는 남은 시간)이 보이고, '
                    '눌러서 바로 시작할 수 있어요',
                  ),
                  value: s.menuBar,
                  onChanged: (v) =>
                      store.updateSettings(s.copyWith(menuBar: v)),
                ),
                const _LaunchAtLoginTile(),
              ],
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
              const _Header('기기 간 동기화'),
              ValueListenableBuilder<SyncConfig?>(
                valueListenable: SyncConfig.active,
                builder: (context, sync, _) => ListTile(
                  title: Text(sync == null ? '꺼짐 (이 기기에만 저장)' : '켜짐'),
                  subtitle: Text(
                    sync == null
                        ? 'Supabase 주소와 키를 넣으면 Mac, iPhone, iPad 기록이 합쳐져요'
                        : sync.url,
                  ),
                  trailing: sync == null
                      ? FilledButton(
                          onPressed: () => _connectSync(context),
                          child: const Text('연결'),
                        )
                      : OutlinedButton(
                          onPressed: () => SyncConfig.disconnect(store.prefs),
                          child: const Text('끄기'),
                        ),
                ),
              ),
              ValueListenableBuilder<SyncConfig?>(
                valueListenable: SyncConfig.active,
                builder: (context, sync, _) => sync == null
                    ? const SizedBox.shrink()
                    : ListTile(
                        title: const Text('로그아웃'),
                        onTap: () {
                          Navigator.pop(context);
                          Supabase.instance.client.auth.signOut();
                        },
                      ),
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

extension on SettingsScreen {
  /// Supabase 주소와 키를 받아 동기화를 켭니다.
  Future<void> _connectSync(BuildContext context) async {
    final url = TextEditingController(text: AppConfig.supabaseUrl);
    final key = TextEditingController(text: AppConfig.supabasePublishableKey);
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('동기화 연결'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supabase 프로젝트의 Project Settings > API(또는 Data API) 화면에서 복사해 붙여 넣으세요. '
                  '모든 기기에 같은 값을 넣고 같은 계정으로 로그인하면 됩니다.',
                ),
                TextField(
                  controller: url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Project URL',
                    hintText: 'https://xxxx.supabase.co',
                  ),
                ),
                TextField(
                  controller: key,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Publishable key (또는 anon key)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await SyncConfig.connect(
                          store.prefs,
                          url.text,
                          key.text,
                        );
                        if (c.mounted) Navigator.pop(c);
                      } on FormatException catch (e) {
                        setState(() => error = e.message);
                      } on StateError catch (e) {
                        setState(() => error = e.message);
                      } catch (e) {
                        setState(() => error = '연결 실패: $e');
                      } finally {
                        if (c.mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('연결'),
            ),
          ],
        ),
      ),
    );
    url.dispose();
    key.dispose();
    // 연결되면 로그인 화면이 나오도록 설정 화면을 닫습니다.
    if (SyncConfig.active.value != null && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

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

/// 로그인할 때 자동 실행. 값은 macOS가 들고 있어서 직접 물어봅니다.
class _LaunchAtLoginTile extends StatefulWidget {
  const _LaunchAtLoginTile();

  @override
  State<_LaunchAtLoginTile> createState() => _LaunchAtLoginTileState();
}

class _LaunchAtLoginTileState extends State<_LaunchAtLoginTile> {
  bool? _on;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppWindow.launchAtLogin().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: const Text('Mac을 켤 때 자동 실행'),
    subtitle: Text(
      _error ?? '로그인하면 앱이 켜져서 메뉴 막대에 바로 보여요 (macOS 13 이상)',
      style: _error == null ? null : const TextStyle(color: Colors.red),
    ),
    value: _on ?? false,
    onChanged: _on == null
        ? null
        : (v) async {
            setState(() {
              _on = v;
              _error = null;
            });
            try {
              await AppWindow.setLaunchAtLogin(v);
            } catch (e) {
              if (mounted) {
                setState(() {
                  _on = !v;
                  _error = '바꾸지 못했어요: $e';
                });
              }
            }
          },
  );
}

/// 색 테마 하나: 동그라미와 이름. 고른 것은 테두리가 진해집니다.
class _ThemeChoice extends StatelessWidget {
  final ColorTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChoice({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('theme-${theme.id}'),
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.ink : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            theme.label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.ink : AppColors.grey,
            ),
          ),
        ],
      ),
    ),
  );
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
          ?.copyWith(color: AppColors.grey),
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
