// FleetProvider Unit Tests
//
// Tests filtered vehicle list, urgency-based sorting, loading/error states,
// and filter switching. Uses a fake FleetService backed by a StreamController.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/fleet_provider.dart';
import 'package:trust_car_platform/services/fleet_service.dart';

// ---------------------------------------------------------------------------
// Fake FleetService
// ---------------------------------------------------------------------------

class _FakeFleetService implements FleetService {
  final StreamController<List<Vehicle>> _controller =
      StreamController<List<Vehicle>>.broadcast();

  FleetStats _stats = const FleetStats(
    total: 0,
    critical: 0,
    warning: 0,
    normal: 0,
  );
  bool _statsFailure = false;

  void emit(List<Vehicle> vehicles) => _controller.add(vehicles);
  void emitError(Object error) => _controller.addError(error);
  void setStats(FleetStats s) => _stats = s;
  void setStatsFailure() => _statsFailure = true;

  @override
  Stream<List<Vehicle>> getCompanyVehicles(String companyId) =>
      _controller.stream;

  @override
  Future<Result<FleetStats, AppError>> getFleetStats(String companyId) async {
    if (_statsFailure) {
      return Result.failure(AppError.unknown('stats error'));
    }
    return Result.success(_stats);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle(String id, {DateTime? inspectionExpiryDate}) => Vehicle(
      id: id,
      userId: 'company1',
      maker: 'Toyota',
      model: 'Prius',
      year: 2020,
      grade: 'S',
      mileage: 50000,
      inspectionExpiryDate: inspectionExpiryDate,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

Vehicle _critical(String id) =>
    _makeVehicle(id, inspectionExpiryDate: DateTime.now().add(const Duration(days: 3)));

Vehicle _warning(String id) =>
    _makeVehicle(id, inspectionExpiryDate: DateTime.now().add(const Duration(days: 20)));

Vehicle _normal(String id) =>
    _makeVehicle(id, inspectionExpiryDate: DateTime.now().add(const Duration(days: 90)));

Vehicle _noDate(String id) => _makeVehicle(id); // daysUntilInspection == null

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FleetProvider', () {
    late _FakeFleetService fakeService;
    late FleetProvider provider;

    setUp(() {
      fakeService = _FakeFleetService();
      provider = FleetProvider(
        fleetService: fakeService,
        companyId: 'company1',
      );
    });

    tearDown(() {
      provider.dispose();
    });

    group('初期状態', () {
      test('isLoading == true before first stream event', () {
        expect(provider.isLoading, isTrue);
      });

      test('allVehicles is empty', () {
        expect(provider.allVehicles, isEmpty);
      });

      test('filter is FleetFilter.all by default', () {
        expect(provider.filter, FleetFilter.all);
      });

      test('errorMessage is null', () {
        expect(provider.errorMessage, isNull);
      });
    });

    group('stream イベント', () {
      test('isLoading becomes false after first event', () async {
        fakeService.emit([_normal('v1')]);
        await Future<void>.delayed(Duration.zero);
        expect(provider.isLoading, isFalse);
      });

      test('allVehicles updated from stream', () async {
        final vehicles = [_normal('v1'), _warning('v2')];
        fakeService.emit(vehicles);
        await Future<void>.delayed(Duration.zero);
        expect(provider.allVehicles, hasLength(2));
      });

      test('stream error sets errorMessage', () async {
        fakeService.emitError(Exception('network error'));
        await Future<void>.delayed(Duration.zero);
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNotNull);
      });

      test('error message is 車両データの取得に失敗しました', () async {
        fakeService.emitError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        expect(provider.errorMessage, '車両データの取得に失敗しました');
      });
    });

    group('filteredVehicles — FleetFilter.all', () {
      test('returns all vehicles', () async {
        fakeService.emit([_critical('v1'), _warning('v2'), _normal('v3')]);
        await Future<void>.delayed(Duration.zero);
        expect(provider.filteredVehicles, hasLength(3));
      });

      test('sorted by urgency: critical first, then warning, then normal', () async {
        fakeService.emit([_normal('v3'), _critical('v1'), _warning('v2')]);
        await Future<void>.delayed(Duration.zero);
        final ids = provider.filteredVehicles.map((v) => v.id).toList();
        expect(ids, ['v1', 'v2', 'v3']);
      });

      test('vehicle with no date (none urgency) is sorted last', () async {
        fakeService.emit([_noDate('vN'), _normal('vA'), _critical('vC')]);
        await Future<void>.delayed(Duration.zero);
        final ids = provider.filteredVehicles.map((v) => v.id).toList();
        expect(ids.first, 'vC');
        expect(ids.last, 'vN');
      });
    });

    group('filteredVehicles — FleetFilter.critical', () {
      setUp(() async {
        fakeService.emit([_critical('c1'), _warning('w1'), _normal('n1'), _noDate('nd1')]);
        await Future<void>.delayed(Duration.zero);
        provider.setFilter(FleetFilter.critical);
      });

      test('returns only critical vehicles', () {
        final filtered = provider.filteredVehicles;
        expect(filtered, hasLength(1));
        expect(filtered.first.id, 'c1');
      });
    });

    group('filteredVehicles — FleetFilter.warning', () {
      setUp(() async {
        fakeService.emit([_critical('c1'), _warning('w1'), _warning('w2'), _normal('n1')]);
        await Future<void>.delayed(Duration.zero);
        provider.setFilter(FleetFilter.warning);
      });

      test('returns only warning vehicles', () {
        final ids = provider.filteredVehicles.map((v) => v.id).toSet();
        expect(ids, {'w1', 'w2'});
      });
    });

    group('filteredVehicles — FleetFilter.normal', () {
      setUp(() async {
        fakeService.emit([_critical('c1'), _normal('n1'), _noDate('nd1')]);
        await Future<void>.delayed(Duration.zero);
        provider.setFilter(FleetFilter.normal);
      });

      test('includes normal urgency vehicles', () {
        final ids = provider.filteredVehicles.map((v) => v.id).toSet();
        expect(ids.contains('n1'), isTrue);
      });

      test('includes no-date (none) vehicles', () {
        final ids = provider.filteredVehicles.map((v) => v.id).toSet();
        expect(ids.contains('nd1'), isTrue);
      });

      test('excludes critical vehicles', () {
        final ids = provider.filteredVehicles.map((v) => v.id).toSet();
        expect(ids.contains('c1'), isFalse);
      });
    });

    group('setFilter', () {
      test('switching filter notifies listeners', () async {
        fakeService.emit([_critical('v1')]);
        await Future<void>.delayed(Duration.zero);

        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.setFilter(FleetFilter.critical);
        expect(notifyCount, 1);
        expect(provider.filter, FleetFilter.critical);
      });

      test('setting same filter does NOT notify listeners', () async {
        fakeService.emit([_normal('v1')]);
        await Future<void>.delayed(Duration.zero);

        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.setFilter(FleetFilter.all); // already all
        expect(notifyCount, 0);
      });
    });

    group('refresh', () {
      test('updates stats on success', () async {
        fakeService.emit([_normal('v1')]);
        await Future<void>.delayed(Duration.zero);

        const expectedStats =
            FleetStats(total: 3, critical: 1, warning: 1, normal: 1);
        fakeService.setStats(expectedStats);

        await provider.refresh();

        expect(provider.stats?.total, 3);
        expect(provider.stats?.critical, 1);
      });

      test('stats remain unchanged on refresh failure', () async {
        fakeService.emit([_normal('v1')]);
        await Future<void>.delayed(Duration.zero);

        // Stats were set during the stream emission above
        final statsBefore = provider.stats;

        fakeService.setStatsFailure();
        await provider.refresh();

        // stats unchanged (the failure branch is a no-op)
        expect(provider.stats?.total, statsBefore?.total);
      });
    });

    group('Edge Cases', () {
      test('empty fleet returns empty filteredVehicles for all filters', () async {
        fakeService.emit([]);
        await Future<void>.delayed(Duration.zero);

        for (final f in FleetFilter.values) {
          provider.setFilter(f);
          expect(provider.filteredVehicles, isEmpty,
              reason: 'filter=$f should be empty');
        }
      });

      test('multiple stream events update state correctly', () async {
        fakeService.emit([_normal('v1')]);
        await Future<void>.delayed(Duration.zero);
        expect(provider.allVehicles, hasLength(1));

        fakeService.emit([_normal('v1'), _critical('v2')]);
        await Future<void>.delayed(Duration.zero);
        expect(provider.allVehicles, hasLength(2));
      });
    });
  });
}
