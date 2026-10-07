import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 폰의 기울기(중력 방향)로 화면을 몇 번 돌릴지 정합니다.
/// 0: 세로, 1: 시계 방향 90°(폰 위쪽이 왼쪽), 3: 반시계 방향 90°(폰 위쪽이 오른쪽).
/// 애매한 각도나 바닥에 눕혀 둔 상태에서는 이전 값을 유지합니다.
int tiltTurns(double x, double y, int previous) {
  const strong = 7.0, weak = 4.0;
  if (y.abs() > strong && x.abs() < weak) return 0;
  if (x > strong && y.abs() < weak) return 1;
  if (x < -strong && y.abs() < weak) return 3;
  return previous;
}

/// 아이폰에서 "세로 화면 잠금"을 켜 두면 iOS가 화면을 돌려 주지 않으므로,
/// 폰을 눕혔을 때 앱이 직접 화면을 가로로 돌려 그립니다.
/// iOS가 이미 가로로 돌려 줬거나 다른 기기면 아무것도 하지 않습니다.
class TiltRotate extends StatefulWidget {
  final Widget child;
  const TiltRotate({super.key, required this.child});

  @override
  State<TiltRotate> createState() => _TiltRotateState();
}

class _TiltRotateState extends State<TiltRotate> {
  StreamSubscription<AccelerometerEvent>? _sub;
  int _turns = 0;
  int _applied = 0; // 상태 막대를 마지막으로 숨기거나 보인 기준

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen(
          (e) {
            final next = tiltTurns(e.x, e.y, _turns);
            if (next != _turns) setState(() => _turns = next);
          },
          onError: (Object _) {}, // 센서가 없으면 그냥 세로로
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_applied != 0) _setStatusBar(visible: true);
    super.dispose();
  }

  void _setStatusBar({required bool visible}) =>
      SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ).ignore();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final portrait = mq.size.height > mq.size.width;
    final turns = portrait ? _turns : 0;
    // 돌려 그리는 동안은 세로 방향 상태 막대를 숨깁니다.
    if ((turns != 0) != (_applied != 0)) {
      _applied = turns;
      _setStatusBar(visible: turns == 0);
    }
    if (turns == 0) return widget.child;
    final p = mq.padding;
    // 폰 위쪽(노치)이 화면의 왼쪽 또는 오른쪽으로 갑니다.
    final padding = turns == 1
        ? EdgeInsets.only(left: p.top, right: p.bottom)
        : EdgeInsets.only(left: p.bottom, right: p.top);
    return RotatedBox(
      quarterTurns: turns,
      child: MediaQuery(
        data: mq.copyWith(
          size: Size(mq.size.height, mq.size.width),
          padding: padding,
          viewPadding: padding,
        ),
        child: widget.child,
      ),
    );
  }
}
