import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store.dart';
import '../services/sync_config.dart';

/// 동기화가 켜져 있을 때만 보이는 로그인 화면. 모든 기기에서 같은 계정으로 로그인하세요.
class LoginScreen extends StatefulWidget {
  final AppStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function(GoTrueClient auth) action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(Supabase.instance.client.auth);
    } on AuthException catch (e) {
      setState(() => _message = e.message);
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text('여러 기기에서 같은 기록을 보려면 같은 계정으로 로그인하세요.'),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        (auth) => auth.signInWithPassword(
                          email: _email.text.trim(),
                          password: _password.text,
                        ),
                      ),
                child: const Text('로그인'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run((auth) async {
                        final res = await auth.signUp(
                          email: _email.text.trim(),
                          password: _password.text,
                        );
                        if (res.session == null && mounted) {
                          setState(
                            () => _message =
                                '가입 확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인하세요.',
                          );
                        }
                      }),
                child: const Text('처음이면 회원가입'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => SyncConfig.disconnect(widget.store.prefs),
                child: const Text('동기화 끄고 이 기기에서만 쓰기'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
