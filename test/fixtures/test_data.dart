/// Centralized test fixture builders for Trust Car Platform unit/widget tests.
///
/// Usage:
///   import '../fixtures/test_data.dart';
///   final v = TestData.makeVehicle(maker: 'Toyota');
///
/// All builders accept named parameters so callers override only what matters.
/// Defaults produce valid, minimal objects that pass validation.

library test_data;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/user.dart';

/// Fixed reference timestamp used across tests so results are deterministic.
final _kBase = DateTime(2024, 1, 15, 10, 0);

abstract final class TestData {
  // ---------------------------------------------------------------------------
  // Vehicle
  // ---------------------------------------------------------------------------

  /// Creates a minimal valid [Vehicle].
  ///
  /// [inspectionExpiryDate] / [insuranceExpiryDate] default to null (未設定).
  static Vehicle makeVehicle({
    String id = 'vehicle-001',
    String userId = 'user-001',
    String maker = 'Toyota',
    String model = 'Prius',
    int year = 2020,
    String grade = 'S',
    int mileage = 30000,
    String? imageUrl,
    String? licensePlate,
    String? vinNumber,
    DateTime? inspectionExpiryDate,
    DateTime? insuranceExpiryDate,
    FuelType? fuelType = FuelType.hybrid,
    DriveType? driveType,
    TransmissionType? transmissionType,
    String? color,
    int? engineDisplacement,
    VoluntaryInsurance? voluntaryInsurance,
  }) {
    return Vehicle(
      id: id,
      userId: userId,
      maker: maker,
      model: model,
      year: year,
      grade: grade,
      mileage: mileage,
      imageUrl: imageUrl,
      createdAt: _kBase,
      updatedAt: _kBase,
      licensePlate: licensePlate,
      vinNumber: vinNumber,
      inspectionExpiryDate: inspectionExpiryDate,
      insuranceExpiryDate: insuranceExpiryDate,
      fuelType: fuelType,
      driveType: driveType,
      transmissionType: transmissionType,
      color: color,
      engineDisplacement: engineDisplacement,
      voluntaryInsurance: voluntaryInsurance,
    );
  }

  /// Vehicle whose inspection expires in [daysFromNow] days.
  static Vehicle vehicleWithInspectionIn(int daysFromNow) {
    return makeVehicle(
      inspectionExpiryDate: DateTime.now().add(Duration(days: daysFromNow)),
    );
  }

  /// Vehicle whose inspection expired [daysAgo] days ago.
  static Vehicle vehicleWithExpiredInspection(int daysAgo) {
    return makeVehicle(
      inspectionExpiryDate: DateTime.now().subtract(Duration(days: daysAgo)),
    );
  }

  // ---------------------------------------------------------------------------
  // AppNotification
  // ---------------------------------------------------------------------------

  static AppNotification makeNotification({
    String id = 'notif-001',
    String userId = 'user-001',
    String? vehicleId = 'vehicle-001',
    NotificationType type = NotificationType.maintenanceRecommendation,
    String title = 'オイル交換を推奨します',
    String message = '前回交換から5,000km走行しました。そろそろオイル交換をご検討ください。',
    NotificationPriority priority = NotificationPriority.medium,
    bool isRead = false,
    DateTime? createdAt,
    DateTime? actionDate,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      type: type,
      title: title,
      message: message,
      priority: priority,
      isRead: isRead,
      createdAt: createdAt ?? _kBase,
      actionDate: actionDate,
      metadata: metadata,
    );
  }

  static AppNotification makeHighPriorityNotification({String id = 'notif-high'}) {
    return makeNotification(
      id: id,
      type: NotificationType.inspectionReminder,
      title: '車検期限が近づいています',
      message: '30日以内に車検が到来します。早めに手配してください。',
      priority: NotificationPriority.high,
    );
  }

  static AppNotification makeReadNotification({String id = 'notif-read'}) {
    return makeNotification(id: id, isRead: true);
  }

  // ---------------------------------------------------------------------------
  // Shop
  // ---------------------------------------------------------------------------

  static Shop makeShop({
    String id = 'shop-001',
    String name = 'トラストモータース',
    ShopType type = ShopType.maintenanceShop,
    bool isVerified = true,
    bool isFeatured = false,
    bool isActive = true,
    double? rating = 4.2,
    int reviewCount = 85,
    String prefecture = '東京都',
    List<ServiceCategory> services = const [
      ServiceCategory.maintenance,
      ServiceCategory.inspection,
    ],
  }) {
    return Shop(
      id: id,
      name: name,
      type: type,
      isVerified: isVerified,
      isFeatured: isFeatured,
      isActive: isActive,
      rating: rating,
      reviewCount: reviewCount,
      prefecture: prefecture,
      services: services,
      supportedMakerIds: [],
      imageUrls: [],
      businessHours: {},
      createdAt: _kBase,
      updatedAt: _kBase,
    );
  }

  static Shop makeFeaturedShop({String id = 'shop-featured'}) {
    return makeShop(id: id, isFeatured: true, name: 'スポンサーショップ');
  }

  static Shop makeUnverifiedShop({String id = 'shop-unverified'}) {
    return makeShop(id: id, isVerified: false, name: '未認証ショップ');
  }

  // ---------------------------------------------------------------------------
  // DriveLog
  // ---------------------------------------------------------------------------

