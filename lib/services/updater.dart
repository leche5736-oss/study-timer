import 'dart:async';

import 'package:flutter/foundation.dart';

import '../version.dart';
import 'window.dart';

/// Mac 앱: GitHub Releases에 새 버전이 올라왔는지 확인합니다.
/// 켤 때와 6시간마다 확인하고, 있으면 [available]에 담아 첫 화면에 알려 줍니다.
class Updater {
  static final available = ValueNotifier<({String version, String page})?>(
    null,
  );
  static Timer? _timer;

  static void start() {
    if (!AppWindow.isMac) return;
    check();
    _timer ??= Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  static Future<void> check() async {
    final r = await AppWindow.checkUpdate();
    if (r == null) return;
    available.value = isNewer(r.version, appVersion) ? r : null;
  }

  /// 받는 페이지를 브라우저로 엽니다.
  static Future<void> openDownload() async {
    final r = available.value;
    if (r != null) await AppWindow.openURL(r.page);
  }

  /// "0.8.10"이 "0.8.9"보다 새것인지처럼 점으로 나눈 숫자를 차례로 비교합니다.
  static bool isNewer(String a, String b) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < x.length || i < y.length; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }
}
