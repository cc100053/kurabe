import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  String? _error;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kurabe',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'コミュニティと価格を比べよう。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildButton(
                label: 'ゲストとして続行',
                onPressed: _isLoading ? null : _continueAsGuest,
              ),
              const SizedBox(height: 12),
              _buildButton(
                label: 'Googleでログイン',
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              _buildButton(
                label: 'メールでログイン',
                onPressed: _isLoading ? null : _loginWithEmail,
              ),
              const SizedBox(height: 12),
              _buildButton(
                label: 'メールで登録',
                onPressed: _isLoading ? null : _signUpWithEmail,
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildButton(
                  label: 'Appleでログイン',
                  onPressed: _isLoading ? null : _signInWithApple,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: const TextStyle(color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    await _runAuthAction(() async {
      await Supabase.instance.client.auth.signInAnonymously();
      return 'ゲストとしてログインしました。';
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(() async {
      await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
      return null;
    });
  }

  Future<void> _signInWithApple() async {
    await _runAuthAction(() async {
      await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.apple);
      return null;
    });
  }

  Future<void> _signUpWithEmail() async {
    final creds = await _promptForEmailPassword(
      title: 'メールで登録',
      actionText: '登録',
    );
    if (creds == null) return;
    await _runAuthAction(() async {
      final response = await Supabase.instance.client.auth.signUp(
        email: creds.$1.trim(),
        password: creds.$2,
      );
      if (response.session != null) {
        return 'ログインしました。';
      }
      return '確認メールを送信しました。メールを確認してください。';
    });
  }

  Future<void> _loginWithEmail() async {
    final creds = await _promptForEmailPassword(
      title: 'メールでログイン',
      actionText: 'ログイン',
    );
    if (creds == null) return;
    await _runAuthAction(() async {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: creds.$1.trim(),
        password: creds.$2,
      );
      if (response.session != null) {
        return 'ログインしました。';
      }
      return 'ログインに失敗しました。';
    });
  }

  Future<(String, String)?> _promptForEmailPassword({
    required String title,
    required String actionText,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    return showDialog<(String, String)?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (email.isEmpty || password.isEmpty) {
                  Navigator.pop(context, null);
                  return;
                }
                Navigator.pop(context, (email, password));
              },
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAuthAction(Future<String?> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final msg = await action();
      if (mounted && msg != null) {
        setState(() => _message = msg);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
