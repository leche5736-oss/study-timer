import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../services/store.dart';
import '../services/sync.dart';
import '../services/window.dart';
import '../version.dart';
import 'focus_screen.dart';
import 'history_tab.dart';
import 'idle_drafts.dart';
import 'mini_timer.dart';
import 'rest_screen.dart';
import 'settings_screen.dart';
import 'stats_tab.dart';
import 'subjects_tab.dart';
import 'timer_tab.dart';

class HomeScreen extends StatefulWidget {
  final AppStore store;

  /// 동기화가 꺼져 있으면 null.
  final SupabaseClient? client;

  const HomeScreen({super.key, required this.store, this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  SyncService? _sync;
  bool _mini = false;

  /// 시안을 타이머 탭에서 볼 때는 위아래 막대 색을 화면과 맞춥니다.
  Color? get _chrome {
    if (_tab != 0 || widget.store.timer.phase != Phase.idle) return null;
    return switch (DesignDraft.value.value) {
      1 => Colors.white,
      2 => Colors.black,
      3 => const Color(0xFFF2F2F7),
      _ => null,
    };
  }

  bool get _darkTop => _chrome == Colors.black;

  /// 미니 타이머는 Mac(다른 창 위에 뜸)과 웹(미리보기용)에서만.
  bool get _miniSupported => kIsWeb || AppWindow.isMac;

  void _setMini(bool on) {
    if (_mini == on) return;
    setState(() => _mini = on);
    AppWindow.setMini(on);
  }

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _sync = SyncService(widget.store, widget.client!)..start();
    }
  }

  @override
  void dispose() {
    _sync?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: Listenable.merge([store, DesignDraft.value]),
      builder: (context, _) {
        final phase = store.timer.phase;
        if (_mini) {
          if (phase == Phase.focus || phase == Phase.rest) {
            return MiniTimer(store: store, onExpand: () => _setMini(false));
          }
          // 집중이 끝나 정리 노트를 쓸 때는 원래 크기로 돌아갑니다.
          WidgetsBinding.instance.addPostFrameCallback((_) => _setMini(false));
        }
        // 휴식 중에는 화면 전체를 조용한 휴식 화면으로 바꿉니다.
        if (phase == Phase.rest) return RestScreen(store: store);
        // 집중 중에는 어두운 화면에 시간만 보여줍니다.
        if (phase == Phase.focus) {
          return FocusScreen(
            store: store,
            onMini: _miniSupported ? () => _setMini(true) : null,
          );
        }

        final tabs = [
          TimerTab(
            store: store,
            onGoToSubjects: () => setState(() => _tab = 1),
          ),
          SubjectsTab(store: store),
          StatsTab(store: store),
          HistoryTab(store: store),
        ];
        return Scaffold(
          appBar: AppBar(
            // 시안을 보는 중이면 제목 없이 (미니멀).
            title: DesignDraft.value.value == 0
                ? const Text('공부 타이머 v$appVersion')
                : null,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _chrome,
            foregroundColor: _darkTop ? Colors.white70 : null,
            actions: [
              IconButton(
                tooltip: '설정',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store),
                  ),
                ),
              ),
              if (_sync != null)
                ValueListenableBuilder<String?>(
                  valueListenable: _sync!.lastError,
                  builder: (context, err, _) => IconButton(
                    tooltip: err ?? '동기화됨',
                    icon: Icon(
                      err == null ? Icons.cloud_done : Icons.cloud_off,
                      color: err == null ? null : Colors.red,
                    ),
                    onPressed: () {
                      _sync!.pull();
                      _sync!.push();
                    },
                  ),
                ),
              if (widget.client != null)
                IconButton(
                  tooltip: '로그아웃',
                  icon: const Icon(Icons.logout),
                  onPressed: () => widget.client!.auth.signOut(),
                ),
            ],
          ),
          body: SafeArea(child: tabs[_tab]),
          bottomNavigationBar: NavigationBar(
            backgroundColor: _chrome,
            indicatorColor: _chrome == null
                ? null
                : (_darkTop ? Colors.white12 : Colors.black12),
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.timer), label: '타이머'),
              NavigationDestination(icon: Icon(Icons.book), label: '과목'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: '통계'),
              NavigationDestination(icon: Icon(Icons.history), label: '기록'),
            ],
          ),
        );
      },
    );
  }
}
