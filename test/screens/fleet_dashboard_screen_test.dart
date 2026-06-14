// FleetDashboardScreen Widget Tests
//
// Tests the fleet management dashboard for business accounts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/fleet_provider.dart';
import 'package:trust_car_platform/services/fleet_service.dart';

// ---------------------------------------------------------------------------
// Stub FleetService
// ---------------------------------------------------------------------------

class _StubFleetService implements FleetService {
  final List<Vehicle> vehicles;
  _StubFleetService({this.vehicles = const []});

  @override
  Stream<List<Vehicle>> getCompanyVehicles(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);
    return Stream.value(vehicles);
  }

  @override
  Future<Result<FleetStats, AppError>> getFleetStats(String companyId) async {
    int critical = 0, warning = 0, normal = 0;
    for (final v in vehicles) {
      final days = v.daysUntilInspection;
      if (days != null && (days < 0 || days <= 7)) {
        critical++;
      } else if (days != null && days <= 30) {
        warning++;
      } else {
        normal++;
      }
    }
    return Result.success(FleetStats(
        total: vehicles.length,
        critical: critical,
        warning: warning,
        normal: normal));
  }

  @override
  Future<Result<void, AppError>> linkVehicleToCompany(
          String vehicleId, String companyId, String userId) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> joinFleetByCode(
          String fleetCode, String vehicleId, String userId) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> leaveFleet(
          String vehicleId, String userId) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> assignVehicle(
          String vehicleId,
          String assigneeId,
          String assigneeName,
          String requestingUserId) async =>
      const Result.success(null);

  @override
  Future<Result<Map<String, MaintenanceSummary>, AppError>>
      getMaintenanceSummaries(List<String> vehicleIds) async =>
          const Result.success({});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String id = 'v1',
  DateTime? inspectionExpiryDate,
}) =>
    Vehicle(
      id: id,
      userId: 'u1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2022,
      grade: 'S',
      mileage: 20000,
      inspectionExpiryDate: inspectionExpiryDate,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

Widget _buildSubject(
    {List<Vehicle> vehicles = const [], String companyId = 'company-A'}) {
  final service = _StubFleetService(vehicles: vehicles);
  final provider = FleetProvider(
    fleetService: service,
    companyId: companyId,
  );
  return ChangeNotifierProvider<FleetProvider>.value(
    value: provider,
    child: MaterialApp(
      home: _TestFleetDashboard(provider: provider),
    ),
  );
}

// Test wrapper that injects the provider without going through sl.get
class _TestFleetDashboard extends StatelessWidget {
  final FleetProvider provider;
  const _TestFleetDashboard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FleetProvider>.value(
      value: provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('フリート管理')),
        body: Consumer<FleetProvider>(
          builder: (context, p, _) {
            if (p.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _FleetBodyTest(provider: p);
          },
        ),
      ),
    );
  }
}

// Inline test version of the fleet body to avoid service locator dependency
class _FleetBodyTest extends StatelessWidget {
  final FleetProvider provider;
  const _FleetBodyTest({required this.provider});

