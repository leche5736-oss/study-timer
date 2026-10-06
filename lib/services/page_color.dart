import 'package:flutter/painting.dart';

import 'page_color_stub.dart'
    if (dart.library.js_interop) 'page_color_web.dart'
    as impl;

/// 웹에서 페이지 바탕색과 iPhone 상단 상태 막대 색을 화면 색에 맞춥니다.
/// (집중 화면이 어두울 때 위쪽만 하얗게 남지 않도록.) 앱에서는 아무것도 안 합니다.
void setPageColor(Color color) => impl.setPageColor(color);

/// 웹: 화면을 아이폰 위쪽 끝(상태 막대 뒤)까지 쓰게 하고, 가려지는 위·아래 여백을
/// 돌려줍니다. Flutter 웹은 이 여백을 모르므로 앱에서 직접 넣어 줍니다.
/// 앱에서는 EdgeInsets.zero.
EdgeInsets webSafeArea() => impl.webSafeArea();
