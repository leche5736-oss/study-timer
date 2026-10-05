import 'package:flutter/material.dart';

import '../services/store.dart';
import '../stats.dart';

/// 조용한 휴식 모드. 휴식 중 뇌는 방금 배운 것을 되풀이(replay)하며
/// 기억을 굳히므로, 화면을 어둡게 하고 호흡 안내만 보여줍니다.
class RestScreen extends StatefulWidget {
  final AppStore store;
  const RestScreen({super.key, required this.store});

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen>
    with SingleTickerProviderStateMixin {
  // 4초 들이쉬고 6초 내쉬기.
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.store.timer;
    const dim = Color(0xFF8A8F98);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.longRest ? '긴 휴식' : '조용한 휴식',
                style: const TextStyle(color: dim, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                formatClock(t.remainingSec(widget.store.now)),
                style: const TextStyle(color: dim, fontSize: 40),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  final v = _breath.value;
                  final inhale = v < 0.4;
                  final size = inhale
                      ? 80 + 120 * Curves.easeInOut.transform(v / 0.4)
                      : 200 - 120 * Curves.easeInOut.transform((v - 0.4) / 0.6);
                  return Column(
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E3A5F),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        inhale ? '들이쉬기' : '내쉬기',
                        style: const TextStyle(color: dim, fontSize: 16),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '눈을 감고 조용히 쉬세요.\n휴대폰, 영상, SNS는 잠시 멀리 두는 게 기억에 좋아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dim),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: widget.store.skipRest,
                child: const Text('휴식 건너뛰기', style: TextStyle(color: dim)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
