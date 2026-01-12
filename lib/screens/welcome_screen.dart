import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../constants/auth.dart';
import '../services/auth_error_mapper.dart';
import '../services/apple_sign_in_service.dart';
import '../widgets/app_snackbar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;

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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo / Brand
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: KurabeColors.primary.withAlpha(50),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/icon_inside.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // App Name - Beautiful gradient text
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    KurabeColors.primary,
                    Color(0xFF2BA89D),
                    KurabeColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'カイログ',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Subtitle with accent
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: KurabeColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                      size: 16,
                      color: KurabeColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'みんなで価格を記録しよう',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KurabeColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Email Field
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                label: 'メールアドレス',
                hint: 'example@email.com',
                icon: PhosphorIcons.envelope(PhosphorIconsStyle.regular),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: 16),

              // Password Field
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: 'パスワード',
                hint: '••••••••',
                icon: PhosphorIcons.lock(PhosphorIconsStyle.regular),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleEmailAuth(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? PhosphorIcons.eye(PhosphorIconsStyle.regular)
                        : PhosphorIcons.eyeSlash(PhosphorIconsStyle.regular),
                    color: KurabeColors.textTertiary,
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KurabeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignUpMode ? '新規登録' : 'ログイン',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (!_isSignUpMode) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    child: const Text('パスワードをお忘れですか？'),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Toggle Sign Up / Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUpMode ? 'すでにアカウントをお持ちですか？' : 'アカウントをお持ちでないですか？',
                    style: TextStyle(
                      fontSize: 14,
                      color: KurabeColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _isSignUpMode = !_isSignUpMode),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isSignUpMode ? 'ログイン' : '新規登録',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KurabeColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: KurabeColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'または',
                      style: TextStyle(
                        fontSize: 13,
                        color: KurabeColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: KurabeColors.divider)),
                ],
              ),
              const SizedBox(height: 24),

              // Social Login Buttons
              _buildSocialButton(
                label: 'Googleでログイン',
                icon: PhosphorIcons.googleLogo(PhosphorIconsStyle.fill),
                iconColor: const Color(0xFFDB4437),
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),

              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildSocialButton(
                  label: 'Appleでログイン',
                  icon: PhosphorIcons.appleLogo(PhosphorIconsStyle.fill),
                  iconColor: Colors.black,
                  onPressed: _isLoading ? null : _signInWithApple,
                ),
              ],

              const SizedBox(height: 12),
              _buildSocialButton(
                label: 'ゲストとして続行',
                icon: PhosphorIcons.userCircle(PhosphorIconsStyle.regular),
                iconColor: KurabeColors.textSecondary,
                onPressed: _isLoading ? null : _continueAsGuest,
                isOutlined: true,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: KurabeColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: KurabeColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KurabeColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: KurabeColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: KurabeColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: KurabeColors.textTertiary, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 46),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isOutlined ? Colors.transparent : KurabeColors.surfaceElevated,
          side: BorderSide(
            color: isOutlined ? KurabeColors.border : KurabeColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: KurabeColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showStatusSnackBar('メールアドレスとパスワードを入力してください。', isError: true);
      return;
    }

    if (_isSignUpMode) {
      await _signUpWithEmail(email, password);
    } else {
      await _loginWithEmail(email, password);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showStatusSnackBar('登録済みのメールアドレスを入力してください。', isError: true);
      return;
    }
    await _runAuthAction(() async {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseRedirectUri,
      );
      return 'パスワードリセット用のメールを送信しました。';
    });
  }

  Future<void> _signUpWithEmail(String email, String password) async {
    await _runAuthAction(() async {
      final auth = Supabase.instance.client.auth;
      try {
        final response = await auth.signUp(
          email: email,
          password: password,
          data: {'email_verified': false},
        );
        if (auth.currentSession == null && response.session == null) {
          try {
            final signIn = await auth.signInWithPassword(
              email: email,
              password: password,
            );
            if (signIn.session == null) {
              return 'ログインに失敗しました。';
            }
          } on AuthException catch (e) {
            if (_isAlreadyRegisteredError(e)) {
              setState(() {
                _isSignUpMode = false;
                _emailController.text = email;
              });
              return '既に登録済みです。ログインしてください。';
            }
            if (_isEmailConfirmationError(e)) {
              await _sendVerificationEmailIfNeeded(email);
              return '確認メールを送信しました。メールを確認してください。';
            }
            rethrow;
          }
        }
        await _ensureEmailVerificationFlag();
        await _sendVerificationEmailIfNeeded(email);
        return 'アカウントを作成しました。確認メールを送信しました。';
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        final alreadyRegistered =
            msg.contains('already') && msg.contains('registered');
        if (alreadyRegistered) {
          setState(() {
            _isSignUpMode = false;
            _emailController.text = email;
          });
          _showStatusSnackBar('既に登録済みです。ログインしてください。', isError: true);
          return null;
        }
        rethrow;
      }
    });
  }

  Future<void> _ensureEmailVerificationFlag() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final metaValue = user.userMetadata?['email_verified'];
    final verifiedAt = user.userMetadata?['email_verified_at'];
    if (metaValue is bool && (metaValue == false || verifiedAt != null)) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'email_verified': false}),
      );
    } catch (_) {
      // Best-effort to mark as unverified.
    }
  }

  bool _isEmailConfirmationError(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('confirm') || message.contains('verified');
  }

  bool _isAlreadyRegisteredError(AuthException error) {
    final message = error.message.toLowerCase();
    return (message.contains('already') &&
            (message.contains('registered') || message.contains('exists'))) ||
        message.contains('already registered') ||
        message.contains('user already') ||
        message.contains('email already');
  }

  Future<void> _sendVerificationEmailIfNeeded(String email) async {
    final user = Supabase.instance.client.auth.currentUser;
    final metaValue = user?.userMetadata?['email_verified'];
    final verifiedAt = user?.userMetadata?['email_verified_at'];
    if (metaValue is bool && metaValue && verifiedAt != null) return;
    try {
      await Supabase.instance.client.functions
          .invoke('send-email-verification');
    } catch (_) {
      // Ignore email resend failures to avoid blocking sign-up.
    }
  }

  Future<void> _loginWithEmail(String email, String password) async {
    await _runAuthAction(() async {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        return 'ログインしました。';
      }
      return 'ログインに失敗しました。';
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(() async {
      final auth = Supabase.instance.client.auth;
      final isAnon = _isAnonymousSession(auth.currentSession);
      final launchMode = Platform.isIOS
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault;
      if (isAnon) {
        await auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: supabaseRedirectUri,
          authScreenLaunchMode: launchMode,
        );
      } else {
        await auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: supabaseRedirectUri,
          authScreenLaunchMode: launchMode,
        );
      }
      return null;
    });
  }

  Future<void> _signInWithApple() async {
    await _runAuthAction(() async {
      final auth = Supabase.instance.client.auth;
      final isAnon = _isAnonymousSession(auth.currentSession);
      final pending = isAnon ? await _captureGuestData() : null;
      final credential = await const AppleSignInService().authorize();
      await auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.idToken,
        nonce: credential.rawNonce,
      );
      if (pending != null) {
        await _migrateGuestData(pending);
      }
      return null;
    });
  }

  Future<void> _continueAsGuest() async {
    await _runAuthAction(() async {
      await Supabase.instance.client.auth.signInAnonymously();
      return 'ゲストとしてログインしました。';
    });
  }

  bool _isAnonymousSession(Session? session) {
    final user = session?.user;
    if (user == null) return false;
    if (user.isAnonymous) return true;
    final appMeta = user.appMetadata;
    final provider = appMeta['provider'];
    if (provider is String && provider.toLowerCase() == 'anonymous') {
      return true;
    }
    final providers = appMeta['providers'];
    if (providers is List) {
      final lower = providers.map((e) => e.toString().toLowerCase());
      if (lower.contains('anonymous')) return true;
    }
    final metaFlag = (user.userMetadata ?? const {})['is_anonymous'];
    return metaFlag is bool && metaFlag;
  }

  Future<
      ({
        List<Map<String, dynamic>> priceRecords,
        List<Map<String, dynamic>> shoppingListItems
      })?> _captureGuestData() async {
    final guestUserId = Supabase.instance.client.auth.currentUser?.id;
    if (guestUserId == null) return null;

    List<Map<String, dynamic>> priceRecords = const [];
    List<Map<String, dynamic>> shoppingListItems = const [];

    try {
      final rows = await Supabase.instance.client
          .from('price_records')
          .select()
          .eq('user_id', guestUserId);
      priceRecords = rows.whereType<Map>().map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('id');
        copy['user_id'] = null;
        return copy;
      }).toList();
    } catch (_) {
      priceRecords = const [];
    }

    try {
      final rows = await Supabase.instance.client
          .from('shopping_list_items')
          .select()
          .eq('user_id', guestUserId);
      shoppingListItems = rows.whereType<Map>().map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('id');
        copy['user_id'] = null;
        return copy;
      }).toList();
    } catch (_) {
      shoppingListItems = const [];
    }

    if (priceRecords.isEmpty && shoppingListItems.isEmpty) return null;
    return (priceRecords: priceRecords, shoppingListItems: shoppingListItems);
  }

  Future<void> _migrateGuestData(
    ({
      List<Map<String, dynamic>> priceRecords,
      List<Map<String, dynamic>> shoppingListItems
    }) pending,
  ) async {
    final newUserId = Supabase.instance.client.auth.currentUser?.id;
    if (newUserId == null) return;

    if (pending.priceRecords.isNotEmpty) {
      final payload = pending.priceRecords
          .map((r) => Map<String, dynamic>.from(r)..['user_id'] = newUserId)
          .toList();
      await Supabase.instance.client.from('price_records').insert(payload);
    }

    if (pending.shoppingListItems.isNotEmpty) {
      final payload = pending.shoppingListItems
          .map((r) => Map<String, dynamic>.from(r)..['user_id'] = newUserId)
          .toList();
      await Supabase.instance.client.from('shopping_list_items').insert(payload);
    }
  }

  Future<void> _runAuthAction(Future<String?> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final msg = await action();
      if (mounted && msg != null) {
        _showStatusSnackBar(msg);
      }
    } catch (e) {
      _showStatusSnackBar(_friendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
