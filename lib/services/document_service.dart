import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// 書類管理サービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class DocumentService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  DocumentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // コレクション参照
  CollectionReference<Map<String, dynamic>> get _documentsCollection =>
      _firestore.collection('documents');

  /// 書類をアップロードして登録
  Future<Result<String, AppError>> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    required DocumentType type,
    required String title,
    String? vehicleId,
    String? maintenanceRecordId,
    String? invoiceId,
    String? description,
    DateTime? documentDate,
    DateTime? expiryDate,
  }) async {
    if (currentUserId == null) {
      return Result.failure(
        const AppError.auth('User not authenticated'),
      );
    }

    try {
      // ファイルをStorageにアップロード
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'documents/$currentUserId/$timestamp-$fileName';
      final ref = _storage.ref().child(storagePath);

      // MIMEタイプを判定
      final mimeType = _getMimeType(fileName);

      await ref.putData(
        fileBytes,
        SettableMetadata(contentType: mimeType.mimeType),
      );
      final fileUrl = await ref.getDownloadURL();

      // Firestoreに書類情報を保存
      final now = DateTime.now();
      final document = Document(
        id: '', // Firestoreが生成
        userId: currentUserId!,
        vehicleId: vehicleId,
        maintenanceRecordId: maintenanceRecordId,
        invoiceId: invoiceId,
        type: type,
        title: title,
        description: description,
        fileUrl: fileUrl,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        documentDate: documentDate,
        expiryDate: expiryDate,
        uploadedBy: currentUserId,
        uploadedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _documentsCollection.add(document.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 書類情報を更新（ファイル以外）
  Future<Result<void, AppError>> updateDocument(String documentId, {
    String? title,
    String? description,
    DateTime? documentDate,
    DateTime? expiryDate,
    bool? isArchived,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (documentDate != null) updates['documentDate'] = Timestamp.fromDate(documentDate);
      if (expiryDate != null) updates['expiryDate'] = Timestamp.fromDate(expiryDate);
      if (isArchived != null) updates['isArchived'] = isArchived;

      await _documentsCollection.doc(documentId).update(updates);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 書類を取得
  Future<Result<Document?, AppError>> getDocument(String documentId) async {
    try {
      final doc = await _documentsCollection.doc(documentId).get();
      if (doc.exists) {
        return Result.success(Document.fromFirestore(doc));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザーの書類一覧を取得（Stream）
  Stream<List<Document>> getUserDocuments({bool includeArchived = false}) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    var query = _documentsCollection
        .where('userId', isEqualTo: currentUserId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    return query
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList();
    });
  }

  /// 車両に紐付く書類一覧を取得
  Future<Result<List<Document>, AppError>> getDocumentsByVehicle(String vehicleId) async {
    try {
      final snapshot = await _documentsCollection
          .where('vehicleId', isEqualTo: vehicleId)
          .where('isArchived', isEqualTo: false)
          .orderBy('uploadedAt', descending: true)
          .get();
      final documents = snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList();
      return Result.success(documents);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 整備記録に紐付く書類一覧を取得
  Future<Result<List<Document>, AppError>> getDocumentsByMaintenanceRecord(String maintenanceRecordId) async {
    try {
      final snapshot = await _documentsCollection
          .where('maintenanceRecordId', isEqualTo: maintenanceRecordId)
          .orderBy('uploadedAt', descending: true)
          .get();
      final documents = snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList();
      return Result.success(documents);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 種別で書類を検索
  Future<Result<List<Document>, AppError>> getDocumentsByType(DocumentType type) async {
    if (currentUserId == null) {
      return Result.success([]);
    }

    try {
      final snapshot = await _documentsCollection
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: type.name)
          .where('isArchived', isEqualTo: false)
          .orderBy('uploadedAt', descending: true)
          .get();
      final documents = snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList();
      return Result.success(documents);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 期限が近い書類を取得（30日以内）
  Future<Result<List<Document>, AppError>> getExpiringDocuments() async {
    if (currentUserId == null) {
      return Result.success([]);
    }

    try {
      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      final snapshot = await _documentsCollection
          .where('userId', isEqualTo: currentUserId)
          .where('expiryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater))
          .where('isArchived', isEqualTo: false)
          .get();
      final documents = snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList();
      return Result.success(documents);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 書類をアーカイブ
  Future<Result<void, AppError>> archiveDocument(String documentId) async {
    return updateDocument(documentId, isArchived: true);
  }

  /// 書類を削除（Storageファイルも削除）
  Future<Result<void, AppError>> deleteDocument(String documentId) async {
    try {
      // まず書類情報を取得
      final docResult = await getDocument(documentId);
      if (docResult.isFailure) {
        return Result.failure(docResult.errorOrNull!);
      }

      final document = docResult.valueOrNull;
      if (document == null) {
        return Result.failure(
          const AppError.notFound('Document not found'),
        );
      }

      // Storageからファイルを削除
      try {
        final ref = _storage.refFromURL(document.fileUrl);
        await ref.delete();
      } catch (e) {
        // Storage削除に失敗しても続行（ファイルが既に削除されている可能性）
      }

      // Firestoreから書類情報を削除
      await _documentsCollection.doc(documentId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// MIMEタイプを判定
  FileMimeType _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return FileMimeType.pdf;
      case 'jpg':
      case 'jpeg':
        return FileMimeType.jpeg;
      case 'png':
        return FileMimeType.png;
      case 'webp':
        return FileMimeType.webp;
      default:
        return FileMimeType.other;
    }
  }
}
