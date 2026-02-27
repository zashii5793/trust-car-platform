import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Mock FirebaseService
class MockFirebaseService implements FirebaseService {
  bool getMaintenanceRecordsCalled = false;
  Result<List<MaintenanceRecord>, AppError>? getMaintenanceRecordsResult;
  Result<Map<String, List<MaintenanceRecord>>, AppError>? getMaintenanceRecordsForVehiclesResult;

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async {
    getMaintenanceRecordsCalled = true;
    return getMaintenanceRecordsResult ?? const Result.success([]);
  }

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>> getMaintenanceRecordsForVehicles(
    List<String> vehicleIds, {
    int limitPerVehicle = 20,
  }) async {
    getMaintenanceRecordsCalled = true;
    return getMaintenanceRecordsForVehiclesResult ?? const Result.success({});
  }

  // Unused methods
  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();
  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();
  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle vehicle) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<bool, AppError>> isLicensePlateExists(
    String licensePlate, {
    String? excludeVehicleId,
  }) async =>
      const Result.success(false);
  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic bytes, String path) async =>
      const Result.success('url');
  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImage(dynamic imageFile, String path) async =>
      const Result.success('url');
  @override
  Future<Result<List<String>, AppError>> uploadImages(
    List<dynamic> imageFiles,
    String basePath,
  ) async =>
      const Result.success([]);
  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic imageBytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

// Mock RecommendationService
class MockRecommendationService implements RecommendationService {
  List<AppNotification>? mockRecommendations;

  @override
  List<AppNotification> generateRecommendations({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    required String userId,
  }) {
    return mockRecommendations ?? [];
  }
}

