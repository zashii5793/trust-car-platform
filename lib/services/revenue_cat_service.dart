import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';

// ---------------------------------------------------------------------------
// Value objects returned by executor functions
// ---------------------------------------------------------------------------

class PurchaseResult {
  final bool isSuccess;
  final String productId;

  const PurchaseResult({required this.isSuccess, required this.productId});
}

class RestoreResult {
  final List<String> activeEntitlements;

  const RestoreResult({required this.activeEntitlements});
}

// ---------------------------------------------------------------------------
// Executor typedefs (injectable for testability)
// ---------------------------------------------------------------------------

typedef InitializeExecutor = Future<void> Function(String userId);
typedef PurchaseExecutor = Future<PurchaseResult> Function(
    String productId, String userId);
typedef RestoreExecutor = Future<RestoreResult> Function(String userId);
typedef EntitlementExecutor = Future<List<String>> Function(String userId);

// ---------------------------------------------------------------------------
// RevenueCatService
// ---------------------------------------------------------------------------

/// Service for RevenueCat BtoB subscription purchase flow.
///
/// All platform calls are injected via executor functions so business logic is
/// fully unit-testable without the native SDK.
///
/// Production usage: pass no arguments — production executors that call
/// `Purchases.*` are used automatically.
/// Test usage: inject fake executors to control responses.
class RevenueCatService {
  /// Resolves the platform-specific RevenueCat public API key from the
  /// environment instead of hard-coding it in the binary.
  ///
  /// Resolution order (first non-empty wins):
  ///   1. `--dart-define` compile-time value
  ///      (`REVENUE_CAT_API_KEY_IOS` / `REVENUE_CAT_API_KEY_ANDROID`)
  ///   2. `.env` runtime value via flutter_dotenv (same keys)
  ///
  /// Returns an empty string when unset so callers can fail gracefully.
  static String get apiKey {
    final useIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    const iosDefine = String.fromEnvironment('REVENUE_CAT_API_KEY_IOS');
    const androidDefine = String.fromEnvironment('REVENUE_CAT_API_KEY_ANDROID');
    final fromDefine = useIos ? iosDefine : androidDefine;
    if (fromDefine.isNotEmpty) return fromDefine;

    final envKey =
        useIos ? 'REVENUE_CAT_API_KEY_IOS' : 'REVENUE_CAT_API_KEY_ANDROID';
    return dotenv.env[envKey] ?? '';
  }

  // Entitlement IDs (must match RevenueCat dashboard configuration)
  static const _entitlementStandard = 'btob_standard';
  static const _entitlementPremium = 'btob_premium';
  static const _entitlementEnterprise = 'btob_enterprise';
  static const _entitlementBtocPremium = 'btoc_premium';

  // Product IDs (must match App Store / Google Play listings)
  static const _productStandard = 'trustcar_btob_standard_monthly';
  static const _productPremium = 'trustcar_btob_premium_monthly';
  static const _productEnterprise = 'trustcar_btob_enterprise_monthly';
  static const _productBtocPremium = 'trustcar_btoc_premium_monthly';

  /// B2C premium product ID for RevenueCat dashboard reference.
  static String get btocPremiumProductId => _productBtocPremium;

  /// B2C premium entitlement ID for RevenueCat dashboard reference.
  static String get btocPremiumEntitlementId => _entitlementBtocPremium;

  final InitializeExecutor _initializeExecutor;
  final PurchaseExecutor _purchaseExecutor;
  final RestoreExecutor _restoreExecutor;
  final EntitlementExecutor _entitlementExecutor;

  RevenueCatService({
    InitializeExecutor? initializeExecutor,
    PurchaseExecutor? purchaseExecutor,
    RestoreExecutor? restoreExecutor,
    EntitlementExecutor? entitlementExecutor,
  })  : _initializeExecutor = initializeExecutor ?? _productionInitialize,
        _purchaseExecutor = purchaseExecutor ?? _productionPurchase,
        _restoreExecutor = restoreExecutor ?? _productionRestore,
        _entitlementExecutor = entitlementExecutor ?? _productionEntitlements;

  // ---------------------------------------------------------------------------
  // Static helpers (pure, fully testable)
  // ---------------------------------------------------------------------------

