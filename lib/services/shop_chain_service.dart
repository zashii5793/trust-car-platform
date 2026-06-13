import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';
import '../models/shop_chain.dart';

/// Manages corporate shop chains (e.g., コバック, ジェームス) that operate
/// multiple branch locations under a single brand.
class ShopChainService {
  static const _chains = 'shop_chains';
  static const _shops = 'shops';

  final FirebaseFirestore _firestore;

  ShopChainService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns chain details for [chainId].
  Future<Result<ShopChain, AppError>> getChain(String chainId) async {
    if (chainId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('chainId must not be empty'));
    }
    try {
      final doc = await _firestore.collection(_chains).doc(chainId).get();
      if (!doc.exists) {
        return Result.failure(
            AppError.notFound('ShopChain not found: $chainId'));
      }
      return Result.success(ShopChain.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns all shops belonging to [chainId].
  Future<Result<List<Shop>, AppError>> getShopsInChain(
      String chainId) async {
    if (chainId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('chainId must not be empty'));
    }
    try {
      final snap = await _firestore
          .collection(_shops)
          .where('chainId', isEqualTo: chainId)
          .get();
      final shops = snap.docs.map(Shop.fromFirestore).toList();
      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Creates a new chain entry and returns its document ID.
  Future<Result<String, AppError>> createChain({
    required String name,
    String? website,
    String? nationalPhone,
    String? logoUrl,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('chain name must not be empty'));
    }
    try {
      final now = DateTime.now();
      final chain = ShopChain(
        id: '',
        name: name.trim(),
        website: website,
        nationalPhone: nationalPhone,
        logoUrl: logoUrl,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
      final doc = await _firestore.collection(_chains).add(chain.toMap());
      return Result.success(doc.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Associates [shopId] with [chainId]. Only the shop owner may call this.
  Future<Result<void, AppError>> linkShopToChain({
    required String shopId,
    required String chainId,
    required String requesterId,
  }) async {
    if (shopId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('shopId must not be empty'));
    }
    if (chainId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('chainId must not be empty'));
    }
    try {
      final shopDoc =
          await _firestore.collection(_shops).doc(shopId).get();
      if (!shopDoc.exists) {
        return Result.failure(AppError.notFound('Shop not found: $shopId'));
      }

      final ownerId = shopDoc.data()?['ownerId'] as String?;
      if (ownerId != requesterId) {
        return const Result.failure(
            AppError.permission('only the shop owner can link to a chain'));
      }

      final chainDoc =
          await _firestore.collection(_chains).doc(chainId).get();
      final chainName = chainDoc.exists
          ? (chainDoc.data()?['name'] as String?) ?? ''
          : '';

      await _firestore.collection(_shops).doc(shopId).update({
        'chainId': chainId,
        'chainName': chainName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Increment shopCount on the chain document
      if (chainDoc.exists) {
        await _firestore.collection(_chains).doc(chainId).update({
          'shopCount': FieldValue.increment(1),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Removes [shopId] from its current chain. Only the shop owner may call this.
  Future<Result<void, AppError>> unlinkShopFromChain({
    required String shopId,
    required String requesterId,
  }) async {
    if (shopId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('shopId must not be empty'));
    }
    try {
      final shopDoc =
          await _firestore.collection(_shops).doc(shopId).get();
      if (!shopDoc.exists) {
        return Result.failure(AppError.notFound('Shop not found: $shopId'));
      }

      final ownerId = shopDoc.data()?['ownerId'] as String?;
      if (ownerId != requesterId) {
        return const Result.failure(
            AppError.permission('only the shop owner can unlink from a chain'));
      }

      final chainId = shopDoc.data()?['chainId'] as String?;

      await _firestore.collection(_shops).doc(shopId).update({
        'chainId': FieldValue.delete(),
        'chainName': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Decrement shopCount on the chain document
      if (chainId != null && chainId.isNotEmpty) {
        final chainDoc =
            await _firestore.collection(_chains).doc(chainId).get();
        if (chainDoc.exists) {
          await _firestore.collection(_chains).doc(chainId).update({
            'shopCount': FieldValue.increment(-1),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
