import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'thoughts_list.dart';

/// 조용한 휴식 모드. 휴식 중 뇌는 방금 배운 것을 되풀이(replay)하며
/// 기억을 굳히므로, 화면을 어둡게 하고 남은 시간과 호흡 안내만 보여줍니다.
/// 화면을 누르면 휴식 중 한 일, 딴생각 메모, 건너뛰기가 잠깐 나타납니다.
class RestScreen extends StatefulWidget {
  final AppStore store;
  const RestScreen({super.key, required this.store});

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen>
    with SingleTickerProviderStateMixin {
  static const _dim = AppColors.dim;

  // 4초 들이쉬고 6초 내쉬기.
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  bool _shown = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _reveal() {
    if (!_shown) setState(() => _shown = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final t = store.timer;
    final restType = RestType.byName(store.session(t.lastSessionId)?.restType);
    const small = TextStyle(color: _dim, fontSize: 13);

    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('휴식 중 한 일', style: small),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final type in RestType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: restType == type,
                onSelected: (_) {
                  store.setRestType(type);
                  _reveal();
                },
                backgroundColor: const Color(0xFF1C1C1E),
                selectedColor: const Color(0xFF3A3A3C),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
        if (store.thoughts.isNotEmpty) ...[
          const SizedBox(height: 24),
          ThoughtsList(store: store, textColor: _dim),
        ],
        const SizedBox(height: 16),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: _dim),
          onPressed: store.skipRest,
          child: const Text('휴식 건너뛰기'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _reveal(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _reveal,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.longRest ? '긴 휴식' : '휴식',
                        style: const TextStyle(color: _dim, fontSize: 15),
                      ),
                      Text(
                        formatClock(t.remainingSec(store.now)),
                        style: const TextStyle(
                          color: _dim,
                          fontSize: 64,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Breath(animation: _breath),
                      const SizedBox(height: 24),
                      AnimatedOpacity(
                        opacity: _shown ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !_shown,
                          child: controls,
                        ),
                      ),
                      if (!_shown)
                        const Text('눈을 감고 쉬세요. 화면을 누르면 메뉴가 나와요', style: small),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 커졌다 작아지는 원과 들이쉬기/내쉬기 글자.
class _Breath extends StatelessWidget {
  final Animation<double> animation;
  const _Breath({required this.animation});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final v = animation.value;
      final inhale = v < 0.4;
      final size = inhale
          ? 60 + 100 * Curves.easeInOut.transform(v / 0.4)
          : 160 - 100 * Curves.easeInOut.transform((v - 0.4) / 0.6);
      return Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inhale ? '들이쉬기' : '내쉬기',
            style: const TextStyle(color: AppColors.dim, fontSize: 13),
          ),
        ],
      );
    },
  );
}
