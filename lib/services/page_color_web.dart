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