Vehicle _createTestVehicle({String? id}) => Vehicle(
      id: id ?? 'test-vehicle-id',
      userId: 'test-user-id',
      maker: 'Toyota',
      model: 'Prius',
      year: 2020,
      grade: 'S',
      mileage: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

AppNotification _createTestNotification({
  String? id,
  NotificationPriority? priority,
  bool isRead = false,
}) =>
    AppNotification(
      id: id ?? 'notification-id',
      userId: 'test-user-id',
      vehicleId: 'test-vehicle-id',
      type: NotificationType.maintenanceRecommendation,
      title: 'Test notification',
      message: 'Test message',
      priority: priority ?? NotificationPriority.medium,
      isRead: isRead,
      createdAt: DateTime.now(),
    );

void main() {
  group('NotificationProvider', () {
    late MockFirebaseService mockFirebaseService;
    late MockRecommendationService mockRecommendationService;
    late NotificationProvider provider;

    setUp(() {
      mockFirebaseService = MockFirebaseService();
      mockRecommendationService = MockRecommendationService();
      provider = NotificationProvider(
        firebaseService: mockFirebaseService,
        recommendationService: mockRecommendationService,
      );
    });

    group('Initial State', () {
      test('starts with empty notifications and no error', () {
        expect(provider.notifications, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
        expect(provider.errorMessage, isNull);
        expect(provider.isRetryable, isFalse);
        expect(provider.unreadCount, equals(0));
        expect(provider.highPriorityUnreadCount, equals(0));
      });
    });

    group('Error Handling', () {
      test('error is AppError type', () async {
        // Create a mock that throws an exception
        final throwingService = _MockFirebaseServiceThrowing();
        provider = NotificationProvider(
          firebaseService: throwingService,
          recommendationService: mockRecommendationService,
        );

        await provider.generateNotificationsForVehicles([_createTestVehicle()]);

        expect(provider.error, isA<AppError>());
        expect(provider.errorMessage, isNotNull);
      });

      test('clearError clears the error', () async {
        final throwingService = _MockFirebaseServiceThrowing();
        provider = NotificationProvider(
          firebaseService: throwingService,
          recommendationService: mockRecommendationService,
        );

        await provider.generateNotificationsForVehicles([_createTestVehicle()]);
        expect(provider.error, isNotNull);

        provider.clearError();

        expect(provider.error, isNull);
        expect(provider.errorMessage, isNull);
      });
    });

    group('generateNotificationsForVehicles', () {
      test('calls firebaseService.getMaintenanceRecordsForVehicle', () async {
        final vehicles = [_createTestVehicle()];
        await provider.generateNotificationsForVehicles(vehicles);

        expect(mockFirebaseService.getMaintenanceRecordsCalled, isTrue);
      });

      test('generates recommendations from recommendation service', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1'),
          _createTestNotification(id: '2'),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        expect(provider.notifications.length, equals(2));
      });

      test('does nothing when vehicles list is empty', () async {
        await provider.generateNotificationsForVehicles([]);

        expect(provider.notifications, isEmpty);
        expect(mockFirebaseService.getMaintenanceRecordsCalled, isFalse);
      });

      test('does nothing when userId is null', () async {
        // Create a mock with null userId
        final nullUserService = _MockFirebaseServiceNullUser();
        provider = NotificationProvider(
          firebaseService: nullUserService,
          recommendationService: mockRecommendationService,
        );

        await provider.generateNotificationsForVehicles([_createTestVehicle()]);

        expect(provider.notifications, isEmpty);
      });
    });

    group('generateRecommendations', () {
      test('generates and sorts recommendations by priority', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', priority: NotificationPriority.low),
          _createTestNotification(id: '2', priority: NotificationPriority.high),
          _createTestNotification(id: '3', priority: NotificationPriority.medium),
        ];

        await provider.generateRecommendations(
          vehicles: vehicles,
          maintenanceRecords: {'test-vehicle-id': []},
        );

        expect(provider.notifications.length, equals(3));
        expect(provider.notifications[0].priority, equals(NotificationPriority.high));
        expect(provider.notifications[1].priority, equals(NotificationPriority.medium));
        expect(provider.notifications[2].priority, equals(NotificationPriority.low));
      });
    });

    group('unreadCount', () {
      test('counts unread notifications', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', isRead: false),
          _createTestNotification(id: '2', isRead: true),
          _createTestNotification(id: '3', isRead: false),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        expect(provider.unreadCount, equals(2));
      });
    });

    group('highPriorityUnreadCount', () {
      test('counts high priority unread notifications', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', priority: NotificationPriority.high, isRead: false),
          _createTestNotification(id: '2', priority: NotificationPriority.high, isRead: true),
          _createTestNotification(id: '3', priority: NotificationPriority.medium, isRead: false),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        expect(provider.highPriorityUnreadCount, equals(1));
      });
    });

    group('markAsRead', () {
      test('marks a notification as read', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: 'n1', isRead: false),
        ];

        await provider.generateNotificationsForVehicles(vehicles);
        expect(provider.unreadCount, equals(1));

        await provider.markAsRead('n1');

        expect(provider.notifications.first.isRead, isTrue);
        expect(provider.unreadCount, equals(0));
      });

      test('does nothing when notification not found', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: 'n1', isRead: false),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        await provider.markAsRead('non-existent');

        expect(provider.notifications.first.isRead, isFalse);
      });
    });

    group('markAllAsRead', () {
      test('marks all notifications as read', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', isRead: false),
          _createTestNotification(id: '2', isRead: false),
        ];

        await provider.generateNotificationsForVehicles(vehicles);
        expect(provider.unreadCount, equals(2));

        await provider.markAllAsRead();

        expect(provider.unreadCount, equals(0));
        expect(provider.notifications.every((n) => n.isRead), isTrue);
      });
    });

    group('removeNotification', () {
      test('removes a notification', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1'),
          _createTestNotification(id: '2'),
        ];

        await provider.generateNotificationsForVehicles(vehicles);
        expect(provider.notifications.length, equals(2));

        provider.removeNotification('1');

        expect(provider.notifications.length, equals(1));
        expect(provider.notifications.first.id, equals('2'));
      });
    });

    group('clearNotifications', () {
      test('clears all notifications', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1'),
          _createTestNotification(id: '2'),
        ];

        await provider.generateNotificationsForVehicles(vehicles);
        expect(provider.notifications.length, equals(2));

        provider.clearNotifications();

        expect(provider.notifications, isEmpty);
      });
    });

    group('clear', () {
      test('resets all state', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1'),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        provider.clear();

        expect(provider.notifications, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });
    });

    group('getNotificationsForVehicle', () {
      test('filters notifications by vehicle id', () async {
        // Use a single vehicle, then manually set notifications with mixed vehicleIds
        final vehicles = [_createTestVehicle(id: 'v1')];
        mockRecommendationService.mockRecommendations = [
          AppNotification(
            id: 'n1',
            userId: 'test-user-id',
            vehicleId: 'v1',
            type: NotificationType.maintenanceRecommendation,
            title: 'Test',
            message: 'Message',
            priority: NotificationPriority.medium,
            isRead: false,
            createdAt: DateTime.now(),
          ),
          AppNotification(
            id: 'n2',
            userId: 'test-user-id',
            vehicleId: 'v2', // Different vehicleId
            type: NotificationType.maintenanceRecommendation,
            title: 'Test',
            message: 'Message',
            priority: NotificationPriority.medium,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ];

        await provider.generateRecommendations(
          vehicles: vehicles,
          maintenanceRecords: {'v1': []},
        );

        final v1Notifications = provider.getNotificationsForVehicle('v1');

        expect(v1Notifications.length, equals(1));
        expect(v1Notifications.first.vehicleId, equals('v1'));
      });
    });

    group('getNotificationsByType', () {
      test('filters notifications by type', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          AppNotification(
            id: 'n1',
            userId: 'test-user-id',
            vehicleId: 'test-vehicle-id',
            type: NotificationType.maintenanceRecommendation,
            title: 'Test',
            message: 'Message',
            priority: NotificationPriority.medium,
            isRead: false,
            createdAt: DateTime.now(),
          ),
          AppNotification(
            id: 'n2',
            userId: 'test-user-id',
            vehicleId: 'test-vehicle-id',
            type: NotificationType.inspectionReminder,
            title: 'Test',
            message: 'Message',
            priority: NotificationPriority.high,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        final maintenanceNotifications =
            provider.getNotificationsByType(NotificationType.maintenanceRecommendation);

        expect(maintenanceNotifications.length, equals(1));
        expect(
          maintenanceNotifications.first.type,
          equals(NotificationType.maintenanceRecommendation),
        );
      });
    });

    group('topSuggestions', () {
      test('returns empty list when no notifications', () {
        expect(provider.topSuggestions, isEmpty);
      });

      test('returns only high and medium priority notifications', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', priority: NotificationPriority.high),
          _createTestNotification(id: '2', priority: NotificationPriority.medium),
          _createTestNotification(id: '3', priority: NotificationPriority.low),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        final suggestions = provider.topSuggestions;
        expect(suggestions.length, equals(2));
        expect(suggestions.any((n) => n.priority == NotificationPriority.low), isFalse);
      });

      test('excludes system type notifications', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', priority: NotificationPriority.high),
          AppNotification(
            id: 'sys',
            userId: 'test-user-id',
            vehicleId: 'test-vehicle-id',
            type: NotificationType.system,
            title: 'System',
            message: 'System message',
            priority: NotificationPriority.high,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        final suggestions = provider.topSuggestions;
        expect(suggestions.length, equals(1));
        expect(suggestions.any((n) => n.type == NotificationType.system), isFalse);
      });

      test('returns at most 3 items', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = List.generate(
          6,
          (i) => _createTestNotification(
            id: 'n$i',
            priority: NotificationPriority.high,
          ),
        );

        await provider.generateNotificationsForVehicles(vehicles);

        expect(provider.topSuggestions.length, equals(3));
      });

      test('high priority appears before medium priority', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: 'med', priority: NotificationPriority.medium),
          _createTestNotification(id: 'high', priority: NotificationPriority.high),
        ];

        await provider.generateRecommendations(
          vehicles: vehicles,
          maintenanceRecords: {'test-vehicle-id': []},
        );

        final suggestions = provider.topSuggestions;
        expect(suggestions.first.priority, equals(NotificationPriority.high));
      });

      test('returns empty when only low priority or system notifications exist', () async {
        final vehicles = [_createTestVehicle()];
        mockRecommendationService.mockRecommendations = [
          _createTestNotification(id: '1', priority: NotificationPriority.low),
          AppNotification(
            id: 'sys',
            userId: 'test-user-id',
            vehicleId: 'test-vehicle-id',
            type: NotificationType.system,
            title: 'System',
            message: 'System message',
            priority: NotificationPriority.medium,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ];

        await provider.generateNotificationsForVehicles(vehicles);

        expect(provider.topSuggestions, isEmpty);
      });
    });
  });
}

