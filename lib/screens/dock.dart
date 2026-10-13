import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// 화면 아래에 떠 있는 하얀 알약 모양 독. 아이콘만 있고,
/// 고른 칸 뒤에는 옅은 회색 캡슐이 깔립니다.
class Dock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  /// 내 정보 칸에 찍는 점. 새 버전·딴생각 메모가 있으면 파란 점,
  /// 동기화가 안 되면 빨간 점.
  final Color? profileDot;

  const Dock({
    super.key,
    required this.index,
    required this.onTap,
    this.profileDot,
  });

  static const items = [
    (CupertinoIcons.timer, '타이머'),
    (CupertinoIcons.chart_bar, '통계'),
    (CupertinoIcons.list_bullet, '기록'),
    (CupertinoIcons.book, '과목'),
    (CupertinoIcons.person, '내 정보'),
  ];

  /// 독 높이 + 위아래 여유. 목록이 독에 가리지 않도록 이만큼 띄웁니다.
  static const space = 72.0;

  /// 화면 맨 아래에서 독까지. 아이폰은 홈 막대 바로 위(안전 영역의 절반),
  /// 홈 막대가 없는 화면(Mac 등)은 12.
  static double bottomGap(EdgeInsets padding) =>
      padding.bottom > 0 ? padding.bottom * 0.5 : 12;

  @override
  Widget build(BuildContext context) {
    // 화면 폭의 80% 정도로 넓게, 아이콘은 고르게 나눠 놓습니다.
    final width = (MediaQuery.sizeOf(context).width * 0.8).clamp(300.0, 440.0);
    return Container(
      width: width,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2A3345),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final (i, (icon, label)) in items.indexed)
            Expanded(
              child: Tooltip(
                message: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 48,
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.fill : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 25,
                          color: i == index ? AppColors.ink : AppColors.grey,
                        ),
                        if (i == items.length - 1 && profileDot != null)
                          // 아이콘 오른쪽 위에 작은 점
                          Transform.translate(
                            offset: const Offset(11, -10),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: profileDot,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 독 위로 뜨는 알림 막대.
void showDockSnack(
  BuildContext context,
  String text, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, Dock.space),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
