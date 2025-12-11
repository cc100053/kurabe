import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/widgets.dart';

import 'providers/app_state.dart';
import 'screens/main_scaffold.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  await initializeDateFormatting('ja_JP', null);
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KurabeApp());
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env の読み込みに失敗しました: $e');
  }
}

/// Premium Design System Colors
class KurabeColors {
  // Primary palette
  static const Color primary = Color(0xFF1A8D7A);        // Deep teal
  static const Color primaryLight = Color(0xFF4DB6A6);   // Light teal
  static const Color primaryDark = Color(0xFF0D5C50);    // Dark teal
  
  // Surface colors (warm cream tones)
  static const Color background = Color(0xFFFAF9F7);     // Warm off-white
  static const Color surface = Color(0xFFFDFCFB);        // Cream white
  static const Color surfaceElevated = Color(0xFFFFFFFF); // Pure white for cards
  
  // Text colors
  static const Color textPrimary = Color(0xFF242424);    // Charcoal
  static const Color textSecondary = Color(0xFF6B7280);  // Warm gray
  static const Color textTertiary = Color(0xFF9CA3AF);   // Light gray
  
  // Accent colors
  static const Color accent = Color(0xFFFF8C42);         // Warm orange
  static const Color success = Color(0xFF34C759);        // Green
  static const Color error = Color(0xFFE53935);          // Red
  static const Color warning = Color(0xFFFFB020);        // Amber
  
  // UI colors
  static const Color border = Color(0xFFE5E7EB);         // Light border
  static const Color divider = Color(0xFFF3F4F6);        // Subtle divider
  static const Color shadow = Color(0x0A000000);         // Soft black shadow
}

class KurabeApp extends StatefulWidget {
  const KurabeApp({super.key});

  @override
  State<KurabeApp> createState() => _KurabeAppState();
}

class _KurabeAppState extends State<KurabeApp> {
  bool _resetDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    // Build the text theme with Noto Sans JP
    final baseTextTheme = GoogleFonts.notoSansJpTextTheme(
      Theme.of(context).textTheme,
    );
    
    final textTheme = baseTextTheme.copyWith(
      // Display styles - for hero text
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: KurabeColors.textPrimary,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: KurabeColors.textPrimary,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: KurabeColors.textPrimary,
      ),
      // Headline styles - for section headers
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: KurabeColors.textPrimary,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: KurabeColors.textPrimary,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: KurabeColors.textPrimary,
      ),
      // Title styles - for cards and list items
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: KurabeColors.textPrimary,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: KurabeColors.textPrimary,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: KurabeColors.textPrimary,
      ),
      // Body styles - for content
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: KurabeColors.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: KurabeColors.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: KurabeColors.textTertiary,
      ),
      // Label styles - for buttons and chips
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: KurabeColors.textPrimary,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: KurabeColors.textSecondary,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: KurabeColors.textTertiary,
      ),
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Kurabe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          
          // Colors
          scaffoldBackgroundColor: KurabeColors.background,
          colorScheme: ColorScheme.light(
            primary: KurabeColors.primary,
            onPrimary: Colors.white,
            primaryContainer: KurabeColors.primaryLight.withAlpha(51),
            onPrimaryContainer: KurabeColors.primaryDark,
            secondary: KurabeColors.accent,
            onSecondary: Colors.white,
            secondaryContainer: KurabeColors.accent.withAlpha(51),
            onSecondaryContainer: KurabeColors.accent,
            tertiary: KurabeColors.primaryLight,
            surface: KurabeColors.surface,
            onSurface: KurabeColors.textPrimary,
            surfaceContainerHighest: KurabeColors.surfaceElevated,
            outline: KurabeColors.border,
            outlineVariant: KurabeColors.divider,
            error: KurabeColors.error,
            onError: Colors.white,
          ),
          
          // Typography
          textTheme: textTheme,
          
          // AppBar theme
          appBarTheme: AppBarTheme(
            backgroundColor: KurabeColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            iconTheme: const IconThemeData(
              color: KurabeColors.textPrimary,
              size: 24,
            ),
          ),
          
          // Card theme - elevated with soft shadows
          cardTheme: CardThemeData(
            color: KurabeColors.surfaceElevated,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          ),
          
          // Input decoration - neumorphic style
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: KurabeColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: KurabeColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: KurabeColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: KurabeColors.error, width: 1),
            ),
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: KurabeColors.textTertiary,
            ),
          ),
          
          // Elevated button - gradient-ready with rounded corners
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: KurabeColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
              textStyle: textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Text button
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: KurabeColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Outlined button
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: KurabeColors.primary,
              side: const BorderSide(color: KurabeColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
              textStyle: textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Floating action button
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: KurabeColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: CircleBorder(),
          ),
          
          // Bottom navigation bar
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: KurabeColors.surfaceElevated,
            selectedItemColor: KurabeColors.primary,
            unselectedItemColor: KurabeColors.textTertiary,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
          
          // Chip theme
          chipTheme: ChipThemeData(
            backgroundColor: KurabeColors.divider,
            labelStyle: textTheme.labelMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          
          // Dialog theme
          dialogTheme: DialogThemeData(
            backgroundColor: KurabeColors.surfaceElevated,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titleTextStyle: textTheme.titleLarge,
            contentTextStyle: textTheme.bodyMedium,
          ),
          
          // Bottom sheet theme
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: KurabeColors.surfaceElevated,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            showDragHandle: true,
            dragHandleColor: KurabeColors.border,
            dragHandleSize: Size(40, 4),
          ),
          
          // Divider theme
          dividerTheme: const DividerThemeData(
            color: KurabeColors.divider,
            thickness: 1,
            space: 1,
          ),
          
          // List tile theme
          listTileTheme: ListTileThemeData(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: Colors.transparent,
            selectedTileColor: KurabeColors.primary.withAlpha(26),
          ),
          
          // Icon theme
          iconTheme: const IconThemeData(
            color: KurabeColors.textSecondary,
            size: 24,
          ),
          
          // Progress indicator theme
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: KurabeColors.primary,
            linearTrackColor: KurabeColors.divider,
            circularTrackColor: KurabeColors.divider,
          ),
          
          // Snackbar theme
          snackBarTheme: SnackBarThemeData(
            backgroundColor: KurabeColors.textPrimary,
            contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final authState = snapshot.data;
            if (authState?.event == AuthChangeEvent.passwordRecovery &&
                !_resetDialogOpen) {
              _resetDialogOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showPasswordResetDialog(context);
              });
            }
            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) return const MainScaffold();
            return const WelcomeScreen();
          },
        ),
      ),
    );
  }

  Future<void> _showPasswordResetDialog(BuildContext context) async {
    final newPassController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final newPass = newPassController.text.trim();
              final confirm = confirmController.text.trim();
              if (newPass.isEmpty || confirm.isEmpty) {
                setState(() => error = 'パスワードを入力してください。');
                return;
              }
              if (newPass.length < 6) {
                setState(() => error = 'パスワードは6文字以上で入力してください。');
                return;
              }
              if (newPass != confirm) {
                setState(() => error = 'パスワードが一致しません。');
                return;
              }
              setState(() {
                saving = true;
                error = null;
              });
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPass),
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('パスワードを更新しました。')),
                );
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  saving = false;
                  error = '更新に失敗しました: $e';
                });
              }
            }

            return AlertDialog(
              title: const Text('パスワード再設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '新しいパスワード'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: '新しいパスワード(確認)'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: KurabeColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('更新'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() => _resetDialogOpen = false);
    } else {
      _resetDialogOpen = false;
    }
  }
}
