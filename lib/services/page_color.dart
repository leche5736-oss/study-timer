import 'package:flutter/painting.dart';

import 'page_color_stub.dart'
    if (dart.library.js_interop) 'page_color_web.dart'
    as impl;

/// 웹에서 페이지 바탕색과 iPhone 상단 상태 막대 색을 화면 색에 맞춥니다.
/// (집중 화면이 어두울 때 위쪽만 하얗게 남지 않도록.) 앱에서는 아무것도 안 합니다.
void setPageColor(Color color) => impl.setPageColor(color);
