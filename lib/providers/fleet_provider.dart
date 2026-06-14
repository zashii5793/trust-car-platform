import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/inspection_urgency.dart';
import '../models/vehicle.dart';
import '../services/fleet_service.dart';

/// Urgency filter for fleet vehicle list.
enum FleetFilter { all, critical, warning, normal }

/// Provides fleet vehicle state for business account managers.
class FleetProvider with ChangeNotifier {
  final FleetService _fleetService;
  final String companyId;

  FleetProvider({
    required FleetService fleetService,
    required this.companyId,
  }) : _fleetService = fleetService {
    _startListening();
  }

  List<Vehicle> _allVehicles = [];
  FleetStats? _stats;
  FleetFilter _filter = FleetFilter.all;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<Vehicle>>? _sub;

  List<Vehicle> get allVehicles => _allVehicles;
  FleetStats? get stats => _stats;
  FleetFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Vehicles sorted by urgency and filtered by [_filter].
  List<Vehicle> get filteredVehicles {
    final sorted = [..._allVehicles]..sort(_compareUrgency);
    return switch (_filter) {
      FleetFilter.all => sorted,
      FleetFilter.critical =>
        sorted.where((v) => _urgency(v) == InspectionUrgency.critical).toList(),
      FleetFilter.warning =>
        sorted.where((v) => _urgency(v) == InspectionUrgency.warning).toList(),
      FleetFilter.normal => sorted
          .where((v) =>
              _urgency(v) == InspectionUrgency.normal ||
              _urgency(v) == InspectionUrgency.none)
          .toList(),
    };
  }

  void setFilter(FleetFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  Future<void> refresh() async {
    final result = await _fleetService.getFleetStats(companyId);
    result.when(
      success: (s) => _stats = s,
      failure: (_) {},
    );
    notifyListeners();
  }

  void _startListening() {
    _sub = _fleetService.getCompanyVehicles(companyId).listen(
      (vehicles) async {
        _allVehicles = vehicles;
        _isLoading = false;
        _errorMessage = null;
        // Refresh stats on each update
        final result = await _fleetService.getFleetStats(companyId);
        result.when(
          success: (s) => _stats = s,
          failure: (_) {},
        );
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = '車両データの取得に失敗しました';
        notifyListeners();
      },
    );
  }

  // ── Sorting helpers ───────────────────────────────────────────────────────

  static InspectionUrgency _urgency(Vehicle v) =>
      inspectionUrgencyForDays(v.daysUntilInspection);

  static int _compareUrgency(Vehicle a, Vehicle b) {
    const order = {
      InspectionUrgency.critical: 0,
      InspectionUrgency.warning: 1,
      InspectionUrgency.normal: 2,
      InspectionUrgency.none: 3,
    };
    return (order[_urgency(a)] ?? 3).compareTo(order[_urgency(b)] ?? 3);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
