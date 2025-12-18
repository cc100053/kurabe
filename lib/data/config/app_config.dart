import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized application configuration loaded from environment variables.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.revenuecatApiKey,
    this.googlePlacesApiKey,
    this.geminiApiKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? revenuecatApiKey;
  final String? googlePlacesApiKey;
  final String? geminiApiKey;
}

/// Provide the resolved configuration; must be overridden at bootstrap.
final appConfigProvider = Provider<AppConfig>((_) {
  throw UnimplementedError('AppConfig is not initialized');
});
