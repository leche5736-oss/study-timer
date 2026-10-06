/// iPhone을 엎어 두고 공부하는지 판단합니다 (가속도 센서의 z 값).
/// 화면이 바닥을 보고 있으면 z가 약 -9.8, 위를 보면 약 +9.8입니다.
///
/// 1. 엎어 둔 채 [armAfter] 지나면 감시 시작
/// 2. 그 뒤 [awayAfter] 넘게 엎어 두지 않으면 딴짓 시작 (들어 올린 순간부터 셈)
///    잠깐 들었다 놓거나, 끝내려고 집은 것은 세지 않습니다.
/// 3. 다른 앱으로 넘어가면 바로 딴짓 시작
/// 4. 다시 엎어 두면 [backAfter] 뒤 딴짓 끝
class FlipDetector {
  static const downZ = -7.0;
  static const armAfter = Duration(seconds: 2);
  static const awayAfter = Duration(seconds: 10);
  static const backAfter = Duration(seconds: 1);

  bool armed = false;
  bool away = false;
  DateTime? _downSince;
  DateTime? _upSince;

  /// 센서 값 하나. 딴짓이 시작되거나 끝나면 그 사건을 돌려줍니다.
  FlipEvent? sample(double z, DateTime t) {
    if (z < downZ) {
      _upSince = null;
      _downSince ??= t;
      final down = t.difference(_downSince!);
      if (!armed && down >= armAfter) armed = true;
      if (away && down >= backAfter) {
        away = false;
        return FlipEvent(false, t);
      }
      return null;
    }
    _downSince = null;
    if (!armed) return null;
    _upSince ??= t;
    if (!away && t.difference(_upSince!) >= awayAfter) {
      away = true;
      return FlipEvent(true, _upSince!);
    }
    return null;
  }

  /// 앱이 뒤로 갔을 때 (다른 앱을 켬).
  FlipEvent? appHidden(DateTime t) {
    if (!armed || away) return null;
    away = true;
    return FlipEvent(true, _upSince ?? t);
  }

  void reset() {
    armed = false;
    away = false;
    _downSince = null;
    _upSince = null;
  }
}

class FlipEvent {
  /// true면 딴짓 시작, false면 끝.
  final bool away;
  final DateTime at;
  const FlipEvent(this.away, this.at);
}
