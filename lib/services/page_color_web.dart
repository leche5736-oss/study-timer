import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

String? _last;

void setPageColor(Color color) {
  final hex =
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  if (hex == _last) return;
  _last = hex;
  web.document.documentElement?.setAttribute('style', 'background:$hex');
  web.document.body?.style.backgroundColor = hex;
  var meta = web.document.querySelector('meta[name="theme-color"]');
  if (meta == null) {
    meta = web.document.createElement('meta')
      ..setAttribute('name', 'theme-color');
    web.document.head?.append(meta);
  }
  meta.setAttribute('content', hex);
}

web.HTMLElement? _probe;

EdgeInsets webSafeArea() {
  // Flutter가 만든 viewport 설정에 viewport-fit=cover를 더해야
  // 아이폰이 가려지는 여백(env(safe-area-inset-*))을 알려 줍니다.
  final meta = web.document.querySelector('meta[name="viewport"]');
  final content = meta?.getAttribute('content') ?? '';
  if (meta != null && !content.contains('viewport-fit')) {
    meta.setAttribute('content', '$content, viewport-fit=cover');
  }
  final probe = _probe ??= () {
    final d = web.document.createElement('div') as web.HTMLElement;
    d.style
      ..position = 'fixed'
      ..visibility = 'hidden'
      ..pointerEvents = 'none'
      ..paddingTop = 'env(safe-area-inset-top)'
      ..paddingBottom = 'env(safe-area-inset-bottom)';
    web.document.body?.append(d);
    return d;
  }();
  final style = web.window.getComputedStyle(probe);
  double px(String v) => double.tryParse(v.replaceAll('px', '')) ?? 0;
  return EdgeInsets.only(
    top: px(style.paddingTop),
    bottom: px(style.paddingBottom),
  );
}
