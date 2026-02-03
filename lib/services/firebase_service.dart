import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// Firebaseサービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // === 車両関連 ===

  /// 車両を登録
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async {
    try {
      final docRef = await _firestore.collection('vehicles').add(vehicle.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両情報を更新
  Future<Result<void, AppError>> updateVehicle(String vehicleId, Vehicle vehicle) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update(vehicle.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザーの車両一覧を取得（Stream版は後方互換性のため維持）
  Stream<List<Vehicle>> getUserVehicles() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('vehicles')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    });
  }

  /// 特定の車両を取得
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (doc.exists) {
        return Result.success(Vehicle.fromFirestore(doc));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両を削除
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ナンバープレートの重複チェック
  Future<Result<bool, AppError>> isLicensePlateExists(String licensePlate, {String? excludeVehicleId}) async {
    try {
      final query = _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: currentUserId)
          .where('licensePlate', isEqualTo: licensePlate);

      final snapshot = await query.get();

      // excludeVehicleIdがある場合は、そのIDを除外してチェック
      if (excludeVehicleId != null) {
        final exists = snapshot.docs.any((doc) => doc.id != excludeVehicleId);
        return Result.success(exists);
      }

      return Result.success(snapshot.docs.isNotEmpty);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // === メンテナンス履歴関連 ===

  /// 履歴を追加
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async {
    try {
      final docRef = await _firestore.collection('maintenance_records').add(record.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 履歴を更新
  Future<Result<void, AppError>> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async {
    try {
      await _firestore.collection('maintenance_records').doc(recordId).update(record.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両の履歴一覧を取得（Stream版は後方互換性のため維持）
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) {
    return _firestore
        .collection('maintenance_records')
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MaintenanceRecord.fromFirestore(doc)).toList();
    });
  }

  /// 履歴を削除
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async {
    try {
      await _firestore.collection('maintenance_records').doc(recordId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // === 画像アップロード ===

  /// 画像をアップロード（ファイル版）
  Future<Result<String, AppError>> uploadImage(io.File imageFile, String path) async {
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
  Future<Result<String, AppError>> uploadImageBytes(Uint8List imageBytes, String path) async {
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
  Future<Result<List<String>, AppError>> uploadImages(List<io.File> imageFiles, String basePath) async {
    try {
      List<String> urls = [];
      for (int i = 0; i < imageFiles.length; i++) {
        final result = await uploadImage(imageFiles[i], '$basePath/image_$i.jpg');
        final url = result.getOrThrow();
        urls.add(url);
      }
      return Result.success(urls);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // === 後方互換性のための非推奨メソッド ===
  // Provider側の修正が完了するまで維持

  /// @deprecated Use addVehicle instead
  @Deprecated('Use addVehicle with Result pattern instead')
  Future<String> addVehicleLegacy(Vehicle vehicle) async {
    final result = await addVehicle(vehicle);
    return result.getOrThrow();
  }

  /// @deprecated Use updateVehicle instead
  @Deprecated('Use updateVehicle with Result pattern instead')
  Future<void> updateVehicleLegacy(String vehicleId, Vehicle vehicle) async {
    final result = await updateVehicle(vehicleId, vehicle);
    result.getOrThrow();
  }

  /// @deprecated Use deleteVehicle instead
  @Deprecated('Use deleteVehicle with Result pattern instead')
  Future<void> deleteVehicleLegacy(String vehicleId) async {
    final result = await deleteVehicle(vehicleId);
    result.getOrThrow();
  }

  /// @deprecated Use uploadImageBytes instead
  @Deprecated('Use uploadImageBytes with Result pattern instead')
  Future<String> uploadImageBytesLegacy(Uint8List imageBytes, String path) async {
    final result = await uploadImageBytes(imageBytes, path);
    return result.getOrThrow();
  }
}
