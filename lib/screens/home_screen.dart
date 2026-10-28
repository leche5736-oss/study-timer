import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../services/page_color.dart';
import '../services/store.dart';
import '../services/sync.dart';
import '../services/updater.dart';
import '../services/window.dart';
import '../theme.dart';
import 'dock.dart';
import 'focus_screen.dart';
import 'history_tab.dart';
import 'mini_timer.dart';
import 'rest_screen.dart';
import 'profile_tab.dart';
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
        // 위쪽 상태 막대(시간·배터리)도 화면 색에 맞춥니다.
        final dark = phase == Phase.focus;
        setPageColor(
          dark
              ? AppColors.night
              : (phase == Phase.rest ? AppColors.restBg : Colors.white),
        );
        // 어두운 바탕 위에서 이전 화면이 먼저 사라지고 새 화면이 나타납니다.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: ColoredBox(
            color: AppColors.night,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
              switchOutCurve: const Interval(0.4, 1, curve: Curves.easeIn),
              child: KeyedSubtree(
                key: ValueKey(
                  phase == Phase.idle || phase == Phase.recall
                      ? 0
                      : phase.index,
                ),
                child: page,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _home(BuildContext context) {
    final store = widget.store;
    // 정리 노트를 쓰는 동안에는 독을 숨기고 저장에 집중합니다.
    final recall = store.timer.phase == Phase.recall;
    final tab = recall ? 0 : _tab;
    final page = switch (tab) {
      1 => StatsTab(store: store),
      2 => HistoryTab(store: store),
      3 => SubjectsTab(store: store),
      4 => ProfileTab(store: store, sync: _sync),
      _ => TimerTab(
        store: store,
        onGoToSubjects: () => setState(() => _tab = 3),
      ),
    };
    final mq = MediaQuery.of(context);
    final bottom = recall
        ? mq.padding.bottom
        : Dock.space + Dock.bottomGap(mq.padding);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: mq.padding.top),
              // 목록은 아래 여백(독 자리)만큼 더 내려가도록 합니다.
              child: MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(top: 0, bottom: bottom),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab != 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          Dock.items[tab].$2,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    Expanded(child: page),
                  ],
                ),
              ),
            ),
          ),
          if (!recall)
            Positioned(
              left: 0,
              right: 0,
              bottom: Dock.bottomGap(mq.padding),
              child: Center(child: _dock()),
            ),
        ],
      ),
    );
  }

  static final _noError = ValueNotifier<String?>(null);

  Widget _dock() {
    final store = widget.store;
    final err = _sync?.lastError ?? _noError;
    return ValueListenableBuilder<String?>(
      valueListenable: err,
      builder: (context, error, _) => ValueListenableBuilder(
        valueListenable: Updater.available,
        builder: (context, update, _) => Dock(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          profileDot: error != null
              ? Colors.red
              : (update != null || store.openThoughts.isNotEmpty
                    ? AppColors.accent
                    : null),
        ),
      ),
    );
  }
}
