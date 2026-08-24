import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../core/utils/license_plate.dart';
import '../core/utils/auth_scoped_stream.dart';

/// Firebaseサービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class FirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Resolved on first use — touching FirebaseStorage.instance in the
  /// constructor crashes tests that never exercise storage (see ShopService).
  FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ??= FirebaseStorage.instance;

  /// Dependencies default to the singleton instances; tests inject fakes.
  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storageOverride = storage;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // === 車両関連 ===

  /// 車両を登録
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async {
    try {
      final docRef = await _firestore
          .collection(FirestoreCollections.vehicles)
          .add(vehicle.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両情報を更新
  Future<Result<void, AppError>> updateVehicle(
      String vehicleId, Vehicle vehicle) async {
    try {
      await _firestore
          .collection(FirestoreCollections.vehicles)
          .doc(vehicleId)
          .update(vehicle.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザーの車両一覧を取得（Stream版は後方互換性のため維持）
  /// Re-subscribes whenever the signed-in user changes.
  ///
  /// Screens start listening from initState, which on web runs before Firebase
  /// Auth has restored its session. Returning a one-shot empty stream there
  /// left the list permanently empty even after login succeeded, because the
  /// subscription never re-evaluated (and the provider's retry only fires on
  /// error, not on a legitimately empty result).
  Stream<List<Vehicle>> getUserVehicles() {
    return authScopedStream<List<Vehicle>>(
      authChanges: _auth.authStateChanges(),
      currentUser: () => _auth.currentUser,
      signedOutValue: const <Vehicle>[],
      onSignedIn: (user) => _firestore
          .collection(FirestoreCollections.vehicles)
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList()),
    );
  }

  /// 特定の車両を取得
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.vehicles)
          .doc(vehicleId)
          .get();
      if (doc.exists) {
        return Result.success(Vehicle.fromFirestore(doc));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両を削除（関連する整備記録もカスケード削除）
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async {
    try {
      final batch = _firestore.batch();

      // 関連する整備記録を取得して削除
      final records = await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .where('userId', isEqualTo: currentUserId)
          .where('vehicleId', isEqualTo: vehicleId)
          .get();

      for (final doc in records.docs) {
        batch.delete(doc.reference);
      }

      // 車両本体を削除
      batch.delete(
          _firestore.collection(FirestoreCollections.vehicles).doc(vehicleId));

      await batch.commit();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ナンバープレートの重複チェック
  Future<Result<bool, AppError>> isLicensePlateExists(String licensePlate,
      {String? excludeVehicleId}) async {
    try {
      // Compare on the normalised key rather than with an equality query.
      // Plates arrive full-width from a Japanese IME and half-width from OCR,
      // so an exact string match let the same car be registered twice —
      // "品川 300 あ 12-34" and "品川　３００　あ　１２－３４" were different
      // strings. Existing documents were also stored unnormalised, so a
      // normalised query would not find them either.
      final query = _firestore
          .collection(FirestoreCollections.vehicles)
          .where('userId', isEqualTo: currentUserId);

      final snapshot = await query.get();
      final target = licensePlateKey(licensePlate);
      if (target.isEmpty) return const Result.success(false);

      final exists = snapshot.docs.any((doc) {
        if (doc.id == excludeVehicleId) return false;
        final raw = doc.data()['licensePlate'];
        if (raw is! String || raw.isEmpty) return false;
        return licensePlateKey(raw) == target;
      });

      return Result.success(exists);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // === メンテナンス履歴関連 ===

  /// 履歴を追加
  Future<Result<String, AppError>> addMaintenanceRecord(
      MaintenanceRecord record) async {
    try {
      final docRef = await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .add(record.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 履歴を更新
  Future<Result<void, AppError>> updateMaintenanceRecord(
      String recordId, MaintenanceRecord record) async {
    try {
      await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .doc(recordId)
          .update(record.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両の履歴一覧を取得（Stream版は後方互換性のため維持）
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(
      String vehicleId) {
    // userId を条件に含めないと Firestore のルール
    // (resource.data.userId == request.auth.uid) をクエリが保証できず、
    // 一覧そのものが PERMISSION_DENIED で弾かれる。
    return _firestore
        .collection(FirestoreCollections.maintenanceRecords)
        .where('userId', isEqualTo: currentUserId)
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();
    });
  }

  /// Whether the user has logged any maintenance at all.
  ///
  /// Used by the getting-started checklist, which only needs "has anything
  /// been recorded", so this reads a single document instead of a list.
  /// Signed out counts as "nothing yet" rather than an error — the checklist
  /// should not show a failure state for a state that is simply empty.
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async {
    final uid = currentUserId;
    if (uid == null) return const Result.success(false);

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      return Result.success(snapshot.docs.isNotEmpty);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両の履歴一覧を取得（Future版、通知生成用）
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .where('userId', isEqualTo: currentUserId)
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      final records = snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();
      return Result.success(records);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 履歴を削除
  Future<Result<void, AppError>> deleteMaintenanceRecord(
      String recordId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .doc(recordId)
          .delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 複数車両の履歴を一括取得（N+1クエリ最適化）
  /// Firestoreの制限（whereIn最大30件）を考慮してバッチ処理
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(
    List<String> vehicleIds, {
    int limitPerVehicle = 20,
  }) async {
    if (vehicleIds.isEmpty) {
      return const Result.success({});
    }

    try {
      final result = <String, List<MaintenanceRecord>>{};

      // FirestoreのwhereIn制限（30件）に対応してバッチ処理
      const batchSize = 30;
      for (var i = 0; i < vehicleIds.length; i += batchSize) {
        final batchIds = vehicleIds.skip(i).take(batchSize).toList();

        final snapshot = await _firestore
            .collection(FirestoreCollections.maintenanceRecords)
            .where('userId', isEqualTo: currentUserId)
            .where('vehicleId', whereIn: batchIds)
            .orderBy('date', descending: true)
            .get();

        // 車両IDごとにグループ化
        for (final doc in snapshot.docs) {
          final record = MaintenanceRecord.fromFirestore(doc);
          result.putIfAbsent(record.vehicleId, () => []);
          // limitPerVehicle件まで追加
          if (result[record.vehicleId]!.length < limitPerVehicle) {
            result[record.vehicleId]!.add(record);
          }
        }
      }

      // 取得できなかった車両IDには空リストを設定
      for (final id in vehicleIds) {
        result.putIfAbsent(id, () => []);
      }

      return Result.success(result);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // === 画像アップロード ===

  /// 画像をアップロード（ファイル版）
  Future<Result<String, AppError>> uploadImage(
      io.File imageFile, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return Result.success(downloadUrl);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 画像をアップロード（バイト列版）- Web対応
  Future<Result<String, AppError>> uploadImageBytes(
      Uint8List imageBytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(imageBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return Result.success(downloadUrl);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 複数画像をアップロード
  Future<Result<List<String>, AppError>> uploadImages(
      List<io.File> imageFiles, String basePath) async {
    try {
      List<String> urls = [];
      for (int i = 0; i < imageFiles.length; i++) {
        final result =
            await uploadImage(imageFiles[i], '$basePath/image_$i.jpg');
        if (result.isFailure) {
          return Result.failure(
              result.errorOrNull ?? const AppError.unknown('Upload failed'));
        }
        urls.add(result.valueOrNull!);
      }
      return Result.success(urls);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 画像をバリデーション・圧縮してアップロード（推奨）
  /// [imageBytes] - 元画像のバイト列
  /// [path] - Storageのパス
  /// [imageService] - ImageProcessingServiceインスタンス
  Future<Result<String, AppError>> uploadProcessedImage(
    Uint8List imageBytes,
    String path, {
    required dynamic imageService,
  }) async {
    try {
      // Validate and compress
      final processResult = await imageService.processImage(imageBytes);
      if (processResult.isFailure) {
        return Result.failure(processResult.errorOrNull ??
            const AppError.unknown('Image processing failed'));
      }

      final processedBytes = processResult.valueOrNull!;

      // Upload compressed image
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        processedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return Result.success(downloadUrl);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
