import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/part_listing.dart';
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

  PartListingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseService? firebaseService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firebaseService = firebaseService ?? FirebaseService();

  static const String _collection = 'user_part_listings';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collection);

  /// Create a new part listing.
  /// Uploads images first, then writes the Firestore document.
  Future<Result<String, AppError>> createListing(
    CreatePartListingInput input,
  ) async {
    final uid = _auth.currentUser?.uid;
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
}
