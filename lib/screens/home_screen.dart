import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../services/store.dart';
import '../services/sync.dart';
import '../version.dart';
import 'history_tab.dart';
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
        // 휴식 중에는 화면 전체를 조용한 휴식 화면으로 바꿉니다.
        if (store.timer.phase == Phase.rest) return RestScreen(store: store);

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
            title: const Text('공부 타이머 v$appVersion'),
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
