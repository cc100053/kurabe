import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

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
  String? _error;
  String? _message;

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

              // Error / Success Messages
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KurabeColors.error.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KurabeColors.error.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                        color: KurabeColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: KurabeColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_message != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KurabeColors.success.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: KurabeColors.success.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: KurabeColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: KurabeColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
      setState(() => _error = 'メールアドレスとパスワードを入力してください。');
      return;
    }

    if (_isSignUpMode) {
      await _signUpWithEmail(email, password);
    } else {
      await _loginWithEmail(email, password);
    }
  }

  Future<void> _signUpWithEmail(String email, String password) async {
    await _runAuthAction(() async {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.session != null) {
        return 'アカウントを作成しました。';
      }
      return '確認メールを送信しました。メールを確認してください。';
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
          redirectTo: 'io.supabase.flutter://login-callback/',
        );
      } else {
        await auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.flutter://login-callback/',
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
        await auth.linkIdentity(OAuthProvider.apple);
      } else {
        await auth.signInWithOAuth(OAuthProvider.apple);
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
      String errorMessage = '$e';
      // Clean up common error messages
      if (errorMessage.contains('Invalid login credentials')) {
        errorMessage = 'メールアドレスまたはパスワードが正しくありません。';
      } else if (errorMessage.contains('User already registered')) {
        errorMessage = 'このメールアドレスは既に登録されています。';
      } else if (errorMessage.contains('Password should be')) {
        errorMessage = 'パスワードは6文字以上で入力してください。';
      }
      setState(() => _error = errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
