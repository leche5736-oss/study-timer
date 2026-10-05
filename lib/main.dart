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
  AppWindow.listenFrontApp((app) {
    if (store.frontAppChanged(app)) notifications.nudge(app);
  });
  // Mac 메뉴 막대에 남은 시간 (매초 store가 바뀔 때마다 갱신).
  store.addListener(() {
    AppWindow.setStatus(
      store.settings.menuBar ? menuBarText(store.timer, store.now) : null,
    );
  });
  store.tick(); // 앱이 꺼져 있던 동안 끝난 단계 정리
  store.startTicking();

  await SyncConfig.startFromSaved(prefs);
  runApp(StudyTimerApp(store: store));
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