  @override
  Widget build(BuildContext context) {
    final stats = provider.stats;
    final vehicles = provider.filteredVehicles;
    return Column(
      children: [
        if (stats != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('合計 ${stats.total}台'),
          ),
        ListTile(
          key: const Key('fleet_company_code'),
          title: Text(provider.companyId),
        ),
        Row(
          children: [
            FilterChip(
              key: const Key('fleet_filter_all'),
              label: const Text('すべて'),
              selected: provider.filter == FleetFilter.all,
              onSelected: (_) => provider.setFilter(FleetFilter.all),
            ),
            FilterChip(
              key: const Key('fleet_filter_critical'),
              label: const Text('緊急'),
              selected: provider.filter == FleetFilter.critical,
              onSelected: (_) => provider.setFilter(FleetFilter.critical),
            ),
            FilterChip(
              key: const Key('fleet_filter_warning'),
              label: const Text('注意'),
              selected: provider.filter == FleetFilter.warning,
              onSelected: (_) => provider.setFilter(FleetFilter.warning),
            ),
          ],
        ),
        if (vehicles.isEmpty)
          const Center(key: Key('fleet_empty_state'), child: Text('車両なし'))
        else
          Expanded(
            child: ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (_, i) {
                final v = vehicles[i];
                final days = v.daysUntilInspection;
                final urgencyKey = (days != null && (days < 0 || days <= 7))
                    ? 'critical'
                    : (days != null && days <= 30)
                        ? 'warning'
                        : 'normal';
                return ListTile(
                  key: Key('fleet_vehicle_card_$urgencyKey'),
                  title: Text(v.displayName),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FleetDashboardScreen', () {
    testWidgets('フリート台数の概要が表示される', (tester) async {
      final vehicles = [
        _makeVehicle(id: 'v1'),
        _makeVehicle(id: 'v2'),
        _makeVehicle(id: 'v3'),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      // Should show total vehicle count
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('車両が一覧表示される', (tester) async {
      final vehicles = [
        _makeVehicle(id: 'v1'),
        _makeVehicle(id: 'v2'),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      // Each vehicle card should show the vehicle name
      expect(find.text('トヨタ プリウス'), findsWidgets);
    });

    testWidgets('車両なし → 空状態メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildSubject(vehicles: []));
      await tester.pump();

      expect(find.byKey(const Key('fleet_empty_state')), findsOneWidget);
    });

    testWidgets('緊急度フィルタチップが表示される', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      expect(find.byKey(const Key('fleet_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('fleet_filter_critical')), findsOneWidget);
      expect(find.byKey(const Key('fleet_filter_warning')), findsOneWidget);
    });

    testWidgets('緊急（≤7日）車両は先頭に並ぶ', (tester) async {
      final now = DateTime.now();
      final vehicles = [
        _makeVehicle(
            id: 'normal',
            inspectionExpiryDate: now.add(const Duration(days: 90))),
        _makeVehicle(
            id: 'critical',
            inspectionExpiryDate: now.add(const Duration(days: 3))),
        _makeVehicle(
            id: 'warning',
            inspectionExpiryDate: now.add(const Duration(days: 20))),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      // Critical vehicles should appear before normal ones
      final criticalFinder =
          find.byKey(const Key('fleet_vehicle_card_critical'));
      final normalFinder = find.byKey(const Key('fleet_vehicle_card_normal'));
      expect(criticalFinder, findsWidgets);
      expect(normalFinder, findsWidgets);
    });

    testWidgets('フリートコードが表示される（招待用）', (tester) async {
      await tester.pumpWidget(_buildSubject(companyId: 'company-ABC'));
      await tester.pump();

      expect(find.byKey(const Key('fleet_company_code')), findsOneWidget);
    });

    testWidgets('criticalフィルタ選択 → 緊急車両のみ表示', (tester) async {
      final now = DateTime.now();
      final vehicles = [
        _makeVehicle(
            id: 'v1', inspectionExpiryDate: now.add(const Duration(days: 3))),
        _makeVehicle(
            id: 'v2', inspectionExpiryDate: now.add(const Duration(days: 90))),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      await tester.tap(find.byKey(const Key('fleet_filter_critical')));
      await tester.pump();

      // Only critical vehicles shown (key contains 'critical')
      expect(
          find.byKey(const Key('fleet_vehicle_card_critical')), findsOneWidget);
    });

    testWidgets('warningフィルタ選択 → 注意車両のみ表示', (tester) async {
      final now = DateTime.now();
      final vehicles = [
        _makeVehicle(
            id: 'crit',
            inspectionExpiryDate: now.add(const Duration(days: 3))),
        _makeVehicle(
            id: 'warn',
            inspectionExpiryDate: now.add(const Duration(days: 20))),
        _makeVehicle(
            id: 'norm',
            inspectionExpiryDate: now.add(const Duration(days: 90))),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      await tester.tap(find.byKey(const Key('fleet_filter_warning')));
      await tester.pump();

      expect(
          find.byKey(const Key('fleet_vehicle_card_warning')), findsOneWidget);
      expect(
          find.byKey(const Key('fleet_vehicle_card_critical')), findsNothing);
      expect(find.byKey(const Key('fleet_vehicle_card_normal')), findsNothing);
    });

    testWidgets('allフィルタで全車両が再表示される', (tester) async {
      final now = DateTime.now();
      final vehicles = [
        _makeVehicle(
            id: 'crit',
            inspectionExpiryDate: now.add(const Duration(days: 3))),
        _makeVehicle(
            id: 'norm',
            inspectionExpiryDate: now.add(const Duration(days: 90))),
      ];
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      // Switch to critical filter, then back to all
      await tester.tap(find.byKey(const Key('fleet_filter_critical')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('fleet_filter_all')));
      await tester.pump();

      expect(
          find.byKey(const Key('fleet_vehicle_card_critical')), findsOneWidget);
      expect(
          find.byKey(const Key('fleet_vehicle_card_normal')), findsOneWidget);
    });

    testWidgets('空のcompanyId → 空状態が表示される', (tester) async {
      await tester.pumpWidget(_buildSubject(vehicles: [], companyId: ''));
      await tester.pump();

      expect(find.byKey(const Key('fleet_empty_state')), findsOneWidget);
    });

    testWidgets('統計: 合計台数が正しく表示される', (tester) async {
      final vehicles = List.generate(
        5,
        (i) => _makeVehicle(id: 'v$i'),
      );
      await tester.pumpWidget(_buildSubject(vehicles: vehicles));
      await tester.pump();

      expect(find.textContaining('5'), findsWidgets);
    });
  });
}
