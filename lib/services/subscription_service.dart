import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles RevenueCat initialization, login and entitlement syncing.
class SubscriptionService {
  SubscriptionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  bool _configured = false;
  bool _hasListener = false;

  static const String _proEntitlementId = 'カイログ Pro';
  static const String _fallbackApiKey = 'test_RVGeIzWYzfusuOXUuNwueYEhskf';

  Future<bool> configure() async {
    if (_configured) return true;
    final envKey = (dotenv.env['REVENUECAT_API_KEY'] ?? '').trim();
    final revenuecatKey = envKey.isNotEmpty ? envKey : _fallbackApiKey;
    try {
      final userId = _client.auth.currentUser?.id;
      final configuration = PurchasesConfiguration(revenuecatKey)
        ..appUserID = userId
        ..entitlementVerificationMode =
            EntitlementVerificationMode.informational;
      await Purchases.configure(configuration);
      _configured = true;
      _attachCustomerInfoListener();
      debugPrint('[SubscriptionService] RevenueCat configured.');
      return true;
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to configure: $e');
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
    return purchasePackage('monthly');
  }

  Future<bool> purchasePackage(String packageId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('ログイン後に購入してください。');
    }
    if (!_configured) {
      final configured = await configure();
      if (!configured) throw Exception('RevenueCat を初期化できませんでした。');
    }
    final offerings = await Purchases.getOfferings();
    final available = offerings.current?.availablePackages ?? [];
    // Try matching by identifier, then by packageType name, then fall back to monthly/first.
    Package? package;
    try {
      package = available.firstWhere(
        (p) =>
            p.identifier == packageId ||
            p.packageType.name.toLowerCase() == packageId.toLowerCase(),
      );
    } catch (_) {
      package = null;
    }
    if (package == null) {
      try {
        package = available.firstWhere(
          (p) => p.packageType == PackageType.monthly,
        );
      } catch (_) {
        package = null;
      }
    }
    if (package == null && available.isNotEmpty) {
      package = available.first;
    }
    package ??= offerings.current?.monthly;
    if (package == null) throw Exception('購入可能なプランが見つかりません。');
    final result = await Purchases.purchase(
      PurchaseParams.package(package),
    );
    return _syncFromCustomerInfo(result.customerInfo);
  }

  Future<bool> restore() async {
    if (!_configured) {
      final configured = await configure();
      if (!configured) return false;
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
      if (!ok) throw Exception('RevenueCat を初期化できませんでした。');
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
      if (!ok) throw Exception('RevenueCat を初期化できませんでした。');
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
