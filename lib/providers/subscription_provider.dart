import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/config/app_config.dart';
import '../services/subscription_service.dart';

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.isLoading = false,
    this.error,
    this.initialized = false,
    this.isConfigured = false,
  });

  final bool isPro;
  final bool isLoading;
  final String? error;
  final bool initialized;
  final bool isConfigured;

  SubscriptionState copyWith({
    bool? isPro,
    bool? isLoading,
    String? error,
    bool? initialized,
    bool? isConfigured,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      initialized: initialized ?? this.initialized,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(this._service) : super(const SubscriptionState()) {
    _init();
  }

  final SubscriptionService _service;
  StreamSubscription<AuthState>? _authSub;

  Future<void> _init() async {
    final configured = await _service.configure();
    state = state.copyWith(isConfigured: configured);
    await _refreshStatus();
    _listenAuthChanges();
  }

  Future<void> _refreshStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isPro = await _service.refreshStatus();
      state = state.copyWith(
        isPro: isPro,
        isLoading: false,
        initialized: true,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        initialized: true,
        error: e.toString(),
      );
    }
  }

  void _listenAuthChanges() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final user = data.session?.user;
        if (data.event == AuthChangeEvent.signedOut || user == null) {
          await _service.logInCurrentUser();
          state = state.copyWith(isPro: false, initialized: true);
          return;
        }
        await _service.logInCurrentUser();
        await _refreshStatus();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[SubscriptionNotifier] auth listener error: $error');
      },
    );
  }

  Future<bool> refresh() async {
    await _refreshStatus();
    return state.isPro;
  }

  Future<bool> purchase() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isPro = await _service.purchaseMonthly();
      state = state.copyWith(isPro: isPro, isLoading: false, error: null);
      return isPro;
    } on PlatformException catch (e) {
      final isCancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      final message = isCancelled ? null : _friendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> purchasePlan(String packageId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isPro = await _service.purchasePackage(packageId);
      state = state.copyWith(isPro: isPro, isLoading: false, error: null);
      return isPro;
    } on PlatformException catch (e) {
      final isCancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      final message = isCancelled ? null : _friendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> showPaywall(BuildContext context) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isPro = await _service.showRevenueCatPaywall(context);
      state = state.copyWith(isPro: isPro, isLoading: false, error: null);
      return isPro;
    } on PlatformException catch (e) {
      final isCancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      final message = isCancelled ? null : _friendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> restore() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isPro = await _service.restore();
      state = state.copyWith(isPro: isPro, isLoading: false, error: null);
      return isPro;
    } on PlatformException catch (e) {
      final isCancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      final message = isCancelled ? null : _friendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  String _friendlyError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return 'ネットワーク接続を確認してください。';
    }
    if (msg.contains('payment') || msg.contains('purchase')) {
      return '購入処理に失敗しました。再度お試しください。';
    }
    if (msg.contains('restricted') || msg.contains('denied')) {
      return '購入が制限されています。設定をご確認ください。';
    }
    return '処理に失敗しました。時間をおいて再度お試しください。';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final config = ref.watch(appConfigProvider);
  return SubscriptionNotifier(SubscriptionService(config: config));
});
