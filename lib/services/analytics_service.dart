import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Tracks KPI events to Firebase Analytics.
///
/// In debug mode analytics calls are no-ops so local/emulator runs stay clean.
/// Use [AnalyticsService.forTesting()] in unit tests to bypass Firebase init.
class AnalyticsService {
  final FirebaseAnalytics? _analytics;

  AnalyticsService()
      : _analytics = kReleaseMode ? FirebaseAnalytics.instance : null;

  /// Named constructor for unit tests — skips Firebase initialization.
  @visibleForTesting
  AnalyticsService.forTesting() : _analytics = null;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    final a = _analytics;
    if (a == null) return;
    await a.logEvent(name: name, parameters: params);
  }

  // ---------------------------------------------------------------------------
  // User events
  // ---------------------------------------------------------------------------

  Future<void> trackLogin(String method) => _log('login', {'method': method});

  Future<void> trackSignup(String method) =>
      _log('sign_up', {'method': method});

  Future<void> setUserId(String? uid) async {
    final a = _analytics;
    if (a == null) return;
    await a.setUserId(id: uid);
  }

  // ---------------------------------------------------------------------------
  // Vehicle events
  // ---------------------------------------------------------------------------

  Future<void> trackVehicleAdded() => _log('vehicle_added');

  Future<void> trackVehicleOcrUsed() => _log('vehicle_ocr_used');

  // ---------------------------------------------------------------------------
  // Maintenance events
  // ---------------------------------------------------------------------------

  Future<void> trackMaintenanceRecorded(String type) =>
      _log('maintenance_recorded', {'type': type});

  Future<void> trackDriveLogged(double distanceKm) =>
      _log('drive_logged', {'distance_km': distanceKm});

  // ---------------------------------------------------------------------------
  // AI recommendation events
  // ---------------------------------------------------------------------------

  Future<void> trackRecommendationViewed(String recommendationType) =>
      _log('recommendation_viewed', {'type': recommendationType});

  Future<void> trackRecommendationActioned() => _log('recommendation_actioned');

  // ---------------------------------------------------------------------------
  // Shop events
  // ---------------------------------------------------------------------------

  Future<void> trackShopViewed(String shopId) =>
      _log('shop_viewed', {'shop_id': shopId});

  Future<void> trackInquirySent(String shopId) =>
      _log('inquiry_sent', {'shop_id': shopId});

  // ---------------------------------------------------------------------------
  // Screen view
  // ---------------------------------------------------------------------------

  Future<void> trackScreenView(String screenName) =>
      _log('screen_view', {'screen_name': screenName});
}
