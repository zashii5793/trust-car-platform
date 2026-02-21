/// Firebase Emulator Helper for Integration Tests
///
/// This helper provides utilities for connecting to Firebase Emulators
/// and managing test data lifecycle.
///
/// Usage:
/// 1. Start Firebase Emulators: `firebase emulators:start`
/// 2. Run integration tests: `flutter test test/integration/`

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Configuration for Firebase Emulators
class EmulatorConfig {
  static const String host = 'localhost';
  static const int firestorePort = 8080;
  static const int authPort = 9099;

  /// Check if running in emulator mode
  static bool get isEmulatorMode {
    // In test environment, we always use emulators
    return true;
  }
}

/// Helper class for Firebase Emulator integration tests
class FirebaseEmulatorHelper {
  static bool _initialized = false;

  /// Initialize Firebase for testing with emulators
  ///
  /// Call this in setUpAll() of your test file
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize Firebase (if not already done)
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Already initialized
    }

    // Connect to Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(
      EmulatorConfig.host,
      EmulatorConfig.firestorePort,
    );

    // Connect to Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(
      EmulatorConfig.host,
      EmulatorConfig.authPort,
    );

    _initialized = true;
  }

  /// Clear all Firestore data
  ///
  /// Call this in setUp() to ensure clean state for each test
  static Future<void> clearFirestore() async {
    final firestore = FirebaseFirestore.instance;

    // Get all collections and delete documents
    // Note: This is a simplified approach for testing
    final collections = [
      'users',
      'vehicles',
      'maintenance_records',
      'posts',
      'post_likes',
      'comments',
      'drive_logs',
      'drive_waypoints',
      'drive_log_likes',
      'spots',
      'spot_ratings',
      'spot_favorites',
      'spot_visits',
    ];

    for (final collection in collections) {
      final snapshot = await firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Create a test user in Auth emulator
  static Future<UserCredential> createTestUser({
    String email = 'test@example.com',
    String password = 'password123',
  }) async {
    try {
      // Try to sign in first (user might exist)
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Create new user if sign in fails
      return await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Get current user ID or null
  static String? get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Delete current user from Auth
  static Future<void> deleteCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}

/// Test data generators
class TestDataGenerator {
  static int _counter = 0;

  /// Generate unique ID for test data
  static String uniqueId([String prefix = 'test']) {
    _counter++;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }

  /// Generate test vehicle data
  static Map<String, dynamic> vehicleData({
    required String userId,
    String? maker,
    String? model,
    int? year,
  }) {
    return {
      'userId': userId,
      'maker': maker ?? 'Toyota',
      'model': model ?? 'Prius',
      'year': year ?? 2023,
      'grade': 'S',
      'mileage': 10000,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Generate test maintenance record data
  static Map<String, dynamic> maintenanceRecordData({
    required String vehicleId,
    required String userId,
    String? type,
    int? cost,
  }) {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'type': type ?? 'oilChange',
      'title': 'Test Maintenance',
      'cost': cost ?? 5000,
      'date': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Generate test user profile data
  static Map<String, dynamic> userProfileData({
    required String email,
    String? displayName,
  }) {
    return {
      'email': email,
      'displayName': displayName ?? 'Test User',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'notificationSettings': {
        'pushEnabled': true,
        'maintenanceReminder': true,
        'inspectionReminder': true,
      },
    };
  }

  /// Generate test post data
  static Map<String, dynamic> postData({
    required String userId,
    String? content,
    String? category,
  }) {
    return {
      'userId': userId,
      'category': category ?? 'general',
      'content': content ?? 'Test post content #test',
      'visibility': 'public',
      'hashtags': ['test'],
      'likeCount': 0,
      'commentCount': 0,
      'viewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Generate test drive log data
  static Map<String, dynamic> driveLogData({
    required String userId,
    String? vehicleId,
    String? status,
  }) {
    return {
      'userId': userId,
      'vehicleId': vehicleId,
      'status': status ?? 'recording',
      'startTime': Timestamp.now(),
      'statistics': {
        'totalDistance': 0.0,
        'totalDuration': 0,
        'averageSpeed': 0.0,
        'maxSpeed': 0.0,
      },
      'isPublic': false,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Generate test drive spot data
  static Map<String, dynamic> driveSpotData({
    required String userId,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
  }) {
    return {
      'userId': userId,
      'name': name ?? 'Test Spot',
      'description': 'A test spot description',
      'category': category ?? 'scenicView',
      'location': {
        'latitude': latitude ?? 35.6762,
        'longitude': longitude ?? 139.6503,
      },
      'isPublic': true,
      'averageRating': 0.0,
      'ratingCount': 0,
      'visitCount': 0,
      'favoriteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