  static DriveLog makeDriveLog({
    String id = 'drive-001',
    String userId = 'user-001',
    String? vehicleId = 'vehicle-001',
    DriveLogStatus status = DriveLogStatus.completed,
    double distance = 55.0,
    int durationSecs = 4200,
    WeatherCondition? weather = WeatherCondition.sunny,
    DateTime? startTime,
  }) {
    final start = startTime ?? _kBase;
    return DriveLog(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      status: status,
      startTime: start,
      endTime: start.add(Duration(seconds: durationSecs)),
      statistics: DriveStatistics(
        totalDistance: distance,
        totalDuration: durationSecs,
        averageSpeed: distance / (durationSecs / 3600),
        maxSpeed: 100.0,
      ),
      weather: weather,
      createdAt: start,
      updatedAt: start,
    );
  }

  // ---------------------------------------------------------------------------
  // Post
  // ---------------------------------------------------------------------------

  static Post makePost({
    String id = 'post-001',
    String userId = 'user-001',
    String? userDisplayName = 'テストユーザー',
    PostCategory category = PostCategory.carLife,
    PostVisibility visibility = PostVisibility.public,
    String content = '今日は天気が良かったのでドライブしました #ドライブ',
    List<PostMedia> media = const [],
    int likeCount = 0,
    bool isLiked = false,
    DateTime? createdAt,
  }) {
    return Post(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName,
      category: category,
      visibility: visibility,
      content: content,
      media: media,
      likeCount: likeCount,
      commentCount: 0,
      createdAt: createdAt ?? _kBase,
      updatedAt: createdAt ?? _kBase,
    );
  }

  static Post makePostWithMedia({String id = 'post-media'}) {
    return makePost(
      id: id,
      content: '愛車の写真です #マイカー',
      media: [
        PostMedia(
          url: 'https://example.com/img1.jpg',
          type: 'image',
          width: 1080,
          height: 720,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MaintenanceRecord
  // ---------------------------------------------------------------------------

  static MaintenanceRecord makeMaintenanceRecord({
    String id = 'maint-001',
    String vehicleId = 'vehicle-001',
    String userId = 'user-001',
    MaintenanceType type = MaintenanceType.oilChange,
    String title = 'オイル交換',
    DateTime? date,
    int cost = 3500,
    int mileageAtService = 30000,
    String? shopName = 'トラストモータース',
    String? description,
  }) {
    return MaintenanceRecord(
      id: id,
      vehicleId: vehicleId,
      userId: userId,
      type: type,
      title: title,
      date: date ?? _kBase,
      cost: cost,
      mileageAtService: mileageAtService,
      shopName: shopName,
      description: description,
      createdAt: date ?? _kBase,
    );
  }

  // ---------------------------------------------------------------------------
  // PartListing
  // ---------------------------------------------------------------------------

  static PartListing makePartListing({
    String id = 'part-001',
    String shopId = 'shop-001',
    String name = 'トヨタ純正エンジンオイル 5W-30',
    String description = 'トヨタ純正エンジンオイルです。',
    PartCategory category = PartCategory.maintenance,
    int? priceFrom = 2800,
    bool isFeatured = false,
    List<String> imageUrls = const [],
    double? rating = 4.5,
    int reviewCount = 12,
  }) {
    return PartListing(
      id: id,
      shopId: shopId,
      name: name,
      description: description,
      category: category,
      priceFrom: priceFrom,
      isFeatured: isFeatured,
      imageUrls: imageUrls,
      rating: rating,
      reviewCount: reviewCount,
      createdAt: _kBase,
      updatedAt: _kBase,
    );
  }

  // ---------------------------------------------------------------------------
  // AppUser
  // ---------------------------------------------------------------------------

  static AppUser makeUser({
    String id = 'user-001',
    String email = 'test@example.com',
    String? displayName = 'テストユーザー',
    String? photoUrl,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      createdAt: _kBase,
      updatedAt: _kBase,
    );
  }
}

/// Convenience: build a list of [n] vehicles with sequential IDs.
List<Vehicle> makeVehicleList(int n) {
  return List.generate(
    n,
    (i) => TestData.makeVehicle(
      id: 'vehicle-${i + 1}',
      maker: ['Toyota', 'Honda', 'Nissan', 'Mazda', 'Subaru'][i % 5],
      model: ['Prius', 'Fit', 'Note', 'CX-5', 'Impreza'][i % 5],
    ),
  );
}

/// Convenience: build a list of [n] notifications with sequential IDs.
List<AppNotification> makeNotificationList(int n) {
  return List.generate(
    n,
    (i) => TestData.makeNotification(
      id: 'notif-${i + 1}',
      isRead: i.isEven,
      priority: [
        NotificationPriority.high,
        NotificationPriority.medium,
        NotificationPriority.low,
      ][i % 3],
    ),
  );
}

/// Convenience: build a list of [n] shops with sequential IDs.
List<Shop> makeShopList(int n) {
  return List.generate(
    n,
    (i) => TestData.makeShop(
      id: 'shop-${i + 1}',
      name: 'ショップ${i + 1}',
      isFeatured: i == 0,
    ),
  );
}

/// Convenience: build a list of [n] posts with sequential IDs.
List<Post> makePostList(int n) {
  return List.generate(
    n,
    (i) => TestData.makePost(
      id: 'post-${i + 1}',
      userId: 'user-${i % 3 + 1}',
      content: '投稿${i + 1}のテスト内容 #テスト',
    ),
  );
}
