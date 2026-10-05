import 'dart:async';

import 'package:flutter/material.dart';

import '../services/store.dart';
import '../stats.dart';

/// 집중 중 화면. 어두운 배경에 시간만 보이고, 화면을 누르거나 마우스를 움직이면
/// 잠깐 동안 버튼과 딴생각 메모 칸이 나타났다가 다시 숨습니다.
class FocusScreen extends StatefulWidget {
  final AppStore store;

  /// 미니 타이머로 바꾸기. 지원하지 않는 기기면 null.
  final VoidCallback? onMini;
  const FocusScreen({super.key, required this.store, this.onMini});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _dim = Color(0xFF8A8F98);
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
    const small = TextStyle(color: _dim, fontSize: 12);
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: _dim,
      side: const BorderSide(color: Color(0xFF2A2F37)),
    );

    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${t.stopwatch ? '스톱워치' : '집중 중'} · ${subject?.name ?? ''}'
          '${t.isRunning ? '' : ' · 일시정지됨'}',
          style: const TextStyle(color: _dim),
        ),
        if (t.distractions > 0) ...[
          const SizedBox(height: 4),
          Text(
            '이번 블록 딴짓 ${t.distractions}회'
            '${t.distractedSec > 0 ? ' · ${formatDuration(t.distractedSec)}' : ''}',
            style: small.copyWith(color: const Color(0xFFB85C5C)),
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              style: buttonStyle,
              onPressed: t.isRunning ? store.pause : store.resume,
              icon: Icon(t.isRunning ? Icons.pause : Icons.play_arrow),
              label: Text(t.isRunning ? '일시정지' : '계속'),
            ),
            OutlinedButton.icon(
              style: buttonStyle,
              onPressed: store.finishFocus,
              icon: const Icon(Icons.flag),
              label: Text(t.stopwatch ? '끝내기' : '지금 끝내기'),
            ),
            if (widget.onMini != null)
              OutlinedButton.icon(
                style: buttonStyle,
                onPressed: widget.onMini,
                icon: const Icon(Icons.picture_in_picture_alt),
                label: const Text('미니 타이머'),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _dim),
              onPressed: () => _confirmCancel(context),
              child: const Text('취소 (기록 안 함)'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _thought,
          focusNode: _thoughtFocus,
          style: const TextStyle(color: _dim),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addThought(),
          onChanged: (_) => _scheduleHide(),
          decoration: InputDecoration(
            labelText: '딴생각 메모',
            labelStyle: const TextStyle(color: _dim),
            hintText: '떠오른 할 일·걱정을 한 줄 적고 Enter',
            hintStyle: const TextStyle(color: Color(0xFF555A62)),
            helperText: thoughtsThisBlock == 0
                ? '적어 두면 휴식 때 다시 보여 드려요.'
                : '이번 블록 $thoughtsThisBlock개 적음 · 휴식 때 보여 드려요',
            helperStyle: small,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2A2F37)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _dim),
            ),
            suffixIcon: IconButton(
              tooltip: '메모 저장',
              color: _dim,
              icon: const Icon(Icons.add),
              onPressed: _addThought,
            ),
          ),
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
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatClock(shownSec),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: _dim,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: controls,
                        ),
                      ),
                      if (!visible) const Text('화면을 누르면 버튼이 나와요', style: small),
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
