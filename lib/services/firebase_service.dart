import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // === 車両関連 ===

  // 車両を登録
  Future<String> addVehicle(Vehicle vehicle) async {
    try {
      final docRef = await _firestore.collection('vehicles').add(vehicle.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('車両の登録に失敗しました: $e');
    }
  }

  // 車両情報を更新
  Future<void> updateVehicle(String vehicleId, Vehicle vehicle) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update(vehicle.toMap());
    } catch (e) {
      throw Exception('車両情報の更新に失敗しました: $e');
    }
  }

  // ユーザーの車両一覧を取得
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

  // 特定の車両を取得
  Future<Vehicle?> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (doc.exists) {
        return Vehicle.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('車両情報の取得に失敗しました: $e');
    }
  }

  // 車両を削除
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).delete();
    } catch (e) {
      throw Exception('車両の削除に失敗しました: $e');
    }
  }

  // === メンテナンス履歴関連 ===

  // 履歴を追加
  Future<String> addMaintenanceRecord(MaintenanceRecord record) async {
    try {
      final docRef = await _firestore.collection('maintenance_records').add(record.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('履歴の登録に失敗しました: $e');
    }
  }

  // 履歴を更新
  Future<void> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async {
    try {
      await _firestore.collection('maintenance_records').doc(recordId).update(record.toMap());
    } catch (e) {
      throw Exception('履歴の更新に失敗しました: $e');
    }
  }

  // 車両の履歴一覧を取得
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

  // 履歴を削除
  Future<void> deleteMaintenanceRecord(String recordId) async {
    try {
      await _firestore.collection('maintenance_records').doc(recordId).delete();
    } catch (e) {
      throw Exception('履歴の削除に失敗しました: $e');
    }
  }

  // === 画像アップロード ===

  // 画像をアップロード（ファイル版）
  Future<String> uploadImage(io.File imageFile, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }

  // 画像をアップロード（バイト列版）- Web対応
  Future<String> uploadImageBytes(Uint8List imageBytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(imageBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }

  // 複数画像をアップロード
  Future<List<String>> uploadImages(List<io.File> imageFiles, String basePath) async {
    List<String> urls = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImage(imageFiles[i], '$basePath/image_$i.jpg');
      urls.add(url);
    }
    return urls;
  }
}
