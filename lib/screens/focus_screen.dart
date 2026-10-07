import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../stats.dart';
import '../theme.dart';
import 'space_key.dart';
import 'subject_picker.dart';

/// 집중 중 화면. 어두운 배경에 시간만 보이고, 화면을 누르거나 클릭하면
/// 잠깐 동안 버튼과 딴생각 메모 칸이 나타났다가 다시 숨습니다.
class FocusScreen extends StatefulWidget {
  final AppStore store;

  /// 미니 타이머로 바꾸기. 지원하지 않는 기기면 null.
  final VoidCallback? onMini;
  const FocusScreen({super.key, required this.store, this.onMini});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with SpaceKeyShortcut {
  /// 스페이스 키 = 일시정지/계속
  @override
  void onSpace() {
    if (store.timer.phase != Phase.focus) return;
    store.timer.isRunning ? store.pause() : store.resume();
  }

  static Color get _dim => AppColors.dim;
  static const _hideAfter = Duration(seconds: 4);

  final _thought = TextEditingController();
  final _thoughtFocus = FocusNode();
  bool _shown = false;
  Timer? _hideTimer;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _thoughtFocus.addListener(_scheduleHide);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _thought.dispose();
    _thoughtFocus.dispose();
    super.dispose();
  }

  /// 조작 버튼을 보여 주고, 잠시 뒤 다시 숨깁니다.
  void _reveal() {
    if (!_shown) setState(() => _shown = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      // 메모를 쓰는 중이면 숨기지 않습니다.
      if (!mounted || _thoughtFocus.hasFocus) return;
      setState(() => _shown = false);
    });
  }

  Future<void> _switchSubject() async {
    _hideTimer?.cancel();
    final id = await pickSubject(
      context,
      store.subjects,
      title: '과목 바꾸기 (시간은 이어서 흘러요)',
      markId: store.timer.subjectId,
      markLabel: '지금',
    );
    if (id != null && mounted) store.switchSubject(id);
    if (mounted) _scheduleHide();
  }

  void _addThought() {
    store.addThought(_thought.text);
    _thought.clear();
    _thoughtFocus.unfocus();
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final t = store.timer;
    final now = store.now;
    final subject = store.subject(t.subjectId);
    final shownSec = t.stopwatch ? t.elapsedSec(now) : t.remainingSec(now);
    // 일시정지 중에는 계속 보여 줍니다.
    final visible = _shown || !t.isRunning;
    final since = t.sessionStartedAt;
    final thoughtsThisBlock = since == null
        ? 0
        : store.thoughts.where((n) => !n.createdAt.isBefore(since)).length;
    final small = TextStyle(color: _dim, fontSize: 13);
    final link = TextButton.styleFrom(foregroundColor: _dim);

    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 과목 이름을 누르면 블록을 이어 가면서 과목만 바꿉니다.
        TextButton(
          key: const Key('focus-subject'),
          style: link,
          onPressed: store.subjects.length > 1 ? _switchSubject : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [
                  subject?.name ?? '',
                  if (!t.isRunning) '일시정지',
                  if (t.distractions > 0) '딴짓 ${t.distractions}회',
                ].join(' · '),
                style: TextStyle(color: _dim, fontSize: 15),
              ),
              if (store.subjects.length > 1)
                Icon(Icons.expand_more, size: 18, color: AppColors.nightFaint),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              label: t.isRunning ? '일시정지' : '계속',
              onTap: t.isRunning ? store.pause : store.resume,
            ),
            const SizedBox(width: 32),
            _RoundButton(label: '끝내기', onTap: store.finishFocus),
          ],
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _thought,
          focusNode: _thoughtFocus,
          style: TextStyle(color: AppColors.dim),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addThought(),
          onChanged: (_) => _scheduleHide(),
          decoration: InputDecoration(
            hintText: thoughtsThisBlock == 0
                ? '딴생각 메모 (적고 Enter, 휴식 때 보여 드려요)'
                : '딴생각 메모 · 이번 블록 $thoughtsThisBlock개',
            hintStyle: TextStyle(color: AppColors.nightFaint),
            fillColor: AppColors.nightRaised,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onMini != null)
              TextButton(
                style: link,
                onPressed: widget.onMini,
                child: const Text('미니 타이머'),
              ),
            TextButton(
              style: link,
              onPressed: () => _confirmCancel(context),
              child: const Text('취소 (기록 안 함)'),
            ),
          ],
        ),
      ],
    );

    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height && size.height < 520;
    Widget clock(double fontSize) => Text(
      formatClock(shownSec),
      style: TextStyle(
        color: _dim,
        fontSize: fontSize,
        fontWeight: FontWeight.w200,
        letterSpacing: -2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // 가로 화면(폰을 눕힘): 평소엔 큰 시간만, 누르면 시간 옆에 버튼이 나옵니다.
    final Widget content = landscape
        ? (visible
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    clock(96),
                    const SizedBox(width: 48),
                    SizedBox(width: 340, child: controls),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    clock(140),
                    Text('화면을 누르면 버튼이 나와요', style: small),
                  ],
                ))
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                clock(96),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(ignoring: !visible, child: controls),
                ),
                if (!visible) Text('화면을 누르면 버튼이 나와요', style: small),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _reveal,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이 블록을 기록하지 않고 취소할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (ok == true) store.cancel();
  }
}

/// 어두운 화면의 동그란 버튼 (Apple 시계 앱 타이머 버튼 모양).
class _RoundButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RoundButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.nightRaised,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: AppColors.dim, fontSize: 15),
          ),
        ),
      ),
    ),
  );
}
