import 'package:flutter/foundation.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/user_plan.dart';
import '../services/revenue_cat_service.dart';
import '../services/user_subscription_service.dart';

/// Manages the current user's B2C subscription plan state.
///
/// Populated from [AppUser] data after authentication resolves.
/// Plan fields are read-only on the client — updated by Cloud Functions only.
class UserSubscriptionProvider with ChangeNotifier {
  final UserSubscriptionService _service;
  final RevenueCatService _revenueCatService;

  UserPlanType _planType = UserPlanType.free;
  DateTime? _planExpiresAt;

  UserSubscriptionProvider({
    UserSubscriptionService? service,
    RevenueCatService? revenueCatService,
  })  : _service = service ?? const UserSubscriptionService(),
        _revenueCatService = revenueCatService ?? RevenueCatService();

  UserPlanType get planType => _planType;
  DateTime? get planExpiresAt => _planExpiresAt;

  bool get isPremium =>
      UserSubscriptionService.isPremium(_planType, _planExpiresAt);

  UserPlanLimits get limits => _service.limitsFor(_planType);

  bool get canExportPdf => limits.canExportPdf;

  int get maxMonthlyInquiries => limits.maxMonthlyInquiries;

  int get driveLogRetentionDays => limits.driveLogRetentionDays;

  /// Called after auth resolves to sync plan state from the user document.
  void loadFromUser(UserPlanType planType, DateTime? planExpiresAt) {
    _planType = planType;
    _planExpiresAt = planExpiresAt;
    notifyListeners();
  }

  /// Resets to free on sign-out.
  void clear() {
    _planType = UserPlanType.free;
    _planExpiresAt = null;
    notifyListeners();
  }

  /// Starts the B2C premium purchase flow via RevenueCat.
  Future<Result<PurchaseResult, AppError>> purchasePremium({
    required String userId,
  }) {
    return _revenueCatService.purchaseUserPremium(userId: userId);
  }
}