  /// Returns the RevenueCat product ID for the given plan, or null for free.
  static String? productIdFor(ShopPlanType plan) {
    return switch (plan) {
      ShopPlanType.standard => _productStandard,
      ShopPlanType.premium => _productPremium,
      ShopPlanType.enterprise => _productEnterprise,
      ShopPlanType.free => null,
    };
  }

  /// Returns the ShopPlanType corresponding to a RevenueCat entitlement ID.
  static ShopPlanType planTypeFromEntitlement(String entitlementId) {
    return switch (entitlementId) {
      _entitlementStandard => ShopPlanType.standard,
      _entitlementPremium => ShopPlanType.premium,
      _entitlementEnterprise => ShopPlanType.enterprise,
      _ => ShopPlanType.free,
    };
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Configures the RevenueCat SDK for the authenticated user.
  Future<Result<void, AppError>> initialize(String userId) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }
    try {
      await _initializeExecutor(userId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
          AppError.server('RevenueCat initialization failed: $e'));
    }
  }

  /// Starts the purchase flow for the given plan.
  ///
  /// Returns failure immediately if [plan] is free.
  Future<Result<PurchaseResult, AppError>> purchasePlan(
    ShopPlanType plan, {
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    final productId = productIdFor(plan);
    if (productId == null) {
      return const Result.failure(
        AppError.validation(
          'Cannot purchase free plan',
          field: 'planType',
        ),
      );
    }

    try {
      final purchaseResult = await _purchaseExecutor(productId, userId);
      if (!purchaseResult.isSuccess) {
        return const Result.failure(
          AppError.server('Purchase was not completed'),
        );
      }
      return Result.success(purchaseResult);
    } catch (e) {
      return Result.failure(AppError.server('Purchase failed: $e'));
    }
  }

  /// Restores previous purchases for the user.
  Future<Result<RestoreResult, AppError>> restorePurchases({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    try {
      final result = await _restoreExecutor(userId);
      return Result.success(result);
    } catch (e) {
      return Result.failure(AppError.server('Restore purchases failed: $e'));
    }
  }

  /// Starts the B2C individual premium purchase flow.
  Future<Result<PurchaseResult, AppError>> purchaseUserPremium({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }
    try {
      final purchaseResult =
          await _purchaseExecutor(_productBtocPremium, userId);
      if (!purchaseResult.isSuccess) {
        return const Result.failure(
          AppError.server('Purchase was not completed'),
        );
      }
      return Result.success(purchaseResult);
    } catch (e) {
      return Result.failure(AppError.server('Purchase failed: $e'));
    }
  }

  /// Returns the list of active entitlement identifiers for the user.
  Future<Result<List<String>, AppError>> getActiveEntitlements({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    try {
      final entitlements = await _entitlementExecutor(userId);
      return Result.success(entitlements);
    } catch (e) {
      return Result.failure(
          AppError.server('Failed to fetch entitlements: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Production executors (wrapped in static methods for clean assignment)
  // ---------------------------------------------------------------------------

  static Future<void> _productionInitialize(String userId) async {
    final key = apiKey;
    if (key.isEmpty) {
      throw StateError(
        'RevenueCat API key is not set. Provide REVENUE_CAT_API_KEY_IOS / '
        'REVENUE_CAT_API_KEY_ANDROID via --dart-define or a bundled .env file.',
      );
    }
    final config = PurchasesConfiguration(key)..appUserID = userId;
    await Purchases.configure(config);
  }

  static Future<PurchaseResult> _productionPurchase(
    String productId,
    String userId,
  ) async {
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? [];
    final package = packages.firstWhere(
      (p) => p.storeProduct.identifier == productId,
      orElse: () =>
          throw Exception('Product $productId not found in offerings'),
    );
    // purchasePackage throws PurchasesError on cancellation or failure.
    await Purchases.purchasePackage(package);
    return PurchaseResult(isSuccess: true, productId: productId);
  }

  static Future<RestoreResult> _productionRestore(String userId) async {
    final customerInfo = await Purchases.restorePurchases();
    final entitlements = customerInfo.entitlements.active.keys.toList();
    return RestoreResult(activeEntitlements: entitlements);
  }

  static Future<List<String>> _productionEntitlements(String userId) async {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.keys.toList();
  }
}
