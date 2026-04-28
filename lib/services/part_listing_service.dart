import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/part_listing.dart';
import '../models/user_part_listing.dart';
import 'firebase_service.dart';

/// Condition (used state) of a part being listed for sale
enum PartCondition {
  brandNew('新品'),
  likeNew('未使用に近い'),
  goodCondition('目立った傷なし'),
  minorScratches('やや傷あり'),
  heavilyUsed('傷・汚れあり');

  final String displayName;
  const PartCondition(this.displayName);

  static PartCondition? fromString(String? value) {
    if (value == null) return null;
    try {
      return PartCondition.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Shipping method for the listing
enum ShippingMethod {
  includedInPrice('送料込み'),
  buyerPays('着払い'),
  faceToFace('直接取引');

  final String displayName;
  const ShippingMethod(this.displayName);

  static ShippingMethod? fromString(String? value) {
    if (value == null) return null;
    try {
      return ShippingMethod.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Commission rate applied to each sale (8%, minimum 100 yen)
const double kCommissionRate = 0.08;
const int kCommissionMin = 100;

/// Calculate seller's net payout after commission
int calculatePayout(int price) {
  final commission = (price * kCommissionRate).ceil();
  final deducted = commission < kCommissionMin ? kCommissionMin : commission;
  final payout = price - deducted;
  return payout < 0 ? 0 : payout;
}

/// Data class for creating a new user-submitted part listing
class CreatePartListingInput {
  final String title;
  final PartCategory category;
  final PartCondition condition;
  final int price;
  final String description;
  final String? compatibleVehicle;
  final List<File> images;
  final ShippingMethod shippingMethod;

  const CreatePartListingInput({
    required this.title,
    required this.category,
    required this.condition,
    required this.price,
    required this.description,
    this.compatibleVehicle,
    this.images = const [],
    required this.shippingMethod,
  });
}

/// Service for user-submitted part listings in the marketplace
class PartListingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseService _firebaseService;
  // Injectable for testability (mirrors DriveRecordingProvider pattern)
  final String? Function() _getCurrentUid;

  PartListingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseService? firebaseService,
    String? Function()? getCurrentUid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firebaseService = firebaseService ?? FirebaseService(),
        _getCurrentUid = getCurrentUid ??
            (() => (auth ?? FirebaseAuth.instance).currentUser?.uid);

  static const String _collection = 'user_part_listings';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collection);

  /// Create a new part listing.
  /// Uploads images first, then writes the Firestore document.
  Future<Result<String, AppError>> createListing(
    CreatePartListingInput input,
  ) async {
    final uid = _getCurrentUid();
    if (uid == null) {
      return const Result.failure(
        AppError.auth('Not authenticated', type: AuthErrorType.unknown),
      );
    }

    // Validate required fields
    if (input.title.trim().isEmpty) {
      return const Result.failure(
        AppError.validation('Title is required', field: 'title'),
      );
    }
    if (input.price <= 0) {
      return const Result.failure(
        AppError.validation('Price must be greater than 0', field: 'price'),
      );
    }

    try {
      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      if (input.images.isNotEmpty) {
        final basePath = 'user_part_listings/$uid/${DateTime.now().millisecondsSinceEpoch}';
        final uploadResult =
            await _firebaseService.uploadImages(input.images, basePath);
        if (uploadResult.isFailure) {
          return Result.failure(uploadResult.errorOrNull!);
        }
        imageUrls = uploadResult.valueOrNull!;
      }

      // Write Firestore document
      final now = DateTime.now();
      final doc = _ref.doc();
      await doc.set({
        'id': doc.id,
        'sellerId': uid,
        'title': input.title.trim(),
        'category': input.category.name,
        'condition': input.condition.name,
        'price': input.price,
        'description': input.description.trim(),
        'compatibleVehicle': input.compatibleVehicle?.trim(),
        'imageUrls': imageUrls,
        'shippingMethod': input.shippingMethod.name,
        'payout': calculatePayout(input.price),
        'status': 'active',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      return Result.success(doc.id);
    } on FirebaseException catch (e) {
      return Result.failure(AppError.unknown(
        'Firestore write failed: ${e.message}',
        originalError: e,
      ));
    } catch (e) {
      return Result.failure(AppError.unknown(
        'Failed to create listing',
        originalError: e,
      ));
    }
  }

  /// Get listings created by the specified seller, ordered by createdAt descending.
  Future<Result<List<UserPartListing>, AppError>> getMyListings(
    String sellerId,
  ) async {
    if (sellerId.isEmpty) {
      return const Result.failure(
        AppError.validation('Seller ID is required', field: 'sellerId'),
      );
    }
    final currentUid = _getCurrentUid();
    if (currentUid == null) {
      return const Result.failure(
        AppError.auth('認証が必要です', type: AuthErrorType.unknown),
      );
    }
    if (currentUid != sellerId) {
      return const Result.failure(
        AppError.auth('他のユーザーの出品一覧は取得できません', type: AuthErrorType.unknown),
      );
    }

    try {
      final snapshot = await _ref
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      final listings = snapshot.docs
          .map((doc) => UserPartListing.fromFirestore(doc))
          .toList();

      return Result.success(listings);
    } on FirebaseException catch (e) {
      return Result.failure(AppError.unknown(
        'Failed to fetch listings: ${e.message}',
        originalError: e,
      ));
    } catch (e) {
      return Result.failure(AppError.unknown(
        'Failed to fetch listings',
        originalError: e,
      ));
    }
  }

  /// Update the status of a listing (e.g. soldOut, cancelled).
  Future<Result<void, AppError>> updateListingStatus(
    String listingId,
    PartListingStatus status,
  ) async {
    if (listingId.isEmpty) {
      return const Result.failure(
        AppError.validation('Listing ID is required', field: 'listingId'),
      );
    }

    try {
      await _ref.doc(listingId).update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return const Result.success(null);
    } on FirebaseException catch (e) {
      return Result.failure(AppError.unknown(
        'Failed to update listing status: ${e.message}',
        originalError: e,
      ));
    } catch (e) {
      return Result.failure(AppError.unknown(
        'Failed to update listing status',
        originalError: e,
      ));
    }
  }
}
