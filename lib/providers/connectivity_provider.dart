import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Manages connectivity state for offline support
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isInitialized = false;

  ConnectivityProvider({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  /// Whether the device is currently online
  bool get isOnline => _isOnline;

  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;

  /// Whether the device is currently offline
  bool get isOffline => !_isOnline;

  Future<void> _init() async {
    // Check initial connectivity status
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);
    _isInitialized = true;
    notifyListeners();

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Consider online if any connection type is available (not none)
    _isOnline = results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  /// Manually check current connectivity
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);
    return _isOnline;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
