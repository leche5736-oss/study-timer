import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 스페이스 키 단축키 (Mac 키보드 등). 화면이 보이는 동안만 [onSpace]를 부릅니다.
/// 글자를 입력하는 중이거나 다른 창(과목 고르기 등)이 위에 떠 있으면 무시합니다.
mixin SpaceKeyShortcut<T extends StatefulWidget> on State<T> {
  void onSpace();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handle);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handle);
    super.dispose();
  }

  bool _handle(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    if (isEditingText()) return false;
    onSpace();
    return true;
  }
}

/// 글자 입력 칸에 커서가 있는지.
bool isEditingText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}
