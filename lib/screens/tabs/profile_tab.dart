import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = _supabaseService.isGuest;
    final emailText = user?.email ?? 'ゲストユーザー';
    final userId = user?.id ?? 'N/A';
    final status = _statusMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGuest ? 'ゲストユーザー' : 'ログイン中',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (!isGuest)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(emailText),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('ユーザーID: $userId'),
            ),
            if (isGuest)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Link your account to unlock community insights.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 20),
            if (isGuest) ...[
              Row(
                children: const [
                  Text(
                    '⚠️ Guest Mode: Link account to save data.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _linkWithOAuth(OAuthProvider.google),
                icon: const Icon(Icons.login),
                label: Text(_isLoading ? 'Working...' : 'Link with Google'),
              ),
              const SizedBox(height: 12),
              if (Platform.isIOS)
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _linkWithOAuth(OAuthProvider.apple),
                  icon: const Icon(Icons.apple),
                  label: Text(_isLoading ? 'Working...' : 'Link with Apple'),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _showEmailLinkDialog,
                icon: const Icon(Icons.email_outlined),
                label: Text(_isLoading ? 'Working...' : 'Link with Email'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _isLoading ? null : _confirmGuestReset,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset / Delete Guest Data'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('ログアウト'),
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 12),
              Text(status, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _linkWithOAuth(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(provider);
      setState(() => _statusMessage = 'Account linked with ${provider.name}.');
    } catch (e) {
      setState(() => _statusMessage = 'OAuth linking failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEmailLinkDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final creds = await showDialog<(String, String)>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Link with Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (email.isEmpty || password.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, (email, password));
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (creds == null) return;
    await _linkWithEmail(creds.$1.trim(), creds.$2);
  }

  Future<void> _confirmGuestReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest data?'),
          content: const Text('Data will be lost forever. Proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await _handleSignOut();
  }

  Future<void> _linkWithEmail(String email, String password) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account linked! Please verify your email.'),
        ),
      );
      setState(() => _statusMessage = 'Email linking started.');
      return;
    } on AuthException catch (e) {
      final alreadyRegistered = e.message.toLowerCase().contains('already');
      if (!alreadyRegistered) {
        setState(() => _statusMessage = 'Email linking failed: ${e.message}');
        return;
      }
      final confirmMerge = await _promptMergeExisting(password: password);
      if (confirmMerge != true) {
        setState(() => _statusMessage = 'Linking cancelled.');
        return;
      }
      await _mergeGuestDataIntoExistingAccount(email, password);
    } catch (e) {
      setState(() => _statusMessage = 'Email linking failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _promptMergeExisting({required String password}) {
    final passwordController = TextEditingController(text: password);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Account exists'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This email is already registered. Log in to merge data?'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  Navigator.pop(context, false);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Merge & Login'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mergeGuestDataIntoExistingAccount(
    String email,
    String password,
  ) async {
    final guestId = Supabase.instance.client.auth.currentUser?.id;
    List<int> guestRecordIds = [];
    if (guestId != null) {
      try {
        final result = await Supabase.instance.client
            .from('price_records')
            .select('id')
            .eq('user_id', guestId);
        guestRecordIds = result
            .whereType<Map>()
            .map((e) => (e['id'] as num).toInt())
            .toList();
      } catch (_) {
        // ignore and continue
      }
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (guestRecordIds.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'transfer_guest_data',
          params: {'record_ids': guestRecordIds},
        );
      }
      if (!mounted) return;
      setState(() => _statusMessage = 'Logged in & Data Merged!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in & Data Merged!')),
      );
    } on AuthException catch (e) {
      setState(() => _statusMessage = 'Login failed: ${e.message}');
    } catch (e) {
      setState(() => _statusMessage = 'Merge failed: $e');
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      setState(() => _statusMessage = 'Signed out.');
    } catch (e) {
      setState(() => _statusMessage = 'Sign out failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
