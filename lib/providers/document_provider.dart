import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../core/error/app_error.dart';

/// 書類管理状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class DocumentProvider with ChangeNotifier {
  final DocumentService _documentService;

  DocumentProvider({required DocumentService documentService})
      : _documentService = documentService;

  List<Document> _documents = [];
  List<Document> _expiringDocuments = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  AppError? _error;
  StreamSubscription<List<Document>>? _documentsSubscription;

  List<Document> get documents => _documents;
  List<Document> get expiringDocuments => _expiringDocuments;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  /// ユーザーの書類一覧をリスニング
  void listenToDocuments({bool includeArchived = false}) {
    _documentsSubscription?.cancel();

    _documentsSubscription = _documentService.getUserDocuments(includeArchived: includeArchived).listen(
      (documents) {
        _documents = documents;
        _error = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
        _scheduleRetry(() => listenToDocuments(includeArchived: includeArchived));
      },
    );
  }

  void _scheduleRetry(VoidCallback action) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: 2 << _retryCount);
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  /// リソースの解放
  void stopListening() {
    _documentsSubscription?.cancel();
    _documentsSubscription = null;
    _retryTimer?.cancel();
    _retryCount = 0;
  }

  /// ログアウト時のクリーンアップ
  void clear() {
    stopListening();
    _documents = [];
    _expiringDocuments = [];
    _error = null;
    notifyListeners();
  }

  /// 期限が近い書類を取得
  Future<void> loadExpiringDocuments() async {
    _isLoading = true;
    notifyListeners();

    final result = await _documentService.getExpiringDocuments();
    result.when(
      success: (documents) {
        _expiringDocuments = documents;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 書類をアップロード
  Future<String?> uploadDocument({
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
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    // アップロード進捗をシミュレート（実際のアップロードは内部で行われる）
    _uploadProgress = 0.3;
    notifyListeners();

    final result = await _documentService.uploadDocument(
      fileBytes: fileBytes,
      fileName: fileName,
      type: type,
      title: title,
      vehicleId: vehicleId,
      maintenanceRecordId: maintenanceRecordId,
      invoiceId: invoiceId,
      description: description,
      documentDate: documentDate,
      expiryDate: expiryDate,
    );

    String? documentId;
    result.when(
      success: (id) {
        documentId = id;
        _uploadProgress = 1.0;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isUploading = false;
    notifyListeners();
    return documentId;
  }

  /// 書類情報を更新
  Future<bool> updateDocument(String documentId, {
    String? title,
    String? description,
    DateTime? documentDate,
    DateTime? expiryDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _documentService.updateDocument(
      documentId,
      title: title,
      description: description,
      documentDate: documentDate,
      expiryDate: expiryDate,
    );
    bool success = false;

    result.when(
      success: (_) {
        success = true;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 書類をアーカイブ
  Future<bool> archiveDocument(String documentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _documentService.archiveDocument(documentId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        _documents.removeWhere((doc) => doc.id == documentId);
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 書類を削除
  Future<bool> deleteDocument(String documentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _documentService.deleteDocument(documentId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        _documents.removeWhere((doc) => doc.id == documentId);
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 車両の書類を取得
  Future<List<Document>> getDocumentsByVehicle(String vehicleId) async {
    final result = await _documentService.getDocumentsByVehicle(vehicleId);
    return result.getOrElse([]);
  }

  /// 整備記録の書類を取得
  Future<List<Document>> getDocumentsByMaintenanceRecord(String maintenanceRecordId) async {
    final result = await _documentService.getDocumentsByMaintenanceRecord(maintenanceRecordId);
    return result.getOrElse([]);
  }

  /// 種別で書類を取得
  Future<List<Document>> getDocumentsByType(DocumentType type) async {
    final result = await _documentService.getDocumentsByType(type);
    return result.getOrElse([]);
  }

  /// 書類をフィルタリング
  List<Document> filterByType(DocumentType type) {
    return _documents.where((doc) => doc.type == type).toList();
  }

  /// 画像書類のみ
  List<Document> get imageDocuments {
    return _documents.where((doc) => doc.isImage).toList();
  }

  /// PDF書類のみ
  List<Document> get pdfDocuments {
    return _documents.where((doc) => doc.isPdf).toList();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
