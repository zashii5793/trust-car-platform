import '../models/vehicle.dart';
import '../models/maintenance_record.dart';

/// A single scheduled maintenance task with its recommended service interval.
class ScheduledMaintenance {
  final MaintenanceType type;
  final int? intervalKm;
  final int? intervalMonths;
  final String description;

  const ScheduledMaintenance({
    required this.type,
    this.intervalKm,
    this.intervalMonths,
    required this.description,
  });
}

/// Generates the standard maintenance schedule for a vehicle based on its
/// fuel type and current mileage, similar to Carsensor/Goo-net specs.
class MaintenanceScheduleService {
  const MaintenanceScheduleService();

  /// Returns a deduplicated list of recommended maintenance items for [vehicle].
  List<ScheduledMaintenance> generateSchedule(Vehicle vehicle) {
    final fuelType = vehicle.fuelType;
    final items = <ScheduledMaintenance>[];

    final isElectric =
        fuelType == FuelType.electric || fuelType == FuelType.hydrogen;
    final isHybrid = fuelType == FuelType.hybrid || fuelType == FuelType.phev;
    final isDiesel = fuelType == FuelType.diesel;

    if (!isElectric) {
      // Oil change interval varies by fuel type
      if (isHybrid) {
        items.add(const ScheduledMaintenance(
          type: MaintenanceType.oilChange,
          intervalKm: 10000,
          intervalMonths: 12,
          description: 'ハイブリッドはエンジン使用頻度が低いため年1回が目安',
        ));
      } else if (isDiesel) {
        items.add(const ScheduledMaintenance(
          type: MaintenanceType.oilChange,
          intervalKm: 5000,
          intervalMonths: 3,
          description: 'ディーゼルはオイル劣化が早いため3ヶ月毎を推奨',
        ));
      } else {
        // gasoline (default for null fuelType too)
        items.add(const ScheduledMaintenance(
          type: MaintenanceType.oilChange,
          intervalKm: 5000,
          intervalMonths: 6,
          description: '5,000km毎または6ヶ月毎（早い方）',
        ));
      }

      items.addAll(const [
        ScheduledMaintenance(
          type: MaintenanceType.oilFilterChange,
          intervalKm: 10000,
          intervalMonths: 12,
          description: 'オイル交換2回に1回を目安に交換',
        ),
        ScheduledMaintenance(
          type: MaintenanceType.airFilterChange,
          intervalKm: 30000,
          intervalMonths: 24,
          description: '吸気効率と燃費を維持するため定期交換',
        ),
        ScheduledMaintenance(
          type: MaintenanceType.transmissionFluidChange,
          intervalKm: 40000,
          intervalMonths: 48,
          description: 'ATF/CVTフルードはメーカー指定周期で交換',
        ),
      ]);
    }

    // Universal items — every vehicle regardless of fuel type
    items.addAll(const [
      ScheduledMaintenance(
        type: MaintenanceType.carInspection,
        intervalMonths: 24,
        description: '法定車検（初回3年、以降2年ごと）',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.legalInspection12,
        intervalMonths: 12,
        description: '12ヶ月定期点検（道路運送車両法による義務）',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.tireRotation,
        intervalKm: 10000,
        intervalMonths: 6,
        description: 'タイヤ偏摩耗防止・寿命延長のため前後ローテーション',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.batteryChange,
        intervalMonths: 36,
        description: 'バッテリー交換（3〜5年が交換の目安）',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.brakePadChange,
        intervalKm: 30000,
        description: 'ブレーキパッド残量3mm以下で要交換',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.coolantChange,
        intervalMonths: 24,
        description: '冷却水（LLC）は2年毎または車検時に交換',
      ),
      ScheduledMaintenance(
        type: MaintenanceType.cabinFilterChange,
        intervalMonths: 12,
        description: '花粉・PM2.5対応フィルターは年1回交換推奨',
      ),
    ]);

    return items;
  }

  /// Returns the next recommended service mileage for [item] given the
  /// vehicle's current [vehicle.mileage].  Returns null if [item] has no
  /// km-based interval.
  int? nextDueMileage(Vehicle vehicle, ScheduledMaintenance item) {
    if (item.intervalKm == null) return null;
    final intervals = (vehicle.mileage / item.intervalKm!).ceil();
    // If mileage is exactly a multiple, next due is the next interval
    final base = intervals * item.intervalKm!;
    return base <= vehicle.mileage ? base + item.intervalKm! : base;
  }
}
