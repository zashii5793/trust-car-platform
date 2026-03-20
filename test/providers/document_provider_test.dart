// DocumentProvider Unit Tests

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/document_provider.dart';
import 'package:trust_car_platform/services/document_service.dart';
import 'package:trust_car_platform/models/document.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock DocumentService
// ---------------------------------------------------------------------------

class MockDocumentService implements DocumentService {
  final _streamController = StreamController<List<Document>>.broadcast();

  Result<List<Document>, AppError> expiringResult = const Result.success([]);
  Result<String, AppError> uploadResult = const Result.success('doc_new');
  Result<void, AppError> updateResult = const Result.success(null);
  Result<void, AppError> archiveResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);
  Result<List<Document>, AppError> byVehicleResult = const Result.success([]);
  Result<List<Document>, AppError> byMaintenanceResult =
      const Result.success([]);
  Result<List<Document>, AppError> byTypeResult = const Result.success([]);

  // Call tracking
  int uploadCallCount = 0;
  int archiveCallCount = 0;
  int deleteCallCount = 0;
  String? lastArchivedId;
  String? lastDeletedId;

  void emitDocuments(List<Document> docs) => _streamController.add(docs);
  void emitError(Object error) => _streamController.addError(error);

  @override
  Stream<List<Document>> getUserDocuments({bool includeArchived = false}) =>
      _streamController.stream;

  @override
  Future<Result<List<Document>, AppError>> getExpiringDocuments() async =>
      expiringResult;

  @override
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
    uploadCallCount++;
    return uploadResult;
  }

  @override
  Future<Result<void, AppError>> updateDocument(
    String documentId, {
    String? title,
    String? description,
    DateTime? documentDate,
    DateTime? expiryDate,
    bool? isArchived,
  }) async => updateResult;

  @override
  Future<Result<void, AppError>> archiveDocument(String documentId) async {
    archiveCallCount++;
    lastArchivedId = documentId;
    return archiveResult;
  }

  @override
  Future<Result<void, AppError>> deleteDocument(String documentId) async {
    deleteCallCount++;
    lastDeletedId = documentId;
    return deleteResult;
  }

  @override
  Future<Result<List<Document>, AppError>> getDocumentsByVehicle(
          String vehicleId) async =>
      byVehicleResult;

  @override
  Future<Result<List<Document>, AppError>> getDocumentsByMaintenanceRecord(
          String maintenanceRecordId) async =>
      byMaintenanceResult;

  @override
  Future<Result<List<Document>, AppError>> getDocumentsByType(
          DocumentType type) async =>
      byTypeResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  void dispose() => _streamController.close();
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Document _makeDoc({
  String id = 'doc1',
  String userId = 'user1',
  DocumentType type = DocumentType.inspectionRecord,
  FileMimeType mimeType = FileMimeType.pdf,
  bool isArchived = false,
  DateTime? expiryDate,
}) {
  final now = DateTime.now();
  return Document(
    id: id,
    userId: userId,
    type: type,
    title: 'テスト書類 $id',
    fileUrl: 'https://example.com/$id.pdf',
    mimeType: mimeType,
    isArchived: isArchived,
    expiryDate: expiryDate,
    uploadedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

DocumentProvider _makeProvider(MockDocumentService service) {
  return DocumentProvider(documentService: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentProvider', () {
    late MockDocumentService mockService;
    late DocumentProvider provider;

    setUp(() {
      mockService = MockDocumentService();
      provider = _makeProvider(mockService);
    });

    tearDown(() {
      provider.stopListening();
      mockService.dispose();
    });

    // ── 初期状態 ──────────────────────────────────────────────────────────────

    group('初期状態', () {
      test('初期状態は空でエラーなし', () {
        expect(provider.documents, isEmpty);
        expect(provider.expiringDocuments, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.isUploading, false);
        expect(provider.uploadProgress, 0.0);
        expect(provider.error, isNull);
      });
    });

    // ── listenToDocuments ─────────────────────────────────────────────────────

    group('listenToDocuments (Stream)', () {
      test('Stream から書類を受け取ると documents が更新される', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc(id: 'd1'), _makeDoc(id: 'd2')]);
        await Future.microtask(() {});

        expect(provider.documents.length, 2);
        expect(provider.error, isNull);
      });

      test('Stream エラーで error が設定される', () async {
        provider.listenToDocuments();
        mockService.emitError(
            Exception('[cloud_firestore/permission-denied] Access denied'));
        await Future.microtask(() {});

        expect(provider.error, isNotNull);
      });

      test('stopListening で購読が解除される', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc()]);
        await Future.microtask(() {});

        provider.stopListening();
        mockService.emitDocuments([_makeDoc(id: 'after_stop')]);
        await Future.microtask(() {});

        expect(provider.documents.length, 1);
      });
    });

    // ── loadExpiringDocuments ─────────────────────────────────────────────────

    group('loadExpiringDocuments', () {
      test('期限が近い書類を読み込める', () async {
        final soon = DateTime.now().add(const Duration(days: 3));
        mockService.expiringResult = Result.success([
          _makeDoc(id: 'exp1', expiryDate: soon),
        ]);

        await provider.loadExpiringDocuments();

        expect(provider.expiringDocuments.length, 1);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.expiringResult =
            Result.failure(AppError.network('failed'));

        await provider.loadExpiringDocuments();

        expect(provider.error, isNotNull);
        expect(provider.expiringDocuments, isEmpty);
      });
    });

    // ── uploadDocument ────────────────────────────────────────────────────────

    group('uploadDocument', () {
      test('アップロード成功で documentId を返す', () async {
        mockService.uploadResult = const Result.success('new_doc_id');

        final id = await provider.uploadDocument(
          fileBytes: Uint8List(0),
          fileName: 'test.pdf',
          type: DocumentType.inspectionRecord,
          title: 'テスト書類',
        );

        expect(id, 'new_doc_id');
        expect(provider.isUploading, false);
        expect(provider.error, isNull);
      });

      test('アップロード失敗で null を返しエラーが設定される', () async {
        mockService.uploadResult =
            Result.failure(AppError.server('upload failed'));

        final id = await provider.uploadDocument(
          fileBytes: Uint8List(0),
          fileName: 'test.pdf',
          type: DocumentType.inspectionRecord,
          title: 'テスト書類',
        );

        expect(id, isNull);
        expect(provider.isUploading, false);
        expect(provider.error, isNotNull);
      });

      test('アップロード成功後は uploadProgress が 1.0 になる', () async {
        final id = await provider.uploadDocument(
          fileBytes: Uint8List(0),
          fileName: 'test.pdf',
          type: DocumentType.inspectionRecord,
          title: 'テスト書類',
        );

        expect(id, isNotNull);
        expect(provider.uploadProgress, 1.0);
      });
    });

    // ── updateDocument ────────────────────────────────────────────────────────

    group('updateDocument', () {
      test('更新成功で true を返す', () async {
        final success = await provider.updateDocument('doc1', title: '新タイトル');
        expect(success, true);
        expect(provider.error, isNull);
      });

      test('更新失敗で false を返しエラーが設定される', () async {
        mockService.updateResult =
            Result.failure(AppError.permission('Permission denied'));

        final success = await provider.updateDocument('doc1');

        expect(success, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── archiveDocument ───────────────────────────────────────────────────────

    group('archiveDocument', () {
      test('アーカイブ成功で書類一覧から除去される', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc(id: 'd1'), _makeDoc(id: 'd2')]);
        await Future.microtask(() {});

        final success = await provider.archiveDocument('d1');

        expect(success, true);
        expect(provider.documents.length, 1);
        expect(provider.documents.first.id, 'd2');
      });

      test('アーカイブ失敗では書類一覧が変わらない', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc(id: 'd1')]);
        await Future.microtask(() {});

        mockService.archiveResult =
            Result.failure(AppError.permission('Permission denied'));
        final success = await provider.archiveDocument('d1');

        expect(success, false);
        expect(provider.documents.length, 1);
      });

      test('正しい documentId でアーカイブを呼び出す', () async {
        await provider.archiveDocument('target_doc');
        expect(mockService.lastArchivedId, 'target_doc');
      });
    });

    // ── deleteDocument ────────────────────────────────────────────────────────

    group('deleteDocument', () {
      test('削除成功で書類一覧から除去される', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc(id: 'd1'), _makeDoc(id: 'd2')]);
        await Future.microtask(() {});

        final success = await provider.deleteDocument('d1');

        expect(success, true);
        expect(provider.documents.length, 1);
        expect(provider.documents.first.id, 'd2');
      });

      test('削除失敗では書類一覧が変わらない', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc(id: 'd1')]);
        await Future.microtask(() {});

        mockService.deleteResult =
            Result.failure(AppError.network('failed'));
        final success = await provider.deleteDocument('d1');

        expect(success, false);
        expect(provider.documents.length, 1);
      });
    });

    // ── filterByType ──────────────────────────────────────────────────────────

    group('filterByType', () {
      test('指定した type の書類のみ返す', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([
          _makeDoc(id: 'd1', type: DocumentType.inspectionRecord),
          _makeDoc(id: 'd2', type: DocumentType.inspectionCert),
          _makeDoc(id: 'd3', type: DocumentType.inspectionRecord),
        ]);
        await Future.microtask(() {});

        final filtered = provider.filterByType(DocumentType.inspectionRecord);

        expect(filtered.length, 2);
        expect(filtered.every((d) => d.type == DocumentType.inspectionRecord),
            true);
      });

      test('一致する type がなければ空リストを返す', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([
          _makeDoc(id: 'd1', type: DocumentType.inspectionRecord),
        ]);
        await Future.microtask(() {});

        final filtered = provider.filterByType(DocumentType.inspectionCert);
        expect(filtered, isEmpty);
      });
    });

    // ── imageDocuments / pdfDocuments ─────────────────────────────────────────

    group('imageDocuments / pdfDocuments', () {
      test('imageDocuments は jpeg/png のみ含む', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([
          _makeDoc(id: 'd1', mimeType: FileMimeType.jpeg),
          _makeDoc(id: 'd2', mimeType: FileMimeType.png),
          _makeDoc(id: 'd3', mimeType: FileMimeType.pdf),
        ]);
        await Future.microtask(() {});

        final images = provider.imageDocuments;

        expect(images.length, 2);
        expect(images.every((d) => d.isImage), true);
      });

      test('pdfDocuments は pdf のみ含む', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([
          _makeDoc(id: 'd1', mimeType: FileMimeType.pdf),
          _makeDoc(id: 'd2', mimeType: FileMimeType.jpeg),
        ]);
        await Future.microtask(() {});

        final pdfs = provider.pdfDocuments;

        expect(pdfs.length, 1);
        expect(pdfs.first.isPdf, true);
      });
    });

    // ── clear ─────────────────────────────────────────────────────────────────

    group('clear', () {
      test('clear で全状態がリセットされる', () async {
        provider.listenToDocuments();
        mockService.emitDocuments([_makeDoc()]);
        await Future.microtask(() {});

        provider.clear();

        expect(provider.documents, isEmpty);
        expect(provider.expiringDocuments, isEmpty);
        expect(provider.error, isNull);
      });
    });

    // ── Edge Cases ────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('getDocumentsByVehicle が失敗しても空リストで返る', () async {
        mockService.byVehicleResult =
            Result.failure(AppError.network('failed'));
        final result = await provider.getDocumentsByVehicle('v1');
        expect(result, isEmpty);
      });

      test('getDocumentsByType が失敗しても空リストで返る', () async {
        mockService.byTypeResult = Result.failure(AppError.network('failed'));
        final result =
            await provider.getDocumentsByType(DocumentType.inspectionRecord);
        expect(result, isEmpty);
      });

      test('書類ゼロのとき imageDocuments と pdfDocuments は空', () {
        expect(provider.imageDocuments, isEmpty);
        expect(provider.pdfDocuments, isEmpty);
      });

      test('errorMessage は error がないとき null', () {
        expect(provider.errorMessage, isNull);
      });

      test('isRetryable はリトライ可能エラーのとき true', () async {
        provider.listenToDocuments();
        mockService.emitError(
            Exception('[cloud_firestore/unavailable] Service unavailable'));
        await Future.microtask(() {});

        expect(provider.isRetryable, true);
      });
    });
  });
}
