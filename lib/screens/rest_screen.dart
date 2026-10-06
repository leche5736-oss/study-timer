import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'thoughts_list.dart';

/// 휴식 화면. 밝은 톤으로 남은 시간과 숨쉬기 원을 보여 줍니다.
/// 음악을 듣는 등 다른 앱을 써도 괜찮고, 끝나면 알림으로 알려 드립니다.
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
    final store = widget.store;
    final t = store.timer;
    final restType = RestType.byName(store.session(t.lastSessionId)?.restType);
    const grey = TextStyle(color: AppColors.grey, fontSize: 15);

    return Scaffold(
      backgroundColor: AppColors.restBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.longRest ? '긴 휴식' : '휴식', style: grey),
                  Text(
                    formatClock(t.remainingSec(store.now)),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Breath(animation: _breath),
                  const SizedBox(height: 32),
                  const Text('휴식 중 한 일', style: grey),
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
                          backgroundColor: Colors.white,
                          onSelected: (_) => store.setRestType(type),
                        ),
                    ],
                  ),
                  if (store.thoughts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ThoughtsList(store: store),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.grey,
                    ),
                    onPressed: store.skipRest,
                    child: const Text('휴식 건너뛰기'),
                  ),
                ],
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
                  color: AppColors.soft,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inhale ? '들이쉬기' : '내쉬기',
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      );
    },
  );
}
