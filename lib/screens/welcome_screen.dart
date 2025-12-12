import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../constants/auth.dart';

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
    final msg = error.toString().toLowerCase();
    
    // Password errors
    if (msg.contains('password') && (msg.contains('6') || msg.contains('least'))) {
      return 'パスワードは6文字以上で入力してください。';
    }
    if (msg.contains('weak') && msg.contains('password')) {
      return 'パスワードが弱すぎます。より強力なパスワードを設定してください。';
    }
    
    // Login errors
    if (msg.contains('invalid') && (msg.contains('login') || msg.contains('credentials'))) {
      return 'メールアドレスまたはパスワードが正しくありません。';
    }
    
    // Email errors
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'メールアドレスの形式が正しくありません。';
    }
    if ((msg.contains('email') || msg.contains('user')) && 
        msg.contains('already') && 
        (msg.contains('registered') || msg.contains('exists'))) {
      return 'このメールアドレスは既に登録されています。';
    }
    if (msg.contains('email') && msg.contains('not') && msg.contains('confirmed')) {
      return 'メールアドレスが確認されていません。受信箱を確認してください。';
    }
    
    // Network errors
    if (msg.contains('network') || msg.contains('connection') || msg.contains('timeout') || msg.contains('socket')) {
      return 'ネットワーク接続に問題があります。接続を確認してください。';
    }
    
    // Rate limiting
    if (msg.contains('rate') && msg.contains('limit')) {
      return 'リクエストが多すぎます。しばらく待ってから再試行してください。';
    }
    
    // Generic fallback
    return '予期せぬエラーが発生しました。もう一度お試しください。';
  }

  /// Shows a floating SnackBar with the given message
  void _showStatusSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)
                  : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? KurabeColors.error : KurabeColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        );
        if (response.session != null) {
          return 'アカウントを作成しました。';
        }
        return '確認メールを送信しました。メールを確認してください。';
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
      if (isAnon) {
        await auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: supabaseRedirectUri,
        );
      } else {
        await auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: supabaseRedirectUri,
        );
      }
      return null;
    });
  }

  Future<void> _signInWithApple() async {
    await _runAuthAction(() async {
      final auth = Supabase.instance.client.auth;
      final isAnon = _isAnonymousSession(auth.currentSession);
      if (isAnon) {
        await auth.linkIdentity(
          OAuthProvider.apple,
          redirectTo: supabaseRedirectUri,
        );
      } else {
        await auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: supabaseRedirectUri,
        );
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
