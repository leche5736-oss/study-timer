import 'dart:async';

import 'package:flutter/material.dart';

import '../services/head_motion.dart';
import '../theme.dart';

/// 에어팟이 고개 각도를 제대로 보내는지 확인하는 화면 (자세 알림 1단계).
class HeadTestScreen extends StatefulWidget {
  const HeadTestScreen({super.key});

  @override
  State<HeadTestScreen> createState() => _HeadTestScreenState();
}

class _HeadTestScreenState extends State<HeadTestScreen> {
  StreamSubscription<HeadPose>? _poseSub;
  StreamSubscription<String>? _statusSub;
  String _state = '시작하는 중';
  HeadPose? _pose;
  double? _base;

  @override
  void initState() {
    super.initState();
    _poseSub = HeadMotion.poses.listen((p) {
      if (mounted) setState(() => _pose = p);
    });
    _statusSub = HeadMotion.status.listen((s) {
      if (!mounted) return;
      setState(() {
        _state = switch (s) {
          'connected' => '에어팟 연결됨',
          'disconnected' => '에어팟이 빠졌어요',
          _ => s,
        };
      });
    });
    HeadMotion.start().then((r) {
      if (!mounted) return;
      setState(() {
        _state = switch (r) {
          'started' => '에어팟을 끼면 숫자가 나와요',
          'denied' =>
            '권한이 꺼져 있어요. 시스템 설정 → 개인정보 보호 및 보안 → '
                '동작 및 피트니스에서 이 앱을 켜 주세요.',
          'unavailable' => '이 Mac에서는 에어팟 머리 움직임을 읽을 수 없어요',
          _ => 'macOS 14 이상 Mac 앱에서만 돼요',
        };
      });
    });
  }

  @override
  void dispose() {
    _poseSub?.cancel();
    _statusSub?.cancel();
    HeadMotion.stop();
    super.dispose();
  }

  String _deg(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}°';

  @override
  Widget build(BuildContext context) {
    final p = _pose;
    final text = Theme.of(context).textTheme;
    final big = p == null ? '–' : _deg(p.pitch - (_base ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('에어팟 고개 각도 (테스트)')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '에어팟을 끼고 고개를 천천히 숙였다 들어 보세요. '
            '큰 숫자가 따라 움직이면 성공이에요.',
            style: text.bodyMedium?.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              big,
              style: text.displayLarge?.copyWith(
                color: AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Center(
            child: Text(
              _base == null ? '앞뒤 기울기' : '기준 자세보다 앞뒤로',
              style: text.bodySmall?.copyWith(color: AppColors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton(
              onPressed: p == null
                  ? null
                  : () => setState(() => _base = p.pitch),
              child: const Text('지금 자세를 기준으로'),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(title: const Text('상태'), subtitle: Text(_state)),
          if (p != null) ...[
            ListTile(title: const Text('좌우 갸웃'), trailing: Text(_deg(p.roll))),
            ListTile(
              title: const Text('보내는 쪽'),
              trailing: Text(switch (p.bud) {
                'left' => '왼쪽',
                'right' => '오른쪽',
                _ => '-',
              }),
            ),
            ListTile(
              title: const Text('원래 값'),
              subtitle: Text(
                'pitch ${p.pitch.toStringAsFixed(1)} · '
                'roll ${p.roll.toStringAsFixed(1)} · '
                'yaw ${p.yaw.toStringAsFixed(1)}\n'
                '중력 ${p.gravity.map((g) => g.toStringAsFixed(2)).join(', ')}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
