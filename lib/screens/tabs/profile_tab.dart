import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/price_repository.dart';
import '../../main.dart';
import '../../constants/auth.dart';
import '../../services/auth_error_mapper.dart';
import '../../services/apple_sign_in_service.dart';
import '../../widgets/app_snackbar.dart';
import '../paywall_screen.dart';
import '../../providers/subscription_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends ConsumerState<ProfileTab> {
  final PriceRepository _priceRepository = PriceRepository();
  StreamSubscription<AuthState>? _authStateSub;
  OAuthProvider? _lastProvider;
  List<Map<String, dynamic>>? _pendingGuestRecords;
  List<Map<String, dynamic>>? _pendingGuestShoppingItems;
  bool _isLoading = false;
  late Future<Map<String, dynamic>> _statsFuture;
  bool _isUpdatingProfile = false;
  bool _handledLinkError = false;

  /// Converts auth exceptions to user-friendly Japanese messages
  String _friendlyErrorMessage(dynamic error) {
    return AuthErrorMapper.message(error);
  }

  /// Shows a floating SnackBar with the given message
  void _showStatusSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    AppSnackbar.show(context, message, isError: isError);
  }

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchProfileStats();
    _listenAuthErrors();
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  Future<bool?> _showIdentityExistsDialog(OAuthProvider provider) {
    final providerLabel = provider == OAuthProvider.google ? 'Google' : 'Apple';
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('既に別のアカウントにリンク済みです'),
          content: Text(
            '$providerLabel アカウントは既に別のユーザーに紐づいています。\n'
            'ゲストのままではリンクできません。$providerLabel で直接ログインしますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('$providerLabel でログイン'),
            ),
          ],
        );
      },
    );
  }

  void _listenAuthErrors() {
    _authStateSub?.cancel();
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) async {
        if (state.event == AuthChangeEvent.signedIn &&
            ((_pendingGuestRecords != null &&
                    _pendingGuestRecords!.isNotEmpty) ||
                (_pendingGuestShoppingItems != null &&
                    _pendingGuestShoppingItems!.isNotEmpty))) {
          await _migrateGuestRecords();
        }
      },
      onError: (error, stackTrace) {
        _handleLinkError(error, _lastProvider ?? OAuthProvider.google);
      },
    );
  }

  Future<void> _handleLinkError(
    Object error,
    OAuthProvider provider,
  ) async {
    if (_handledLinkError) return;
    _handledLinkError = true;
    await _captureGuestRecords();
    final authEx = error is AuthException ? error : null;
    final code = (authEx?.statusCode ?? authEx?.code ?? '').toLowerCase();
    final message = error.toString().toLowerCase();
    final identityExists = code.contains('identity_already_exists') ||
        (code.contains('identity') && code.contains('exists')) ||
        message.contains('identity_already_exists') ||
        message.contains('identity is already linked');
    if (identityExists) {
      final guestUserId = Supabase.instance.client.auth.currentUser?.id;
      if (guestUserId != null && _pendingGuestRecords == null) {
        try {
          final rows = await Supabase.instance.client
              .from('price_records')
              .select()
              .eq('user_id', guestUserId);
          _pendingGuestRecords = rows.whereType<Map>().map((e) {
            final copy = Map<String, dynamic>.from(e);
            copy.remove('id');
            copy['user_id'] = null;
            return copy;
          }).toList();
        } catch (_) {
          _pendingGuestRecords = null;
        }
      }
      final shouldLogin = await _showIdentityExistsDialog(provider);
      if (shouldLogin == true) {
        try {
          await Supabase.instance.client.auth.signOut();
          await Supabase.instance.client.auth.signInWithOAuth(
            provider,
            redirectTo: supabaseRedirectUri,
          );
          if (!mounted) return;
          _showStatusSnackBar('ブラウザを開きました。Googleアカウントでログインしてください。');
        } catch (loginError) {
          if (!mounted) return;
          _showStatusSnackBar(
              'ログインに失敗しました。${_friendlyErrorMessage(loginError)}',
              isError: true);
        }
      } else {
        if (!mounted) return;
        _showStatusSnackBar('このアカウントは既に別のユーザーに紐づいています。', isError: true);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (!mounted) return;
    _showStatusSnackBar('連携に失敗しました。${_friendlyErrorMessage(error)}',
        isError: true);
    setState(() => _isLoading = false);
  }

  Future<void> _migrateGuestRecords() async {
    final newUserId = Supabase.instance.client.auth.currentUser?.id;
    final records = _pendingGuestRecords;
    final shoppingItems = _pendingGuestShoppingItems;
    _pendingGuestRecords = null;
    _pendingGuestShoppingItems = null;
    try {
      if (newUserId == null) return;

      if (records != null && records.isNotEmpty) {
        final payload = records
            .map((r) => Map<String, dynamic>.from(r)..['user_id'] = newUserId)
            .toList();
        await Supabase.instance.client.from('price_records').insert(payload);
      }

      if (shoppingItems != null && shoppingItems.isNotEmpty) {
        final payload = shoppingItems
            .map((r) => Map<String, dynamic>.from(r)..['user_id'] = newUserId)
            .toList();
        await Supabase.instance.client
            .from('shopping_list_items')
            .insert(payload);
      }
      if (mounted) {
        _showStatusSnackBar('ゲストの記録をアカウントに引き継ぎました。');
        refreshStats();
      }
    } catch (e) {
      if (mounted) {
        _showStatusSnackBar('記録の引き継ぎに失敗しました。${_friendlyErrorMessage(e)}',
            isError: true);
      }
    }
  }

  Future<void> _captureGuestRecords() async {
    if (!_priceRepository.isGuest) return;
    final guestUserId = Supabase.instance.client.auth.currentUser?.id;
    if (guestUserId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('price_records')
          .select()
          .eq('user_id', guestUserId);
      _pendingGuestRecords = rows.whereType<Map>().map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('id');
        copy['user_id'] = null;
        return copy;
      }).toList();
    } catch (_) {
      _pendingGuestRecords = null;
    }

    try {
      final rows = await Supabase.instance.client
          .from('shopping_list_items')
          .select()
          .eq('user_id', guestUserId);
      _pendingGuestShoppingItems = rows.whereType<Map>().map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('id');
        copy['user_id'] = null;
        return copy;
      }).toList();
    } catch (_) {
      _pendingGuestShoppingItems = null;
    }
  }

  Future<void> refreshStats() async {
    setState(() {
      _statsFuture = _fetchProfileStats();
    });
    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = _priceRepository.isGuest;
    final emailText = user?.email ?? 'ゲストユーザー';
    final isPro = ref.watch(subscriptionProvider).isPro;

    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: RefreshIndicator(
        onRefresh: refreshStats,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Premium header with gradient
            SliverToBoxAdapter(
              child: _buildHeader(user, isGuest, isPro, emailText),
            ),

            // Stats section
            SliverToBoxAdapter(
              child: _buildStatsSection(),
            ),

            // Settings menu
            SliverToBoxAdapter(
              child: _buildSettingsSection(isGuest, isPro),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User? user, bool isGuest, bool isPro, String emailText) {
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
              // Avatar section with Pro badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatar(user),
                  if (!isGuest && isPro)
                    Positioned(
                      right: -15,
                      top: -5,
                      child: Transform.rotate(
                        angle: 0.15, // slight tilt to right
                        child: _buildProBadge(),
                      ),
                    ),
                ],
              ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildProBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.crown(PhosphorIconsStyle.fill),
            size: 14,
            color: const Color(0xFFFFB800),
          ),
          const SizedBox(width: 4),
          const Text(
            'Pro',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB800),
            ),
          ),
        ],
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
          onTap: !_priceRepository.isGuest && !_isUpdatingProfile
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
              if (!_priceRepository.isGuest)
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
                    onTap: loading ? null : () => _showLevelInfoDialog(scans),
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
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
          ),
        ),
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

  Widget _buildSettingsSection(bool isGuest, bool isPro) {
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
                    title: '新規アカウント作成',
                    subtitle: 'メールアドレスで新しく登録',
                    onTap: _isLoading ? null : _showEmailLinkDialog,
                    iconColor: KurabeColors.primary,
                  ),
                  _buildTileDivider(),
                  _buildSettingsTile(
                    icon: PhosphorIcons.key(PhosphorIconsStyle.fill),
                    title: '既存アカウントでログイン',
                    subtitle: '登録済みメールでサインイン',
                    onTap: _isLoading ? null : _showExistingEmailLoginDialog,
                    iconColor: KurabeColors.accent,
                  ),
                ] else ...[
                  if (!isPro) ...[
                    _buildSettingsTile(
                      icon: PhosphorIcons.crown(PhosphorIconsStyle.fill),
                      title: 'Proにアップグレード',
                      subtitle: 'コミュニティ価格を解放',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                        ),
                      ),
                      iconColor: KurabeColors.accent,
                    ),
                    _buildTileDivider(),
                  ],
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
                title: 'ログアウト',
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
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      _showStatusSnackBar('サインアウトしました。');
    } catch (e) {
      _showStatusSnackBar('サインアウトに失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkWithOAuth(OAuthProvider provider) async {
    _lastProvider = provider;
    _handledLinkError = false;
    setState(() => _isLoading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (provider == OAuthProvider.apple && Platform.isIOS) {
        await _captureGuestRecords();
        final credential = await const AppleSignInService().authorize();
        await auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.idToken,
          nonce: credential.rawNonce,
        );
      } else {
        if (_priceRepository.isGuest) {
          await auth.linkIdentity(
            provider,
            redirectTo: supabaseRedirectUri,
          );
        } else {
          await auth.signInWithOAuth(
            provider,
            redirectTo: supabaseRedirectUri,
          );
        }
      }
      if (!mounted) return;
      if (provider == OAuthProvider.apple && Platform.isIOS) {
        _showStatusSnackBar('Appleでサインインしました。');
      } else {
        _showStatusSnackBar('連携用のブラウザを開きました。サインインを完了してください。');
      }
    } catch (e) {
      await _handleLinkError(e, provider);
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

  Future<void> _showExistingEmailLoginDialog({String? prefillEmail}) async {
    final emailController = TextEditingController(text: prefillEmail ?? '');
    final passwordController = TextEditingController();

    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('既存メールでログイン'),
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
              const SizedBox(height: 8),
              const Text(
                'ゲストの記録を保持したまま既存アカウントにログインします。',
                style: TextStyle(fontSize: 12),
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
              child: const Text('ログイン'),
            ),
          ],
        );
      },
    );

    if (shouldLogin == true) {
      await _loginWithExistingEmail(
        emailController.text.trim(),
        passwordController.text,
      );
    }
  }

  Future<void> _linkWithEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      _showStatusSnackBar('確認メールを送信しました。受信箱を確認してください。');
    } on AuthException catch (e) {
      final msgLower = e.message.toLowerCase();
      final alreadyRegistered =
          msgLower.contains('already') && msgLower.contains('registered');
      if (alreadyRegistered) {
        if (mounted) {
          _showStatusSnackBar('このメールは既に登録されています。ログインから接続してください。',
              isError: true);
        }
        await _showExistingEmailLoginDialog(prefillEmail: email);
        return;
      }
      if (!mounted) return;
      _showStatusSnackBar('メール連携に失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
    } catch (e) {
      if (!mounted) return;
      _showStatusSnackBar('メール連携に失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithExistingEmail(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);

    await _captureGuestRecords();

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _migrateGuestRecords();
      if (!mounted) return;
      _showStatusSnackBar('ログインしました。ゲストの記録を引き継ぎました。');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showStatusSnackBar('ログインに失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
    } catch (e) {
      if (!mounted) return;
      _showStatusSnackBar('ログインに失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
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
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      _showStatusSnackBar('ゲストとしてサインアウトしました。');
    } catch (e) {
      if (!mounted) return;
      _showStatusSnackBar('サインアウトに失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
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
    if (scans >= 100) return '仙人';
    if (scans >= 50) return '師範';
    if (scans >= 30) return '達人';
    if (scans >= 15) return '熟練';
    if (scans >= 5) return '初級';
    return '見習';
  }

  Future<void> _showLevelInfoDialog(int scans) async {
    final levels = [
      ('見習', 0, Icons.eco_outlined),
      ('初級', 5, Icons.trending_up),
      ('熟練', 15, Icons.star_outline),
      ('達人', 30, Icons.workspace_premium_outlined),
      ('師範', 50, Icons.emoji_events_outlined),
      ('仙人', 100, Icons.auto_awesome),
    ];

    // Find current and next level
    int currentLevelIndex = 0;
    for (int i = levels.length - 1; i >= 0; i--) {
      if (scans >= levels[i].$2) {
        currentLevelIndex = i;
        break;
      }
    }

    final currentLevel = levels[currentLevelIndex];
    final isMaxLevel = currentLevelIndex == levels.length - 1;
    final nextLevel = isMaxLevel ? null : levels[currentLevelIndex + 1];

    // Calculate progress to next level
    double progress = 1.0;
    int scansToNext = 0;
    if (!isMaxLevel && nextLevel != null) {
      final currentThreshold = currentLevel.$2;
      final nextThreshold = nextLevel.$2;
      final range = nextThreshold - currentThreshold;
      final progressInRange = scans - currentThreshold;
      progress = (progressInRange / range).clamp(0.0, 1.0);
      scansToNext = nextThreshold - scans;
    }

    // Gradient colors for levels
    final levelColors = [
      [const Color(0xFF9CA3AF), const Color(0xFF6B7280)], // 見習 - Gray
      [const Color(0xFF60A5FA), const Color(0xFF3B82F6)], // 初級 - Blue
      [const Color(0xFF34D399), const Color(0xFF10B981)], // 熟練 - Green
      [const Color(0xFFFBBF24), const Color(0xFFF59E0B)], // 達人 - Amber
      [const Color(0xFFF472B6), const Color(0xFFEC4899)], // 師範 - Pink
      [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)], // 仙人 - Purple
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: levelColors[currentLevelIndex],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          currentLevel.$3,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentLevel.$1,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$scans 回スキャン達成',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress section
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMaxLevel && nextLevel != null) ...[
                        // Next level info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '次のレベル: ${nextLevel.$1}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            Text(
                              'あと $scansToNext 回',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: levelColors[currentLevelIndex + 1][0],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress bar
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    width: constraints.maxWidth * progress,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: levelColors[currentLevelIndex],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: levelColors[currentLevelIndex]
                                                  [0]
                                              .withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress label
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentLevel.$2}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              '${nextLevel.$2}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        // Max level reached
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: levelColors[currentLevelIndex][0]
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified,
                                color: levelColors[currentLevelIndex][0],
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '最高レベルに到達しました！',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Level milestones
                      const Text(
                        'レベル一覧',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(levels.length, (index) {
                        final level = levels[index];
                        final isAchieved = scans >= level.$2;
                        final isCurrent = index == currentLevelIndex;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: isAchieved
                                      ? LinearGradient(
                                          colors: levelColors[index])
                                      : null,
                                  color:
                                      isAchieved ? null : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  level.$3,
                                  size: 16,
                                  color: isAchieved
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  level.$1,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isAchieved
                                        ? const Color(0xFF374151)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Text(
                                '${level.$2}回',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isAchieved
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isAchieved)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: levelColors[index][0],
                                )
                              else
                                Icon(
                                  Icons.circle_outlined,
                                  size: 18,
                                  color: Colors.grey.shade300,
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        '閉じる',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      _showStatusSnackBar('画像サイズは15MB以内にしてください。', isError: true);
      return;
    }
    final adjustedBytes = await _showAvatarAdjustDialog(originalBytes);
    if (adjustedBytes == null) return;
    setState(() => _isUpdatingProfile = true);
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
      _showStatusSnackBar('アバターを更新しました。');
    } catch (e) {
      _showStatusSnackBar('アバター更新に失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
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
    setState(() => _isUpdatingProfile = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'name': newName}),
      );
      _showStatusSnackBar('名前を更新しました。');
    } catch (e) {
      _showStatusSnackBar('名前の更新に失敗しました。${_friendlyErrorMessage(e)}',
          isError: true);
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
