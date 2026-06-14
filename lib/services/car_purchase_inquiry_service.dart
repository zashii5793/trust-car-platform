import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/car_purchase_inquiry.dart';

/// Handles used-car purchase inquiries and deep-link generation for major
/// Japanese used-car marketplaces (カーセンサー, Goo-net).
///
/// Deep links use each site's public search URL parameters — no API key needed.
class CarPurchaseInquiryService {
  static const _collection = 'car_purchase_inquiries';

  final FirebaseFirestore _firestore;

  CarPurchaseInquiryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates a new purchase inquiry document.
  Future<Result<String, AppError>> createInquiry({
    required String userId,
    required CarPurchaseCondition condition,
    required String message,
    String? shopId,
  }) async {
    if (userId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('userId must not be empty'));
    }
    if (message.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('message must not be empty'));
    }
    if (condition.minPrice != null &&
        condition.maxPrice != null &&
        condition.minPrice! > condition.maxPrice!) {
      return const Result.failure(
          AppError.validation('minPrice must not exceed maxPrice'));
    }
    if (condition.minYear != null &&
        condition.maxYear != null &&
        condition.minYear! > condition.maxYear!) {
      return const Result.failure(
          AppError.validation('minYear must not exceed maxYear'));
    }

    try {
      final inquiry = CarPurchaseInquiry(
        id: '',
        userId: userId,
        shopId: shopId,
        condition: condition,
        message: message.trim(),
        createdAt: DateTime.now(),
      );
      final doc = await _firestore.collection(_collection).add(inquiry.toMap());
      return Result.success(doc.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns all inquiries created by [userId].
  Future<Result<List<CarPurchaseInquiry>, AppError>> getMyInquiries(
      String userId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return Result.success(
          snap.docs.map(CarPurchaseInquiry.fromFirestore).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Closes an inquiry. Only the inquiry owner may close it.
  Future<Result<void, AppError>> closeInquiry({
    required String inquiryId,
    required String requesterId,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(inquiryId).get();
      if (!doc.exists) {
        return Result.failure(
            AppError.notFound('Inquiry not found: $inquiryId'));
      }
      if (doc.data()?['userId'] != requesterId) {
        return const Result.failure(
            AppError.permission('only the inquiry owner can close it'));
      }
      await _firestore
          .collection(_collection)
          .doc(inquiryId)
          .update({'status': InquiryStatus.closed.name});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Generates deep-link search URLs for major Japanese used-car portals.
  ///
  /// Uses each portal's public search URL structure — no API contract needed.
  List<UsedCarSearchLink> generateSearchLinks(CarPurchaseCondition condition) {
    return [
      UsedCarSearchLink(
        siteName: 'カーセンサー',
        url: _buildCarSensorUrl(condition),
      ),
      UsedCarSearchLink(
        siteName: 'Goo-net',
        url: _buildGooNetUrl(condition),
      ),
    ];
  }

  String _buildCarSensorUrl(CarPurchaseCondition c) {
    final params = <String, String>{};
    if (c.maker != null) params['BRAND_CODE'] = _toCarSensorMakerCode(c.maker!);
    if (c.model != null) params['SERIES_CODE'] = Uri.encodeComponent(c.model!);
    if (c.minYear != null) params['NENKI_MIN'] = c.minYear.toString();
    if (c.maxYear != null) params['NENKI_MAX'] = c.maxYear.toString();
    if (c.maxPrice != null) params['KAKAKU_MAX'] = c.maxPrice.toString();
    if (c.maxMileage != null) params['MILEAGE_MAX'] = c.maxMileage.toString();

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://www.carsensor.net/usedcar/search/?$query';
  }

  String _buildGooNetUrl(CarPurchaseCondition c) {
    final params = <String, String>{'l': 'ja'};
    if (c.maker != null) params['maker'] = Uri.encodeComponent(c.maker!);
    if (c.model != null) params['model'] = Uri.encodeComponent(c.model!);
    if (c.minYear != null) params['year_min'] = c.minYear.toString();
    if (c.maxYear != null) params['year_max'] = c.maxYear.toString();
    if (c.maxPrice != null) params['price_max'] = c.maxPrice.toString();
    if (c.maxMileage != null) params['mileage_max'] = c.maxMileage.toString();

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://www.goo-net.com/usedcar/search/?$query';
  }

  // CarSensor uses numeric brand codes. Only common makers listed here;
  // unmapped makers fall back to URL-encoded name search.
  static const _carSensorMakerCodes = <String, String>{
    'Toyota': 'TOYOTA',
    'Honda': 'HONDA',
    'Nissan': 'NISSAN',
    'Mazda': 'MAZDA',
    'Subaru': 'SUBARU',
    'Mitsubishi': 'MITSUBISHI',
    'Suzuki': 'SUZUKI',
    'Daihatsu': 'DAIHATSU',
    'Lexus': 'LEXUS',
  };

  String _toCarSensorMakerCode(String maker) =>
      _carSensorMakerCodes[maker] ?? Uri.encodeComponent(maker);
}
