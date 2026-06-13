/// 法人・複数台管理（フリート）プラン定義
///
/// 価格設計の根拠:
/// - 国内の車両管理SaaSはデバイス連携型で1台あたり月額数千円が相場。
///   本アプリはソフトのみの軽量管理なので、SMBが稟議なしで決裁できる
///   価格帯（月額5,000円以下）を狙う。
/// - フリート（5〜20台）: 月額4,980円 → 1台あたり249〜996円で割安感。
/// - ビジネス（21〜50台）: 月額9,800円 → 既存BtoBプレミアムと同価格で整合。
///
/// ローンチ戦略: [isPromotionalFreePeriod] が true の間は全機能を無料開放し、
/// UI には「現在無料開放中（正式リリース後 月額¥4,980〜）」と将来価格を
/// 明示して、有料化時の期待値ギャップを防ぐ。
class FleetPlan {
  FleetPlan._(); // 静的メンバーのみ

  /// この台数までは個人プランと同じく無料（5台以上で法人プラン対象）。
  static const int freeVehicleLimit = 4;

  /// フリートプラン（5〜20台）月額（円）
  static const int fleetMonthlyPrice = 4980;
  static const int fleetVehicleLimit = 20;

  /// ビジネスプラン（21〜50台）月額（円）
  static const int businessMonthlyPrice = 9800;
  static const int businessVehicleLimit = 50;

  /// ローンチ期の無料開放フラグ。
  /// 課金開始時に false へ切り替える（サーバー設定化は課金実装時に検討）。
  static const bool isPromotionalFreePeriod = true;

  /// 台数が有料プラン対象か（無料開放期間かどうかとは独立に判定）
  static bool requiresPaidPlan(int vehicleCount) =>
      vehicleCount > freeVehicleLimit;

  /// 台数に応じた月額（円）。無料枠内・50台超（個別見積もり）は null。
  static int? monthlyPriceFor(int vehicleCount) {
    if (vehicleCount <= freeVehicleLimit) return null;
    if (vehicleCount <= fleetVehicleLimit) return fleetMonthlyPrice;
    if (vehicleCount <= businessVehicleLimit) return businessMonthlyPrice;
    return null; // エンタープライズ（個別見積もり）
  }

  /// 台数に応じたプラン表示名
  static String planLabelFor(int vehicleCount) {
    if (vehicleCount <= freeVehicleLimit) return 'フリー';
    if (vehicleCount <= fleetVehicleLimit) return 'フリート';
    if (vehicleCount <= businessVehicleLimit) return 'ビジネス';
    return 'エンタープライズ';
  }

  /// 今この台数で課金が発生するか（無料開放期間中は常に false）
  static bool isBillableNow(int vehicleCount) =>
      !isPromotionalFreePeriod && requiresPaidPlan(vehicleCount);
}
