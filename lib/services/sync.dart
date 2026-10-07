import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'store.dart';

/// Supabase와 기록을 주고받습니다. config.dart가 채워져 있을 때만 쓰입니다.
///
/// 방식: 바뀐 것은 바로 올리고(upsert), 다른 기기에서 바뀐 것은
/// 실시간(Realtime) 알림을 받아 내려받습니다. 같은 항목이 양쪽에서 바뀌면
/// 나중에 바뀐 쪽이 이깁니다.
class SyncService {
  final AppStore store;
  final SupabaseClient client;
  RealtimeChannel? _channel;
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  bool _pushing = false;
  bool _pendingPush = false;
  // 이 시각 이후에 바뀐 항목만 올립니다. 앱을 켠 뒤 첫 업로드는 전부 올립니다.
  DateTime _pushedUpTo = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// 화면에 보여줄 마지막 오류.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  SyncService(this.store, this.client);

  Future<void> start() async {
    store.onLocalChange = _schedulePush;
    await pull();
    await push();
    // 폰에서 앱이 뒤에 숨어 있는 동안은 실시간 알림을 못 받으니, 다시 열면 바로 받아 옵니다.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(pull()));
    _channel = client
        .channel('study-sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subjects',
          callback: (_) => pull(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sessions',
          callback: (_) => pull(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'timer_state',
          callback: (_) => pull(),
        )
        .subscribe();
  }

  Future<void> stop() async {
    store.onLocalChange = null;
    _debounce?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    if (_channel != null) await client.removeChannel(_channel!);
    _channel = null;
  }

  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), push);
  }

  String get _uid => client.auth.currentUser!.id;

  Future<void> push() async {
    if (_pushing) {
      _pendingPush = true;
      return;
    }
    _pushing = true;
    try {
      final uid = _uid;
      final since = _pushedUpTo;
      final startedAt = DateTime.now().toUtc();
      final subjects = store.allSubjects
          .where((s) => !s.updatedAt.isBefore(since))
          .map((s) => {...s.toJson(), 'user_id': uid})
          .toList();
      final sessions = store.allSessions
          .where((s) => !s.updatedAt.isBefore(since))
          .map((s) => {...s.toJson(), 'user_id': uid})
          .toList();
      if (subjects.isNotEmpty) await client.from('subjects').upsert(subjects);
      if (sessions.isNotEmpty) await client.from('sessions').upsert(sessions);
      await client.from('timer_state').upsert({
        'user_id': uid,
        'data': store.timer.toJson(),
        'updated_at': store.timer.updatedAt.toIso8601String(),
      });
      _pushedUpTo = startedAt.subtract(const Duration(seconds: 1));
      lastError.value = null;
    } catch (e) {
      lastError.value = '동기화 실패: $e';
      debugPrint(lastError.value);
    } finally {
      _pushing = false;
      if (_pendingPush) {
        _pendingPush = false;
        unawaited(push());
      }
    }
  }

  Future<void> pull() async {
    try {
      final subjects = await client.from('subjects').select();
      final sessions = await client.from('sessions').select();
      final timer = await client
          .from('timer_state')
          .select()
          .eq('user_id', _uid)
          .maybeSingle();
      store.mergeRemote(
        subjects: subjects.map(Subject.fromJson),
        sessions: sessions.map(StudySession.fromJson),
        timer: timer == null
            ? null
            : TimerState.fromJson(timer['data'] as Map<String, dynamic>),
      );
      lastError.value = null;
    } catch (e) {
      lastError.value = '동기화 실패: $e';
      debugPrint(lastError.value);
    }
  }
}
