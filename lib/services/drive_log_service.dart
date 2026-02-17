import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/result/result.dart';
import '../core/error/app_error.dart';
import '../models/drive_log.dart';
import '../models/drive_spot.dart';

/// Service for managing drive logs and spots
class DriveLogService {
  final FirebaseFirestore _firestore;

  DriveLogService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _driveLogsRef =>
      _firestore.collection('drive_logs');

  CollectionReference<Map<String, dynamic>> get _waypointsRef =>
      _firestore.collection('drive_waypoints');

  CollectionReference<Map<String, dynamic>> get _driveLogLikesRef =>
      _firestore.collection('drive_log_likes');

  CollectionReference<Map<String, dynamic>> get _spotsRef =>
      _firestore.collection('spots');

  CollectionReference<Map<String, dynamic>> get _spotRatingsRef =>
      _firestore.collection('spot_ratings');

  CollectionReference<Map<String, dynamic>> get _spotFavoritesRef =>
      _firestore.collection('spot_favorites');

  CollectionReference<Map<String, dynamic>> get _spotVisitsRef =>
      _firestore.collection('spot_visits');

  // ============================================================
  // Drive Log Operations
  // ============================================================

  /// Start a new drive recording
  Future<Result<DriveLog, AppError>> startDrive({
    required String userId,
    String? vehicleId,
    GeoPoint2D? startLocation,
    String? startAddress,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _driveLogsRef.doc();

      final driveLog = DriveLog(
        id: docRef.id,
        userId: userId,
        vehicleId: vehicleId,
        status: DriveLogStatus.recording,
        startLocation: startLocation,
        startAddress: startAddress,
        startTime: now,
        statistics: const DriveStatistics(
          totalDistance: 0,
          totalDuration: 0,
          averageSpeed: 0,
          maxSpeed: 0,
        ),
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(driveLog.toMap());

      return Result.success(driveLog);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString()));
    }
  }

  /// End a drive recording
  Future<Result<DriveLog, AppError>> endDrive({
    required String driveLogId,
    required String userId,
    GeoPoint2D? endLocation,
    String? endAddress,
    required DriveStatistics statistics,
    String? title,
    String? description,
    WeatherCondition? weather,
    List<RoadType>? roadTypes,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    try {
      final docRef = _driveLogsRef.doc(driveLogId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      final existing = DriveLog.fromMap(doc.data()!, doc.id);
      if (existing.userId != userId) {
        return Result.failure(AppError.permission('Permission denied'));
      }

      final now = DateTime.now();
      final updated = existing.copyWith(
        status: DriveLogStatus.completed,
        endLocation: endLocation,
        endAddress: endAddress,
        endTime: now,
        statistics: statistics,
        title: title,
        description: description,
        weather: weather,
        roadTypes: roadTypes,
        tags: tags,
        isPublic: isPublic,
        updatedAt: now,
      );

      await docRef.update(updated.toMap());

      return Result.success(updated);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Add waypoint to a drive
  Future<Result<void, AppError>> addWaypoint({
    required String driveLogId,
    required DriveWaypoint waypoint,
  }) async {
    try {
      await _waypointsRef.add({
        'driveLogId': driveLogId,
        ...waypoint.toMap(),
      });

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get waypoints for a drive
  Future<Result<List<DriveWaypoint>, AppError>> getWaypoints(String driveLogId) async {
    try {
      final snapshot = await _waypointsRef
          .where('driveLogId', isEqualTo: driveLogId)
          .orderBy('timestamp')
          .get();

      final waypoints = snapshot.docs
          .map((doc) => DriveWaypoint.fromMap(doc.data()))
          .toList();

      return Result.success(waypoints);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get drive log by ID
  Future<Result<DriveLog, AppError>> getDriveLog(String driveLogId) async {
    try {
      final doc = await _driveLogsRef.doc(driveLogId).get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      return Result.success(DriveLog.fromMap(doc.data()!, doc.id));
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get user's drive logs
  Future<Result<List<DriveLog>, AppError>> getUserDriveLogs({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      var query = _driveLogsRef
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final logs = snapshot.docs
          .map((doc) => DriveLog.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(logs);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get public drive logs (for feed)
  Future<Result<List<DriveLog>, AppError>> getPublicDriveLogs({
    int limit = 20,
    DocumentSnapshot? startAfter,
    List<String>? tags,
    String? prefecture,
  }) async {
    try {
      var query = _driveLogsRef
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: DriveLogStatus.completed.name)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      var logs = snapshot.docs
          .map((doc) => DriveLog.fromMap(doc.data(), doc.id))
          .toList();

      // Client-side filtering for tags and prefecture
      if (tags != null && tags.isNotEmpty) {
        logs = logs.where((log) =>
          log.tags.any((tag) => tags.contains(tag))
        ).toList();
      }

      if (prefecture != null) {
        logs = logs.where((log) =>
          log.startAddress?.contains(prefecture) == true ||
          log.endAddress?.contains(prefecture) == true
        ).toList();
      }

      return Result.success(logs);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Update drive log
  Future<Result<DriveLog, AppError>> updateDriveLog({
    required String driveLogId,
    required String userId,
    String? title,
    String? description,
    List<String>? tags,
    bool? isPublic,
    List<String>? photoUrls,
    String? thumbnailUrl,
  }) async {
    try {
      final docRef = _driveLogsRef.doc(driveLogId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      final existing = DriveLog.fromMap(doc.data()!, doc.id);
      if (existing.userId != userId) {
        return Result.failure(AppError.permission('Permission denied'));
      }

      final updated = existing.copyWith(
        title: title ?? existing.title,
        description: description ?? existing.description,
        tags: tags ?? existing.tags,
        isPublic: isPublic ?? existing.isPublic,
        photoUrls: photoUrls ?? existing.photoUrls,
        thumbnailUrl: thumbnailUrl ?? existing.thumbnailUrl,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updated.toMap());

      return Result.success(updated);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Delete drive log
  Future<Result<void, AppError>> deleteDriveLog({
    required String driveLogId,
    required String userId,
  }) async {
    try {
      final docRef = _driveLogsRef.doc(driveLogId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      final existing = DriveLog.fromMap(doc.data()!, doc.id);
      if (existing.userId != userId) {
        return Result.failure(AppError.permission('Permission denied'));
      }

      // Delete waypoints
      final waypointSnapshot = await _waypointsRef
          .where('driveLogId', isEqualTo: driveLogId)
          .get();
      for (final waypointDoc in waypointSnapshot.docs) {
        await waypointDoc.reference.delete();
      }

      // Delete likes
      final likeSnapshot = await _driveLogLikesRef
          .where('driveLogId', isEqualTo: driveLogId)
          .get();
      for (final likeDoc in likeSnapshot.docs) {
        await likeDoc.reference.delete();
      }

      // Delete drive log
      await docRef.delete();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Drive Log Social Operations
  // ============================================================

  /// Like a drive log
  Future<Result<void, AppError>> likeDriveLog({
    required String driveLogId,
    required String userId,
  }) async {
    try {
      final existingLike = await _driveLogLikesRef
          .where('driveLogId', isEqualTo: driveLogId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingLike.docs.isNotEmpty) {
        return Result.success(null); // Already liked
      }

      final batch = _firestore.batch();

      // Add like
      final likeRef = _driveLogLikesRef.doc();
      batch.set(likeRef, {
        'driveLogId': driveLogId,
        'userId': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      // Increment like count
      batch.update(_driveLogsRef.doc(driveLogId), {
        'likeCount': FieldValue.increment(1),
      });

      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Unlike a drive log
  Future<Result<void, AppError>> unlikeDriveLog({
    required String driveLogId,
    required String userId,
  }) async {
    try {
      final existingLike = await _driveLogLikesRef
          .where('driveLogId', isEqualTo: driveLogId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingLike.docs.isEmpty) {
        return Result.success(null); // Not liked
      }

      final batch = _firestore.batch();

      // Remove like
      batch.delete(existingLike.docs.first.reference);

      // Decrement like count
      batch.update(_driveLogsRef.doc(driveLogId), {
        'likeCount': FieldValue.increment(-1),
      });

      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Check if user liked a drive log
  Future<Result<bool, AppError>> isLikedByUser({
    required String driveLogId,
    required String userId,
  }) async {
    try {
      final snapshot = await _driveLogLikesRef
          .where('driveLogId', isEqualTo: driveLogId)
          .where('userId', isEqualTo: userId)
          .get();

      return Result.success(snapshot.docs.isNotEmpty);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Spot Operations
  // ============================================================

  /// Create a new spot
  Future<Result<DriveSpot, AppError>> createSpot({
    required String userId,
    required String name,
    required SpotCategory category,
    required GeoPoint2D location,
    String? description,
    String? driveLogId,
    String? address,
    String? prefecture,
    String? city,
    List<String>? tags,
    bool isPublic = true,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _spotsRef.doc();

      final spot = DriveSpot(
        id: docRef.id,
        userId: userId,
        driveLogId: driveLogId,
        name: name,
        description: description,
        category: category,
        tags: tags ?? [],
        location: location,
        address: address,
        prefecture: prefecture,
        city: city,
        isPublic: isPublic,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(spot.toMap());

      return Result.success(spot);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get spot by ID
  Future<Result<DriveSpot, AppError>> getSpot(String spotId) async {
    try {
      final doc = await _spotsRef.doc(spotId).get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      return Result.success(DriveSpot.fromMap(doc.data()!, doc.id));
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Search spots by location
  Future<Result<List<DriveSpot>, AppError>> searchSpotsByLocation({
    required GeoPoint2D center,
    required double radiusKm,
    SpotCategory? category,
    int limit = 50,
  }) async {
    try {
      // Note: For production, use GeoFirestore or similar for efficient geo queries
      // This is a simplified version that fetches and filters client-side
      var query = _spotsRef
          .where('isPublic', isEqualTo: true)
          .limit(200); // Fetch more for filtering

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      final snapshot = await query.get();
      final spots = snapshot.docs
          .map((doc) => DriveSpot.fromMap(doc.data(), doc.id))
          .where((spot) {
            final distance = center.distanceTo(spot.location) / 1000; // Convert to km
            return distance <= radiusKm;
          })
          .take(limit)
          .toList();

      return Result.success(spots);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Search spots by text
  Future<Result<List<DriveSpot>, AppError>> searchSpotsByText({
    required String query,
    SpotCategory? category,
    String? prefecture,
    int limit = 20,
  }) async {
    try {
      var firestoreQuery = _spotsRef
          .where('isPublic', isEqualTo: true)
          .orderBy('name')
          .limit(100);

      if (category != null) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: category.name);
      }

      if (prefecture != null) {
        firestoreQuery = firestoreQuery.where('prefecture', isEqualTo: prefecture);
      }

      final snapshot = await firestoreQuery.get();

      // Client-side text search
      final queryLower = query.toLowerCase();
      final spots = snapshot.docs
          .map((doc) => DriveSpot.fromMap(doc.data(), doc.id))
          .where((spot) {
            return spot.name.toLowerCase().contains(queryLower) ||
                (spot.description?.toLowerCase().contains(queryLower) ?? false) ||
                spot.tags.any((tag) => tag.toLowerCase().contains(queryLower));
          })
          .take(limit)
          .toList();

      return Result.success(spots);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get popular spots
  Future<Result<List<DriveSpot>, AppError>> getPopularSpots({
    SpotCategory? category,
    String? prefecture,
    int limit = 20,
  }) async {
    try {
      var query = _spotsRef
          .where('isPublic', isEqualTo: true)
          .orderBy('visitCount', descending: true)
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      final snapshot = await query.get();
      var spots = snapshot.docs
          .map((doc) => DriveSpot.fromMap(doc.data(), doc.id))
          .toList();

      if (prefecture != null) {
        spots = spots.where((spot) => spot.prefecture == prefecture).toList();
      }

      return Result.success(spots);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Update spot
  Future<Result<DriveSpot, AppError>> updateSpot({
    required String spotId,
    required String userId,
    String? name,
    String? description,
    SpotCategory? category,
    List<String>? tags,
    String? address,
    String? phoneNumber,
    String? website,
    List<SpotBusinessHours>? businessHours,
    bool? isParkingAvailable,
    int? parkingCapacity,
    List<SpotImage>? images,
    bool? isPublic,
  }) async {
    try {
      final docRef = _spotsRef.doc(spotId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      final existing = DriveSpot.fromMap(doc.data()!, doc.id);
      if (existing.userId != userId) {
        return Result.failure(AppError.permission('Permission denied'));
      }

      final updated = existing.copyWith(
        name: name ?? existing.name,
        description: description ?? existing.description,
        category: category ?? existing.category,
        tags: tags ?? existing.tags,
        address: address ?? existing.address,
        phoneNumber: phoneNumber ?? existing.phoneNumber,
        website: website ?? existing.website,
        businessHours: businessHours ?? existing.businessHours,
        isParkingAvailable: isParkingAvailable ?? existing.isParkingAvailable,
        parkingCapacity: parkingCapacity ?? existing.parkingCapacity,
        images: images ?? existing.images,
        isPublic: isPublic ?? existing.isPublic,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updated.toMap());

      return Result.success(updated);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Delete spot
  Future<Result<void, AppError>> deleteSpot({
    required String spotId,
    required String userId,
  }) async {
    try {
      final docRef = _spotsRef.doc(spotId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('Resource not found'));
      }

      final existing = DriveSpot.fromMap(doc.data()!, doc.id);
      if (existing.userId != userId) {
        return Result.failure(AppError.permission('Permission denied'));
      }

      await docRef.delete();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Spot Rating Operations
  // ============================================================

  /// Add rating to spot
  Future<Result<SpotRating, AppError>> addSpotRating({
    required String spotId,
    required String userId,
    required int rating,
    String? userName,
    String? userAvatarUrl,
    String? comment,
    List<String>? photoUrls,
    DateTime? visitedAt,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        return Result.failure(AppError.validation('Invalid rating value'));
      }

      final now = DateTime.now();
      final docRef = _spotRatingsRef.doc();

      final spotRating = SpotRating(
        id: docRef.id,
        spotId: spotId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        rating: rating,
        comment: comment,
        photoUrls: photoUrls ?? [],
        visitedAt: visitedAt ?? now,
        createdAt: now,
      );

      final batch = _firestore.batch();

      // Add rating
      batch.set(docRef, spotRating.toMap());

      // Update spot average rating
      // This should ideally be done with a cloud function for accuracy
      final spotDoc = await _spotsRef.doc(spotId).get();
      if (spotDoc.exists) {
        final spot = DriveSpot.fromMap(spotDoc.data()!, spotDoc.id);
        final newCount = spot.ratingCount + 1;
        final newAverage = ((spot.averageRating * spot.ratingCount) + rating) / newCount;

        batch.update(_spotsRef.doc(spotId), {
          'averageRating': newAverage,
          'ratingCount': newCount,
        });
      }

      await batch.commit();

      return Result.success(spotRating);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get ratings for a spot
  Future<Result<List<SpotRating>, AppError>> getSpotRatings({
    required String spotId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _spotRatingsRef
          .where('spotId', isEqualTo: spotId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final ratings = snapshot.docs
          .map((doc) => SpotRating.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(ratings);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Spot Favorite Operations
  // ============================================================

  /// Add spot to favorites
  Future<Result<void, AppError>> addSpotFavorite({
    required String spotId,
    required String userId,
    String? note,
  }) async {
    try {
      final existing = await _spotFavoritesRef
          .where('spotId', isEqualTo: spotId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existing.docs.isNotEmpty) {
        return Result.success(null); // Already favorited
      }

      final batch = _firestore.batch();

      // Add favorite
      final docRef = _spotFavoritesRef.doc();
      batch.set(docRef, {
        'spotId': spotId,
        'userId': userId,
        if (note != null) 'note': note,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      // Increment favorite count
      batch.update(_spotsRef.doc(spotId), {
        'favoriteCount': FieldValue.increment(1),
      });

      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Remove spot from favorites
  Future<Result<void, AppError>> removeSpotFavorite({
    required String spotId,
    required String userId,
  }) async {
    try {
      final existing = await _spotFavoritesRef
          .where('spotId', isEqualTo: spotId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existing.docs.isEmpty) {
        return Result.success(null); // Not favorited
      }

      final batch = _firestore.batch();

      // Remove favorite
      batch.delete(existing.docs.first.reference);

      // Decrement favorite count
      batch.update(_spotsRef.doc(spotId), {
        'favoriteCount': FieldValue.increment(-1),
      });

      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get user's favorite spots
  Future<Result<List<DriveSpot>, AppError>> getUserFavoriteSpots({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final favoriteSnapshot = await _spotFavoritesRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final spotIds = favoriteSnapshot.docs
          .map((doc) => doc.data()['spotId'] as String)
          .toList();

      if (spotIds.isEmpty) {
        return Result.success([]);
      }

      // Fetch spots (Firestore limits whereIn to 10 items)
      final spots = <DriveSpot>[];
      for (var i = 0; i < spotIds.length; i += 10) {
        final chunk = spotIds.skip(i).take(10).toList();
        final spotSnapshot = await _spotsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        spots.addAll(
          spotSnapshot.docs.map((doc) => DriveSpot.fromMap(doc.data(), doc.id)),
        );
      }

      return Result.success(spots);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Spot Visit Operations
  // ============================================================

  /// Record a spot visit
  Future<Result<SpotVisit, AppError>> recordSpotVisit({
    required String spotId,
    required String userId,
    String? driveLogId,
    String? note,
    List<String>? photoUrls,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _spotVisitsRef.doc();

      final visit = SpotVisit(
        id: docRef.id,
        spotId: spotId,
        userId: userId,
        driveLogId: driveLogId,
        visitedAt: now,
        note: note,
        photoUrls: photoUrls ?? [],
      );

      final batch = _firestore.batch();

      // Add visit
      batch.set(docRef, visit.toMap());

      // Increment visit count
      batch.update(_spotsRef.doc(spotId), {
        'visitCount': FieldValue.increment(1),
      });

      await batch.commit();

      return Result.success(visit);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  /// Get user's spot visits
  Future<Result<List<SpotVisit>, AppError>> getUserSpotVisits({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _spotVisitsRef
          .where('userId', isEqualTo: userId)
          .orderBy('visitedAt', descending: true)
          .limit(limit)
          .get();

      final visits = snapshot.docs
          .map((doc) => SpotVisit.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(visits);
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }

  // ============================================================
  // Statistics
  // ============================================================

  /// Get user drive statistics
  Future<Result<Map<String, dynamic>, AppError>> getUserDriveStatistics(String userId) async {
    try {
      final snapshot = await _driveLogsRef
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: DriveLogStatus.completed.name)
          .get();

      double totalDistance = 0;
      int totalDuration = 0;
      int driveCount = snapshot.docs.length;
      double maxSpeed = 0;

      for (final doc in snapshot.docs) {
        final log = DriveLog.fromMap(doc.data(), doc.id);
        totalDistance += log.statistics.totalDistance;
        totalDuration += log.statistics.totalDuration;
        if (log.statistics.maxSpeed > maxSpeed) {
          maxSpeed = log.statistics.maxSpeed;
        }
      }

      return Result.success({
        'driveCount': driveCount,
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'averageDistance': driveCount > 0 ? totalDistance / driveCount : 0,
        'maxSpeed': maxSpeed,
      });
    } catch (e) {
      return Result.failure(AppError.unknown('An error occurred'));
    }
  }
}
