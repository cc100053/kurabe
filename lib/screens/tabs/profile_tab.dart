import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late Future<Map<String, dynamic>> _statsFuture;
  bool _isUpdatingProfile = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchProfileStats();
  }

  Widget _buildAvatar(User? user) {
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initials = (user?.userMetadata?['name'] as String?)
            ?.trim()
            .split(RegExp(r'\s+'))
            .map((part) => part.isNotEmpty ? part.characters.first : '')
            .take(2)
            .join()
        ?? (user?.email?.isNotEmpty == true ? user!.email!.characters.first : 'ゲ');

    final avatar = avatarUrl != null
        ? ClipOval(
            child: Image.network(
              avatarUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackAvatar(initials),
            ),
          )
        : _fallbackAvatar(initials);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatar,
            if (!_supabaseService.isGuest)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _isUpdatingProfile ? null : _changeAvatar,
              ),
          ],
        ),
        if (_isUpdatingProfile)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _fallbackAvatar(String initials) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initials.isNotEmpty ? initials.toUpperCase() : 'ゲ',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildNameRow(User? user, bool isGuest, String emailText) {
    final displayName = isGuest
        ? 'ゲストユーザー'
        : (user?.userMetadata?['name'] as String?) ??
            emailText;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (!isGuest)
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: _isUpdatingProfile ? null : _changeName,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = _supabaseService.isGuest;
    final emailText = user?.email ?? 'ゲストユーザー';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('プロフィール'),
        backgroundColor: Colors.transparent, 
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar & Name
            _buildAvatar(user),
            const SizedBox(height: 16),
            _buildNameRow(user, isGuest, emailText),
            Text(
              emailText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final loading = snapshot.connectionState == ConnectionState.waiting;
                  final stats = snapshot.data ?? {};
                  final scans = stats['count'] as int? ?? 0;
                  final activeDays = stats['activeDays'] as int?;
                  final joinDate = stats['joinDate'] as DateTime?;
                  final level = _levelLabel(scans);
                  final activeDaysText = activeDays != null
                      ? '$activeDays 日'
                      : (joinDate != null
                          ? '参加日 ${_formatDate(joinDate)}'
                          : 'ー');
                  return Row(
                    children: [
                      _buildStatCard(
                        'スキャン',
                        loading ? null : '$scans',
                        Icons.qr_code_scanner,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'レベル',
                        loading ? null : level,
                        Icons.leaderboard_outlined,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        '活動日数',
                        loading ? null : activeDaysText,
                        Icons.calendar_today,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Settings Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (isGuest) ...[
                    _buildSettingsTile(
                      icon: Icons.login,
                      title: 'Googleで連携',
                      onTap: _isLoading ? null : () => _linkWithOAuth(OAuthProvider.google),
                      isDestructive: false,
                    ),
                    if (Platform.isIOS)
                      _buildSettingsTile(
                        icon: Icons.apple,
                        title: 'Appleで連携',
                        onTap: _isLoading ? null : () => _linkWithOAuth(OAuthProvider.apple),
                      ),
                    _buildSettingsTile(
                      icon: Icons.email_outlined,
                      title: 'メールで連携',
                      onTap: _isLoading ? null : _showEmailLinkDialog,
                    ),
                    const SizedBox(height: 20),
                    _buildSettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'ゲストデータを削除',
                      onTap: _isLoading ? null : _confirmGuestReset,
                      isDestructive: true,
                    ),
                  ] else ...[
                    _buildSettingsTile(
                      icon: Icons.logout,
                      title: 'ログアウト',
                      onTap: _isLoading ? null : _handleSignOut,
                      isDestructive: true,
                    ),
                  ],
                ],
              ),
            ),
            
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains('失敗') ? Colors.red : Colors.green,
                  ),
                ),
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String? value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            value == null
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive ? const Color(0xFFFFEBEE) : const Color(0xFFF0F9F8), // Light mint or red
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : Theme.of(context).colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      setState(() => _statusMessage = 'サインアウトしました。');
    } catch (e) {
      setState(() => _statusMessage = 'サインアウトに失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkWithOAuth(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(provider);
      if (!mounted) return;
      setState(
        () => _statusMessage = '連携用のブラウザを開きました。サインインを完了してください。',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '連携に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEmailLinkDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('メールで連携'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('連携する'),
            ),
          ],
        );
      },
    );

    if (shouldLink == true) {
      await _linkWithEmail(
        emailController.text.trim(),
        passwordController.text,
      );
    }
  }

  Future<void> _linkWithEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(
        () => _statusMessage = '確認メールを送信しました。受信箱を確認してください。',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'メール連携に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmGuestReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ゲストデータを削除しますか？'),
        content: const Text('ゲストの記録をすべて削除し、サインアウトします。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _resetGuestData();
    }
  }

  Future<void> _resetGuestData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('price_records')
            .delete()
            .eq('user_id', userId);
      }
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(() => _statusMessage = 'ゲストデータを削除しました。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '削除に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProfileStats() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final userCreatedRaw = client.auth.currentUser?.createdAt;
    if (userId == null) return {'count': 0, 'activeDays': 0, 'joinDate': null};

    try {
      final rows = await client
          .from('price_records')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final total = rows.length;

      DateTime? joinDate =
          userCreatedRaw != null ? DateTime.tryParse(userCreatedRaw)?.toLocal() : null;
      final createdAtList = rows
          .whereType<Map>()
          .map((e) => e['created_at']?.toString())
          .whereType<String>();
      for (final raw in createdAtList) {
        final dt = DateTime.tryParse(raw)?.toLocal();
        if (dt == null) continue;
        if (joinDate == null || dt.isBefore(joinDate)) {
          joinDate = dt;
        }
      }
      joinDate ??= DateTime.now();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(joinDate.year, joinDate.month, joinDate.day);
      final activeDays = today.difference(start).inDays + 1;

      return {
        'count': total,
        'activeDays': activeDays,
        'joinDate': joinDate,
      };
    } catch (e) {
      debugPrint('Failed to fetch profile stats: $e');
      return {
        'count': 0,
        'activeDays': 1,
        'joinDate': (userCreatedRaw != null
                ? DateTime.tryParse(userCreatedRaw)?.toLocal()
                : null) ??
            DateTime.now(),
      };
    }
  }

  String _levelLabel(int scans) {
    if (scans >= 50) return '達人';
    if (scans >= 10) return '熟練';
    return '見習';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _changeAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    const avatarBucket = 'avatars';
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;
    final originalBytes = await picked.readAsBytes();
    if (originalBytes.lengthInBytes > 15 * 1024 * 1024) {
      setState(() => _statusMessage = '画像サイズは15MB以内にしてください。');
      return;
    }
    final adjustedBytes = await _showAvatarAdjustDialog(originalBytes);
    if (adjustedBytes == null) return;
    setState(() {
      _isUpdatingProfile = true;
      _statusMessage = null;
    });
    try {
      final path = 'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}${picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '.jpg'}';
      await Supabase.instance.client.storage.from(avatarBucket).uploadBinary(
            path,
            adjustedBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final publicUrl = Supabase.instance.client.storage.from(avatarBucket).getPublicUrl(path);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );
      setState(() => _statusMessage = 'アバターを更新しました。');
    } catch (e) {
      setState(() => _statusMessage = 'アバター更新に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  Future<void> _changeName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final controller = TextEditingController(
      text: (user.userMetadata?['name'] as String?) ?? user.email ?? '',
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前を変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '表示名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) return;
    setState(() {
      _isUpdatingProfile = true;
      _statusMessage = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'name': newName}),
      );
      setState(() => _statusMessage = '名前を更新しました。');
    } catch (e) {
      setState(() => _statusMessage = '名前の更新に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfile = false);
      }
    }
  }

  Future<Uint8List?> _showAvatarAdjustDialog(Uint8List bytes) async {
    double scale = 1.0;
    Offset offset = Offset.zero;
    return showDialog<Uint8List>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('アバターを調整'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanUpdate: (details) =>
                        setState(() => offset += details.delta),
                    child: ClipOval(
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: Transform.translate(
                          offset: offset,
                          child: Transform.scale(
                            scale: scale,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('ズーム'),
                      Expanded(
                        child: Slider(
                          value: scale,
                          min: 1.0,
                          max: 3.0,
                          onChanged: (v) => setState(() => scale = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final cropped = await _cropCenteredSquare(bytes, scale, offset);
                    if (!mounted) return;
                    Navigator.of(context).pop(cropped);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _cropCenteredSquare(Uint8List bytes, double scale, Offset offset) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = image.width < image.height ? image.width : image.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final dstSize = size.toDouble();

    // Center crop with zoom (scale)
    canvas.translate(dstSize / 2 + offset.dx, dstSize / 2 + offset.dy);
    canvas.scale(scale);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
