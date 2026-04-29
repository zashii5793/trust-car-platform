import 'package:flutter/foundation.dart';
import '../core/error/app_error.dart';
import '../models/shop.dart';
import '../services/shop_subscription_service.dart';

/// BtoB shop subscription state management.
///
/// Holds the current shop's plan and exposes limit-check helpers.
class SubscriptionProvider with ChangeNotifier {
  final ShopSubscriptionService _subscriptionService;

  SubscriptionProvider({required ShopSubscriptionService subscriptionService})
      : _subscriptionService = subscriptionService;

  ShopPlanType _planType = ShopPlanType.free;
  ShopSubscriptionStatus _subscriptionStatus = ShopSubscriptionStatus.free;
  DateTime? _planExpiresAt;
  bool _isLoading = false;
  AppError? _error;
  String? _currentShopId;

  ShopPlanType get planType => _planType;
  ShopSubscriptionStatus get subscriptionStatus => _subscriptionStatus;
  DateTime? get planExpiresAt => _planExpiresAt;
  bool get isLoading => _isLoading;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;

  /// Current plan limits (based on active plan and subscription status).
  ShopPlanLimits get currentLimits => _subscriptionService.getPlanLimits(_effectivePlan);

  ShopPlanType get _effectivePlan {
    if (_subscriptionStatus == ShopSubscriptionStatus.active ||
        _subscriptionStatus == ShopSubscriptionStatus.trialing) {
      return _planType;
    }
    return ShopPlanType.free;
  }

  bool get hasUnlimitedInquiries => currentLimits.maxMonthlyInquiries < 0;
  bool get hasPriorityDisplay => currentLimits.hasPriorityDisplay;
  bool get hasMonthlyReport => currentLimits.hasMonthlyReport;

  /// Load subscription state from the given shop document.
  void loadFromShop(Shop shop) {
    _currentShopId = shop.id;
    _planType = shop.planType;
    _subscriptionStatus = shop.subscriptionStatus;
    _planExpiresAt = shop.planExpiresAt;
    _error = null;
    notifyListeners();
  }

  /// Check whether the shop can receive one more inquiry this month.
  Future<bool> canReceiveInquiry() async {
    if (_currentShopId == null) {
      return false;
    }
    final result = await _subscriptionService.canReceiveInquiry(_currentShopId!);
    return result.valueOrNull ?? false;
  }

  /// Check whether the shop can add one more photo.
  Future<bool> canAddPhoto(int currentCount) async {
    if (_currentShopId == null) {
      return false;
    }
    final result = await _subscriptionService.canAddPhoto(
      _currentShopId!,
      currentCount: currentCount,
    );
    return result.valueOrNull ?? false;
  }

  /// Update the shop's subscription plan.
  Future<bool> updatePlan({
    required String shopId,
    required ShopPlanType newPlan,
    required ShopSubscriptionStatus subscriptionStatus,
    DateTime? expiresAt,
    String? revenueCatUserId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _subscriptionService.updatePlan(
      shopId,
      newPlan: newPlan,
      subscriptionStatus: subscriptionStatus,
      expiresAt: expiresAt,
      revenueCatUserId: revenueCatUserId,
    );

    _isLoading = false;

    return result.when(
      success: (_) {
        _planType = newPlan;
        _subscriptionStatus = subscriptionStatus;
        _planExpiresAt = expiresAt;
        notifyListeners();
        return true;
      },
      failure: (err) {
        _error = err;
        notifyListeners();
        return false;
      },
    );
  }

  void clearShop() {
    _currentShopId = null;
    _planType = ShopPlanType.free;
    _subscriptionStatus = ShopSubscriptionStatus.free;
    _planExpiresAt = null;
    _error = null;
    notifyListeners();
  }
}
