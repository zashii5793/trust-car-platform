import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 利用者の最初の7日の段階（プロダクト評価 2026-09-29 改善 #6）。
///
/// 登録（`sign_up`）のあと、この順に進むと価値が伝わる、という想定の道筋。
/// Firebase Analytics の `first_week_step` イベントの `step` に入る。
enum FirstWeekStep {
  vehicleAdded('vehicle_added'),
  pastRecordsImported('past_records_imported'),
  modelCostViewed('model_cost_viewed'),
  shopLinked('shop_linked');

  const FirstWeekStep(this.eventValue);

  /// イベントに載せる名前。**変えない**（変えると過去のファネルとつながらなくなる）。
  final String eventValue;
}

/// Tracks KPI events to Firebase Analytics.
///
/// In debug mode analytics calls are no-ops so local/emulator runs stay clean.
/// Use [AnalyticsService.forTesting()] in unit tests to bypass Firebase init.
class AnalyticsService {
  final FirebaseAnalytics? _analytics;

  /// テストで送った中身を受け取るためのもの。本番では null。
  final void Function(String name, Map<String, Object>? params)? _onLog;

  final DateTime Function() _clock;

  /// アカウントの作成日時。分からなければ null。
  final DateTime? Function() _accountCreatedAt;

  AnalyticsService()
      : _analytics = kReleaseMode ? FirebaseAnalytics.instance : null,
        _onLog = null,
        _clock = DateTime.now,
        _accountCreatedAt = _currentUserCreatedAt;

  /// Named constructor for unit tests — skips Firebase initialization.
  @visibleForTesting
  AnalyticsService.forTesting({
    void Function(String name, Map<String, Object>? params)? onLog,
    DateTime Function()? clock,
    DateTime? Function()? accountCreatedAt,
  })  : _analytics = null,
        _onLog = onLog,
        _clock = clock ?? DateTime.now,
        _accountCreatedAt = accountCreatedAt ?? (() => null);

  static DateTime? _currentUserCreatedAt() {
    try {
      return FirebaseAuth.instance.currentUser?.metadata.creationTime;
    } catch (_) {
      // Firebase が初期化されていない（テスト・一部のデバッグ起動）
      return null;
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    _onLog?.call(name, params);
    final a = _analytics;
    if (a == null) return;
    await a.logEvent(name: name, parameters: params);
  }

  // ---------------------------------------------------------------------------
  // First week（最初の7日）
  // ---------------------------------------------------------------------------

  /// 最初の7日の段階に着いたことを送る。
  ///
  /// `days_since_signup` は登録からの経過日数（切り捨て。分からなければ -1）、
  /// `within_7_days` は 7日以内なら 1。Analytics のパラメータは真偽値を
  /// 持てないので数値で送る。何度呼んでもよい（ファネルは初回で数える）。
  Future<void> trackFirstWeekStep(FirstWeekStep step) {
    final created =
        _analytics == null && _onLog == null ? null : _accountCreatedAt();
    final int days;
    if (created == null) {
      days = -1;
    } else {
      final elapsed = _clock().difference(created).inDays;
      // 端末の時計がずれていても負の日数は送らない
      days = elapsed < 0 ? 0 : elapsed;
    }
    return _log('first_week_step', {
      'step': step.eventValue,
      'days_since_signup': days,
      'within_7_days': (days >= 0 && days <= 7) ? 1 : 0,
    });
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
