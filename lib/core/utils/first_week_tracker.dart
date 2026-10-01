import 'dart:async';

import '../../services/analytics_service.dart';
import '../di/service_locator.dart';

/// 画面から最初の7日の段階を送る（プロダクト評価 2026-09-29 改善 #6）。
///
/// 送れなくても画面の動きは止めない。`AnalyticsService` が登録されていない
/// （単体テストで ServiceLocator を組んでいない）ときは何もしない。
void trackFirstWeekStep(FirstWeekStep step) {
  if (!sl.isRegistered<AnalyticsService>()) return;
  unawaited(
    sl.get<AnalyticsService>().trackFirstWeekStep(step).catchError((_) {}),
  );
}
