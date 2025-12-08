import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = _supabaseService.isGuest;
    final emailText = user?.email ?? 'ゲストユーザー';

    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: CustomScrollView(
        slivers: [
          // Premium header with gradient
          SliverToBoxAdapter(
            child: _buildHeader(user, isGuest, emailText),
          ),

          // Stats section
          SliverToBoxAdapter(
            child: _buildStatsSection(),
          ),

          // Settings menu
          SliverToBoxAdapter(
            child: _buildSettingsSection(isGuest),
          ),

          // Status message
          if (_statusMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusMessage!.contains('失敗')
                        ? KurabeColors.error.withAlpha(26)
                        : KurabeColors.success.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusMessage!.contains('失敗')
                          ? KurabeColors.error.withAlpha(77)
                          : KurabeColors.success.withAlpha(77),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage!.contains('失敗')
                            ? PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)
                            : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: _statusMessage!.contains('失敗')
                            ? KurabeColors.error
                            : KurabeColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusMessage!.contains('失敗')
                                ? KurabeColors.error
                                : KurabeColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader(User? user, bool isGuest, String emailText) {
    final displayName = isGuest
        ? 'ゲストユーザー'
        : (user?.userMetadata?['name'] as String?) ?? emailText;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KurabeColors.primary,
            KurabeColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            children: [
              // Avatar section
              _buildAvatar(user),
              const SizedBox(height: 20),

              // Name with edit button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isGuest) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isUpdatingProfile ? null : _changeName,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Email
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  emailText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User? user) {
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initials = (user?.userMetadata?['name'] as String?)
            ?.trim()
            .split(RegExp(r'\s+'))
            .map((part) => part.isNotEmpty ? part.characters.first : '')
            .take(2)
            .join() ??
        (user?.email?.isNotEmpty == true
            ? user!.email!.characters.first.toUpperCase()
            : 'ゲ');

    return Column(
      children: [
        GestureDetector(
          onTap: !_supabaseService.isGuest && !_isUpdatingProfile
              ? _changeAvatar
              : null,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Avatar ring
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(102),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _fallbackAvatar(initials),
                          )
                        : _fallbackAvatar(initials),
                  ),
                ),
              ),

              // Edit badge
              if (!_supabaseService.isGuest)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    PhosphorIcons.camera(PhosphorIconsStyle.fill),
                    size: 18,
                    color: KurabeColors.primary,
                  ),
                ),
            ],
          ),
        ),
        if (_isUpdatingProfile)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withAlpha(179),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(51),
            Colors.white.withAlpha(26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials.toUpperCase() : 'ゲ',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Transform.translate(
      offset: const Offset(0, 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final stats = snapshot.data ?? {};
              final scans = stats['count'] as int? ?? 0;
              final activeDays = stats['activeDays'] as int?;
              final joinDate = stats['joinDate'] as DateTime?;
              final level = _levelLabel(scans);
              final activeDaysText = activeDays != null
                  ? '$activeDays'
                  : (joinDate != null ? '1' : '-');

              return Row(
                children: [
                  _buildStatItem(
                    icon: PhosphorIcons.scan(PhosphorIconsStyle.fill),
                    value: loading ? null : '$scans',
                    label: 'スキャン',
                    color: KurabeColors.primary,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    icon: PhosphorIcons.medal(PhosphorIconsStyle.fill),
                    value: loading ? null : level,
                    label: 'レベル',
                    color: KurabeColors.accent,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    icon: PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill),
                    value: loading ? null : activeDaysText,
                    label: '活動日数',
                    color: KurabeColors.success,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String? value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          value == null
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KurabeColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KurabeColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 60,
      color: KurabeColors.divider,
    );
  }

  Widget _buildSettingsSection(bool isGuest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'アカウント',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KurabeColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Settings tiles
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                if (isGuest) ...[
                  _buildSettingsTile(
                    icon: PhosphorIcons.googleLogo(PhosphorIconsStyle.fill),
                    title: 'Googleで連携',
                    subtitle: 'データを安全に保存',
                    onTap: _isLoading
                        ? null
                        : () => _linkWithOAuth(OAuthProvider.google),
                    iconColor: const Color(0xFFDB4437),
                  ),
                  _buildTileDivider(),
                  if (Platform.isIOS) ...[
                    _buildSettingsTile(
                      icon: PhosphorIcons.appleLogo(PhosphorIconsStyle.fill),
                      title: 'Appleで連携',
                      subtitle: 'Face IDで簡単ログイン',
                      onTap: _isLoading
                          ? null
                          : () => _linkWithOAuth(OAuthProvider.apple),
                      iconColor: Colors.black,
                    ),
                    _buildTileDivider(),
                  ],
                  _buildSettingsTile(
                    icon: PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                    title: 'メールで連携',
                    subtitle: 'メールアドレスで登録',
                    onTap: _isLoading ? null : _showEmailLinkDialog,
                    iconColor: KurabeColors.primary,
                  ),
                ] else ...[
                  _buildSettingsTile(
                    icon: PhosphorIcons.signOut(PhosphorIconsStyle.fill),
                    title: 'ログアウト',
                    subtitle: 'アカウントからサインアウト',
                    onTap: _isLoading ? null : _confirmSignOut,
                    iconColor: KurabeColors.error,
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),

          // Destructive actions for guests
          if (isGuest) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'データ管理',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KurabeColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: KurabeColors.error.withAlpha(51),
                ),
              ),
              child: _buildSettingsTile(
                icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
                title: 'ゲストデータを削除',
                subtitle: 'すべての記録を消去します',
                onTap: _isLoading ? null : _confirmGuestReset,
                iconColor: KurabeColors.error,
                isDestructive: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? KurabeColors.error
                            : KurabeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KurabeColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                color: KurabeColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 62),
      child: Container(
        height: 1,
        color: KurabeColors.divider,
      ),
    );
  }

  // ========== Logic Methods (unchanged) ==========

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        content: const Text('サインアウトしても保存済みの記録は残ります。再度利用するにはログインが必要です。'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KurabeColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('ログアウト'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _handleSignOut();
    }
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
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
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
              backgroundColor: KurabeColors.error,
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
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(() => _statusMessage = 'ゲストとしてサインアウトしました。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'サインアウトに失敗しました: $e');
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

      DateTime? joinDate = userCreatedRaw != null
          ? DateTime.tryParse(userCreatedRaw)?.toLocal()
          : null;
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

  Future<void> _changeAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    const avatarBucket = 'avatars';
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
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
      final path =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}${picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '.jpg'}';
      await Supabase.instance.client.storage.from(avatarBucket).uploadBinary(
            path,
            adjustedBytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final publicUrl = Supabase.instance.client.storage
          .from(avatarBucket)
          .getPublicUrl(path);
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
                    final cropped =
                        await _cropCenteredSquare(bytes, scale, offset);
                    if (!context.mounted) return;
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

  Future<Uint8List> _cropCenteredSquare(
      Uint8List bytes, double scale, Offset offset) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = image.width < image.height ? image.width : image.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final dstSize = size.toDouble();

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
