import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../services/store.dart';
import '../services/sync.dart';
import '../services/window.dart';
import 'focus_screen.dart';
import 'history_tab.dart';
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
      listenable: store,
      builder: (context, _) {
        final phase = store.timer.phase;
        if (_mini) {
          if (phase == Phase.focus || phase == Phase.rest) {
            return MiniTimer(store: store, onExpand: () => _setMini(false));
          }
          // 집중이 끝나 정리 노트를 쓸 때는 원래 크기로 돌아갑니다.
          WidgetsBinding.instance.addPostFrameCallback((_) => _setMini(false));
        }
        // 집중 중에는 어두운 화면에 시간만, 휴식 중에는 조용한 휴식 화면.
        // 밝은 화면에서 천천히 어두워지며 넘어갑니다.
        final Widget page = switch (phase) {
          Phase.focus => FocusScreen(
            store: store,
            onMini: _miniSupported ? () => _setMini(true) : null,
          ),
          Phase.rest => RestScreen(store: store),
          _ => _home(context),
        };
        // 검은 바탕 위에서 이전 화면이 먼저 사라지고 새 화면이 나타납니다.
        return ColoredBox(
          color: Colors.black,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
            switchOutCurve: const Interval(0.4, 1, curve: Curves.easeIn),
            child: KeyedSubtree(
              key: ValueKey(
                phase == Phase.idle || phase == Phase.recall ? 0 : phase.index,
              ),
              child: page,
            ),
          ),
        );
      },
    );
  }

  Widget _home(BuildContext context) {
    final store = widget.store;
    final tabs = [
      TimerTab(store: store, onGoToSubjects: () => setState(() => _tab = 1)),
      SubjectsTab(store: store),
      StatsTab(store: store),
      HistoryTab(store: store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: _tab == 0 ? null : Text(const ['', '과목', '통계', '기록'][_tab]),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
            ),
          ),
          if (_sync != null)
            ValueListenableBuilder<String?>(
              valueListenable: _sync!.lastError,
              // 동기화가 안 될 때만 보입니다. 누르면 다시 시도.
              builder: (context, err, _) => err == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: err,
                      icon: const Icon(Icons.cloud_off, color: Colors.red),
                      onPressed: () {
                        _sync!.pull();
                        _sync!.push();
                      },
                    ),
            ),
        ],
      ),
      body: SafeArea(child: tabs[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '타이머',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '과목',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '기록',
          ),
        ],
      ),
    );
  }
}
