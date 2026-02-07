import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:trust_car_platform/providers/connectivity_provider.dart';

// Mock Connectivity for testing
class MockConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> _currentResults = [ConnectivityResult.wifi];

  void setConnectivity(List<ConnectivityResult> results) {
    _currentResults = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return _currentResults;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('ConnectivityProvider', () {
    late MockConnectivity mockConnectivity;
    late ConnectivityProvider provider;

    setUp(() {
      mockConnectivity = MockConnectivity();
    });

    tearDown(() {
      provider.dispose();
      mockConnectivity.dispose();
    });

    group('Initial State', () {
      test('starts with online status after initialization', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
        expect(provider.isOffline, isFalse);
        expect(provider.isInitialized, isTrue);
      });

      test('starts with offline status when no connection', () async {
        mockConnectivity._currentResults = [ConnectivityResult.none];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isFalse);
        expect(provider.isOffline, isTrue);
      });
    });

    group('Connection Types', () {
      test('wifi connection is online', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
      });

      test('mobile connection is online', () async {
        mockConnectivity._currentResults = [ConnectivityResult.mobile];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
      });

      test('ethernet connection is online', () async {
        mockConnectivity._currentResults = [ConnectivityResult.ethernet];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
      });

      test('no connection is offline', () async {
        mockConnectivity._currentResults = [ConnectivityResult.none];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isFalse);
        expect(provider.isOffline, isTrue);
      });
    });

    group('Connectivity Changes', () {
      test('updates when connection is lost', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(provider.isOnline, isTrue);

        mockConnectivity.setConnectivity([ConnectivityResult.none]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isFalse);
      });

      test('updates when connection is restored', () async {
        mockConnectivity._currentResults = [ConnectivityResult.none];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(provider.isOnline, isFalse);

        mockConnectivity.setConnectivity([ConnectivityResult.wifi]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
      });

      test('notifies listeners on connectivity change', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        var notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });

        mockConnectivity.setConnectivity([ConnectivityResult.none]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(notificationCount, greaterThan(0));
      });

      test('does not notify when connectivity status unchanged', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        var notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });

        // Change to mobile but still online
        mockConnectivity.setConnectivity([ConnectivityResult.mobile]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not notify since isOnline is still true
        expect(notificationCount, equals(0));
      });
    });

    group('checkConnectivity', () {
      test('returns current connectivity status', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        final isOnline = await provider.checkConnectivity();

        expect(isOnline, isTrue);
      });

      test('updates state when manually checked', () async {
        mockConnectivity._currentResults = [ConnectivityResult.wifi];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(provider.isOnline, isTrue);

        // Simulate connection loss without stream event
        mockConnectivity._currentResults = [ConnectivityResult.none];
        final isOnline = await provider.checkConnectivity();

        expect(isOnline, isFalse);
        expect(provider.isOnline, isFalse);
      });
    });

    group('Multiple Connection Types', () {
      test('is online with multiple connection types', () async {
        mockConnectivity._currentResults = [
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isTrue);
      });

      test('is offline only when all connections are none', () async {
        mockConnectivity._currentResults = [ConnectivityResult.none];
        provider = ConnectivityProvider(connectivity: mockConnectivity);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isOnline, isFalse);
      });
    });
  });
}
