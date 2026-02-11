import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_menu.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// サービスメニュー管理サービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class ServiceMenuService {
  final FirebaseFirestore _firestore;

  ServiceMenuService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // コレクション参照
  CollectionReference<Map<String, dynamic>> get _serviceMenusCollection =>
      _firestore.collection('service_menus');

  /// サービスメニューを登録
  Future<Result<String, AppError>> createServiceMenu(ServiceMenu menu) async {
    try {
      final docRef = await _serviceMenusCollection.add(menu.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを更新
  Future<Result<void, AppError>> updateServiceMenu(String menuId, ServiceMenu menu) async {
    try {
      await _serviceMenusCollection.doc(menuId).update(menu.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを取得
  Future<Result<ServiceMenu?, AppError>> getServiceMenu(String menuId) async {
    try {
      final doc = await _serviceMenusCollection.doc(menuId).get();
      if (doc.exists) {
        return Result.success(ServiceMenu.fromFirestore(doc));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 有効なサービスメニュー一覧を取得（Stream）
  Stream<List<ServiceMenu>> getActiveServiceMenus({String? shopId}) {
    var query = _serviceMenusCollection.where('isActive', isEqualTo: true);

    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    return query
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();
    });
  }

  /// カテゴリ別にサービスメニューを取得
  Future<Result<List<ServiceMenu>, AppError>> getServiceMenusByCategory(
    ServiceCategory category, {
    String? shopId,
  }) async {
    try {
      var query = _serviceMenusCollection
          .where('category', isEqualTo: category.name)
          .where('isActive', isEqualTo: true);

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snapshot = await query.orderBy('sortOrder').get();
      final menus = snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();
      return Result.success(menus);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 人気メニューを取得
  Future<Result<List<ServiceMenu>, AppError>> getPopularMenus({
    String? shopId,
    int limit = 10,
  }) async {
    try {
      var query = _serviceMenusCollection
          .where('isActive', isEqualTo: true)
          .where('isPopular', isEqualTo: true);

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snapshot = await query.orderBy('sortOrder').limit(limit).get();
      final menus = snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();
      return Result.success(menus);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// おすすめメニューを取得
  Future<Result<List<ServiceMenu>, AppError>> getRecommendedMenus({
    String? shopId,
    int limit = 10,
  }) async {
    try {
      var query = _serviceMenusCollection
          .where('isActive', isEqualTo: true)
          .where('isRecommended', isEqualTo: true);

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snapshot = await query.orderBy('sortOrder').limit(limit).get();
      final menus = snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();
      return Result.success(menus);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを検索
  Future<Result<List<ServiceMenu>, AppError>> searchServiceMenus({
    required String query,
    String? shopId,
  }) async {
    try {
      // Firestoreは部分一致検索をサポートしていないため、
      // 全件取得してクライアントサイドでフィルタリング
      var firestoreQuery = _serviceMenusCollection.where('isActive', isEqualTo: true);

      if (shopId != null) {
        firestoreQuery = firestoreQuery.where('shopId', isEqualTo: shopId);
      }

      final snapshot = await firestoreQuery.get();
      final allMenus = snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();

      // クライアントサイドでフィルタリング
      final lowerQuery = query.toLowerCase();
      final filteredMenus = allMenus.where((menu) {
        return menu.name.toLowerCase().contains(lowerQuery) ||
            (menu.description?.toLowerCase().contains(lowerQuery) ?? false) ||
            menu.category.displayName.contains(query);
      }).toList();

      return Result.success(filteredMenus);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを無効化
  Future<Result<void, AppError>> deactivateServiceMenu(String menuId) async {
    try {
      await _serviceMenusCollection.doc(menuId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを有効化
  Future<Result<void, AppError>> activateServiceMenu(String menuId) async {
    try {
      await _serviceMenusCollection.doc(menuId).update({
        'isActive': true,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サービスメニューを削除
  Future<Result<void, AppError>> deleteServiceMenu(String menuId) async {
    try {
      await _serviceMenusCollection.doc(menuId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 表示順を更新
  Future<Result<void, AppError>> updateSortOrder(String menuId, int sortOrder) async {
    try {
      await _serviceMenusCollection.doc(menuId).update({
        'sortOrder': sortOrder,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// カテゴリ別にグループ化されたメニューを取得
  Future<Result<Map<ServiceCategory, List<ServiceMenu>>, AppError>> getGroupedServiceMenus({
    String? shopId,
  }) async {
    try {
      var query = _serviceMenusCollection.where('isActive', isEqualTo: true);

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snapshot = await query.orderBy('sortOrder').get();
      final allMenus = snapshot.docs.map((doc) => ServiceMenu.fromFirestore(doc)).toList();

      // カテゴリ別にグループ化
      final grouped = <ServiceCategory, List<ServiceMenu>>{};
      for (final menu in allMenus) {
        grouped.putIfAbsent(menu.category, () => []);
        grouped[menu.category]!.add(menu);
      }

      return Result.success(grouped);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