// Helper mock for null user case
class _MockFirebaseServiceNullUser implements FirebaseService {
  @override
  String? get currentUserId => null;

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>> getMaintenanceRecordsForVehicles(
    List<String> vehicleIds, {
    int limitPerVehicle = 20,
  }) async =>
      const Result.success({});

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();
  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();
  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle vehicle) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<bool, AppError>> isLicensePlateExists(
    String licensePlate, {
    String? excludeVehicleId,
  }) async =>
      const Result.success(false);
  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic bytes, String path) async =>
      const Result.success('url');
  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImage(dynamic imageFile, String path) async =>
      const Result.success('url');
  @override
  Future<Result<List<String>, AppError>> uploadImages(
    List<dynamic> imageFiles,
    String basePath,
  ) async =>
      const Result.success([]);
  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic imageBytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

// Helper mock for throwing exception case
class _MockFirebaseServiceThrowing implements FirebaseService {
  @override
  String? get currentUserId => 'test-user-id';

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async {
    throw Exception('Test exception');
  }

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>> getMaintenanceRecordsForVehicles(
    List<String> vehicleIds, {
    int limitPerVehicle = 20,
  }) async {
    throw Exception('Test exception');
  }

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();
  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();
  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle vehicle) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<bool, AppError>> isLicensePlateExists(
    String licensePlate, {
    String? excludeVehicleId,
  }) async =>
      const Result.success(false);
  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('id');
  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic bytes, String path) async =>
      const Result.success('url');
  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);
  @override
  Future<Result<String, AppError>> uploadImage(dynamic imageFile, String path) async =>
      const Result.success('url');
  @override
  Future<Result<List<String>, AppError>> uploadImages(
    List<dynamic> imageFiles,
    String basePath,
  ) async =>
      const Result.success([]);
  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic imageBytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}
