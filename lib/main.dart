import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notifications.dart';
import 'services/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final notifications = Notifications.instance;
  await notifications.init();
  store.onTimerChanged = notifications.sync;
  store.tick(); // 앱이 꺼져 있던 동안 끝난 단계 정리
  store.startTicking();

  if (AppConfig.syncEnabled) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  }
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
      home: AppConfig.syncEnabled
          ? AuthGate(store: store)
          : HomeScreen(store: store),
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
        if (auth.currentSession == null) return const LoginScreen();
        return HomeScreen(store: store, client: Supabase.instance.client);
      },
    );
  }
}
