import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notifications.dart';
import 'services/store.dart';
import 'services/sync_config.dart';
import 'services/window.dart';
import 'stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final notifications = Notifications.instance;
  await notifications.init();
  notifications.sound = store.settings.sound;
  store.onTimerChanged = (previous, next) {
    notifications.sync(previous, next);
    if (store.settings.bringToFront && Notifications.isTimeUp(previous, next)) {
      AppWindow.bringToFront();
    }
  };
  AppWindow.listen(
    onFrontApp: (app) {
      if (store.frontAppChanged(app)) notifications.nudge(app);
    },
    onMenu: (id) => _menuAction(store, id),
  );
  // Mac 메뉴 막대: 오늘 공부 시간 또는 남은 시간, 누르면 바로 시작하는 메뉴.
  void updateMenuBar() {
    final s = store.settings;
    if (!s.menuBar) return AppWindow.setStatus(null).ignore();
    final today = todaySeconds(
      store.allSessions,
      DateTime.now(),
      dayStartHour: s.dayStartHour,
    );
    AppWindow.setStatus(
      menuBarText(store.timer, store.now, todaySec: today),
      menuBarItems(
        store.timer,
        store.subjects,
        todaySec: today,
        goalSec: s.dailyGoalMin * 60,
      ),
    );
  }

  store.addListener(updateMenuBar);
  Timer.periodic(const Duration(minutes: 1), (_) => updateMenuBar());
  updateMenuBar();
  store.tick(); // 앱이 꺼져 있던 동안 끝난 단계 정리
  store.startTicking();

  await SyncConfig.startFromSaved(prefs);
  runApp(StudyTimerApp(store: store));
}

/// 메뉴 막대 메뉴를 눌렀을 때.
void _menuAction(AppStore store, String id) {
  final t = store.timer;
  if (id.startsWith('start:')) {
    store.startFocus(id.substring(6), t.presetIndex, stopwatch: t.stopwatch);
    return;
  }
  switch (id) {
    case 'pause':
      store.pause();
    case 'resume':
      store.resume();
    case 'finish':
      store.finishFocus();
      AppWindow.bringToFront(); // 정리 노트를 쓰도록 창을 앞으로
    case 'skipRest':
      store.skipRest();
  }
}

class StudyTimerApp extends StatelessWidget {
  final AppStore store;
  const StudyTimerApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공부 타이머',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ValueListenableBuilder<SyncConfig?>(
        valueListenable: SyncConfig.active,
        builder: (context, sync, _) =>
            sync == null ? HomeScreen(store: store) : AuthGate(store: store),
      ),
    );
  }
}

/// 동기화가 켜져 있으면 로그인한 뒤에만 홈 화면을 보여줍니다.
class AuthGate extends StatelessWidget {
  final AppStore store;
  const AuthGate({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        if (auth.currentSession == null) return LoginScreen(store: store);
        return HomeScreen(store: store, client: Supabase.instance.client);
      },
    );
  }
}
