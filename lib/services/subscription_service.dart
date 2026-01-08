import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/config/app_config.dart';

class SubscriptionException implements Exception {
  SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Handles RevenueCat initialization, login and entitlement syncing.
class SubscriptionService {
  SubscriptionService({SupabaseClient? client, AppConfig? config})
      : _client = client ?? Supabase.instance.client,
        _config = config;

  final SupabaseClient _client;
  final AppConfig? _config;
  bool _configured = false;
  bool _hasListener = false;
  String? _lastError;

  static const String _proEntitlementId = 'カイログ Pro';

  String? get lastError => _lastError;

  Future<bool> configure() async {
    if (_configured) return true;
    final envKey =
        (_config?.revenuecatApiKey ?? dotenv.env['REVENUECAT_API_KEY'] ?? '')
            .trim();
    if (envKey.isEmpty) {
      _lastError = 'RevenueCatのAPIキーが未設定です。設定を確認してください。';
      _configured = false;
      return false;
    }
    final revenuecatKey = envKey;
    try {
      final userId = _client.auth.currentUser?.id;
      final configuration = PurchasesConfiguration(revenuecatKey)
        ..appUserID = userId
        ..entitlementVerificationMode =
            EntitlementVerificationMode.informational;
      await Purchases.configure(configuration);
      _configured = true;
      _lastError = null;
      _attachCustomerInfoListener();
      debugPrint('[SubscriptionService] RevenueCat configured.');
      return true;
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to configure: $e');
      _lastError = 'RevenueCat を初期化できませんでした。';
      _configured = false;
      return false;
    }
  }

  Future<void> logInCurrentUser() async {
    if (!_configured) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await _safeLogout();
      return;
    }
    try {
      final result = await Purchases.logIn(userId);
      await _syncFromCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('[SubscriptionService] logIn failed: $e');
    }
  }

  Future<void> _safeLogout() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('[SubscriptionService] logOut failed: $e');
    }
  }

  Future<bool> refreshStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      if (!_configured) {
        final fallback = await _fetchSupabaseFlag(userId);
        return fallback ?? false;
      }
      final info = await Purchases.getCustomerInfo();
      return _syncFromCustomerInfo(info);
    } catch (e) {
      debugPrint('[SubscriptionService] refreshStatus fallback: $e');
      await _updateSupabaseFlag(userId, false);
      return false;
    }
  }

  Future<bool> purchaseMonthly() async {
    return purchasePackage('Promonthly');
  }

  Future<bool> purchasePackage(String packageId) async {
    debugPrint('[SubscriptionService] purchasePackage called with: $packageId');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[SubscriptionService] Error: No user ID');
      throw SubscriptionException('ログイン後に購入してください。');
    }
    if (!_configured) {
      debugPrint('[SubscriptionService] Not configured, attempting configure...');
      final configured = await configure();
      if (!configured) {
        debugPrint('[SubscriptionService] Configure failed: $_lastError');
        throw SubscriptionException(
          _lastError ?? 'RevenueCat を初期化できませんでした。',
        );
      }
    }
    debugPrint('[SubscriptionService] Fetching offerings...');
    final offerings = await Purchases.getOfferings();
    debugPrint('[SubscriptionService] Current offering: ${offerings.current?.identifier}');
    final available = offerings.current?.availablePackages ?? [];
    debugPrint('[SubscriptionService] Available packages: ${available.map((p) => '${p.identifier}(${p.packageType})').toList()}');
    // Try matching by identifier, then by packageType name, then fall back to monthly/first.
    Package? package;
    try {
      package = available.firstWhere(
        (p) =>
            p.identifier == packageId ||
            p.packageType.name.toLowerCase() == packageId.toLowerCase(),
      );
      debugPrint('[SubscriptionService] Found package by ID/type match: ${package.identifier}');
    } catch (_) {
      debugPrint('[SubscriptionService] No exact match for $packageId');
      package = null;
    }
    if (package == null) {
      try {
        package = available.firstWhere(
          (p) => p.packageType == PackageType.monthly || p.identifier == 'Promonthly',
        );
        debugPrint('[SubscriptionService] Found fallback monthly package: ${package.identifier}');
      } catch (_) {
        debugPrint('[SubscriptionService] No monthly fallback found');
        package = null;
      }
    }
    if (package == null && available.isNotEmpty) {
      package = available.first;
      debugPrint('[SubscriptionService] Using first available package: ${package.identifier}');
    }
    package ??= offerings.current?.monthly;
    if (package == null) {
      debugPrint('[SubscriptionService] Error: No package found at all!');
      throw SubscriptionException('購入可能なプランが見つかりません。');
    }
    debugPrint('[SubscriptionService] Attempting purchase of: ${package.identifier} (${package.storeProduct.identifier})');
    final result = await Purchases.purchase(
      PurchaseParams.package(package),
    );
    debugPrint('[SubscriptionService] Purchase completed, syncing customer info...');
    return _syncFromCustomerInfo(result.customerInfo);
  }

  Future<bool> restore() async {
    if (!_configured) {
      final configured = await configure();
      if (!configured) {
        throw SubscriptionException(
          _lastError ?? 'RevenueCat を初期化できませんでした。',
        );
      }
    }
    try {
      final info = await Purchases.restorePurchases();
      return _syncFromCustomerInfo(info);
    } catch (e) {
      debugPrint('[SubscriptionService] restore failed: $e');
      return false;
    }
  }

  Future<bool> showRevenueCatPaywall(BuildContext context) async {
    if (!_configured) {
      final ok = await configure();
      if (!ok) {
        throw SubscriptionException(
          _lastError ?? 'RevenueCat を初期化できませんでした。',
        );
      }
    }
    final result = await RevenueCatUI.presentPaywallIfNeeded(
      _proEntitlementId,
    );
    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      final info = await Purchases.getCustomerInfo();
      return _syncFromCustomerInfo(info);
    }
    final info = await Purchases.getCustomerInfo();
    return _syncFromCustomerInfo(info);
  }

  Future<void> showCustomerCenter(BuildContext context) async {
    if (!_configured) {
      final ok = await configure();
      if (!ok) {
        throw SubscriptionException(
          _lastError ?? 'RevenueCat を初期化できませんでした。',
        );
      }
    }
    await RevenueCatUI.presentCustomerCenter();
  }

  Future<bool> _syncFromCustomerInfo(CustomerInfo info) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final isPro = _hasProEntitlement(info);
    await _updateSupabaseFlag(userId, isPro);
    return isPro;
  }

  bool _hasProEntitlement(CustomerInfo info) {
    final entitlements = info.entitlements.active;
    if (entitlements[_proEntitlementId] != null) return true;
    return entitlements.values
        .any((entitlement) => entitlement.identifier == _proEntitlementId);
  }

  void _attachCustomerInfoListener() {
    if (_hasListener || !_configured) return;
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      unawaited(_syncFromCustomerInfo(customerInfo));
    });
    _hasListener = true;
  }

  Future<bool?> _fetchSupabaseFlag(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('is_pro')
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      final isPro = response['is_pro'];
      if (isPro is bool) return isPro;
      return null;
    } catch (e) {
      debugPrint('[SubscriptionService] fetch flag failed: $e');
      return null;
    }
  }

  Future<void> _updateSupabaseFlag(String userId, bool isPro) async {
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'is_pro': isPro,
      });
    } catch (e) {
      debugPrint('[SubscriptionService] update flag failed: $e');
    }
  }
}
