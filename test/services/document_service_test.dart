// DocumentService / Document Model Unit Tests
//
// Since DocumentService requires FirebaseFirestore/FirebaseStorage,
// we test pure business logic on the Document model:
//   1. DocumentType / FileMimeType enum behavior
//   2. Document.isImage / isPdf
//   3. Document.isExpired / isExpiringSoon (date-based logic)
//   4. Document.fileSizeDisplay (byte formatting)
//   5. AppError patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/document.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Document _makeDocument({
  String id = 'doc1',
  DocumentType type = DocumentType.other,
  FileMimeType mimeType = FileMimeType.pdf,
  int? fileSize,
  DateTime? expiryDate,
}) {
  final now = DateTime.now();
  return Document(
    id: id,
    userId: 'user1',
    type: type,
    title: 'テストドキュメント',
    fileUrl: 'https://example.com/file.pdf',
    mimeType: mimeType,
    fileSize: fileSize,
    expiryDate: expiryDate,
    uploadedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentType enum', () {
    test('全タイプ name が空でない', () {
      for (final type in DocumentType.values) {
        expect(type.name, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(DocumentType.fromString('vehicleRegistration'), DocumentType.vehicleRegistration);
      expect(DocumentType.fromString('invoice'), DocumentType.invoice);
      expect(DocumentType.fromString('manual'), DocumentType.manual);
      expect(DocumentType.fromString('other'), DocumentType.other);
    });

    test('fromString(null) は null を返す', () {
      expect(DocumentType.fromString(null), isNull);
    });

    test('fromString 不明な文字列は null を返す', () {
      expect(DocumentType.fromString(''), isNull);
      expect(DocumentType.fromString('unknown'), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final type in DocumentType.values) {
        expect(DocumentType.fromString(type.name), type);
      }
    });
  });

  // ── FileMimeType enum ─────────────────────────────────────────────────────

  group('FileMimeType enum', () {
    test('fromMimeType: application/pdf → pdf', () {
      expect(FileMimeType.fromMimeType('application/pdf'), FileMimeType.pdf);
    });

    test('fromMimeType: image/jpeg → jpeg', () {
      expect(FileMimeType.fromMimeType('image/jpeg'), FileMimeType.jpeg);
    });

    test('fromMimeType: image/png → png', () {
      expect(FileMimeType.fromMimeType('image/png'), FileMimeType.png);
    });

    test('fromMimeType: image/webp → webp', () {
      expect(FileMimeType.fromMimeType('image/webp'), FileMimeType.webp);
    });

    test('fromMimeType: 不明な MimeType → other', () {
      expect(FileMimeType.fromMimeType('application/zip'), FileMimeType.other);
      expect(FileMimeType.fromMimeType(null), FileMimeType.other);
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(FileMimeType.fromString('pdf'), FileMimeType.pdf);
      expect(FileMimeType.fromString('jpeg'), FileMimeType.jpeg);
      expect(FileMimeType.fromString('png'), FileMimeType.png);
      expect(FileMimeType.fromString('webp'), FileMimeType.webp);
      expect(FileMimeType.fromString('other'), FileMimeType.other);
    });

    test('全 enum 値を往復変換できる', () {
      for (final mime in FileMimeType.values) {
        expect(FileMimeType.fromString(mime.name), mime);
      }
    });
  });

  // ── Document.isImage / isPdf ──────────────────────────────────────────────

  group('Document.isImage', () {
    test('jpeg → true', () {
      expect(_makeDocument(mimeType: FileMimeType.jpeg).isImage, true);
    });

    test('png → true', () {
      expect(_makeDocument(mimeType: FileMimeType.png).isImage, true);
    });

    test('webp → true', () {
      expect(_makeDocument(mimeType: FileMimeType.webp).isImage, true);
    });

    test('pdf → false', () {
      expect(_makeDocument(mimeType: FileMimeType.pdf).isImage, false);
    });

    test('other → false', () {
      expect(_makeDocument(mimeType: FileMimeType.other).isImage, false);
    });
  });

  group('Document.isPdf', () {
    test('pdf → true', () {
      expect(_makeDocument(mimeType: FileMimeType.pdf).isPdf, true);
    });

    test('jpeg → false', () {
      expect(_makeDocument(mimeType: FileMimeType.jpeg).isPdf, false);
    });

    test('other → false', () {
      expect(_makeDocument(mimeType: FileMimeType.other).isPdf, false);
    });
  });

  // ── Document.isExpired ────────────────────────────────────────────────────

  group('Document.isExpired', () {
    test('expiryDate が null のとき false', () {
      final doc = _makeDocument(expiryDate: null);
      expect(doc.isExpired, false);
    });

    test('expiryDate が過去のとき true', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(doc.isExpired, true);
    });

    test('expiryDate が未来のとき false', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(doc.isExpired, false);
    });

    test('1年前の有効期限は期限切れ', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(doc.isExpired, true);
    });
  });

  // ── Document.isExpiringSoon ───────────────────────────────────────────────

  group('Document.isExpiringSoon', () {
    test('expiryDate が null のとき false', () {
      final doc = _makeDocument(expiryDate: null);
      expect(doc.isExpiringSoon, false);
    });

    test('既に期限切れのとき false（isExpired=true はスキップ）', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(doc.isExpiringSoon, false);
    });

    test('30日以内（29日後）のとき true', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 29)),
      );
      expect(doc.isExpiringSoon, true);
    });

    test('ちょうど30日後のとき true', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(doc.isExpiringSoon, true);
    });

    test('31日後のとき false', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 31)),
      );
      expect(doc.isExpiringSoon, false);
    });

    test('明日が期限のとき true', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(doc.isExpiringSoon, true);
    });

    test('1年後は false', () {
      final doc = _makeDocument(
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );
      expect(doc.isExpiringSoon, false);
    });
  });

  // ── Document.fileSizeDisplay ──────────────────────────────────────────────

  group('Document.fileSizeDisplay', () {
    test('fileSize が null のとき「不明」', () {
      final doc = _makeDocument(fileSize: null);
      expect(doc.fileSizeDisplay, '不明');
    });

    test('1023 bytes のとき「1023 B」', () {
      final doc = _makeDocument(fileSize: 1023);
      expect(doc.fileSizeDisplay, '1023 B');
    });

    test('1024 bytes = 1.0 KB のとき「1.0 KB」', () {
      final doc = _makeDocument(fileSize: 1024);
      expect(doc.fileSizeDisplay, '1.0 KB');
    });

    test('1536 bytes = 1.5 KB のとき「1.5 KB」', () {
      final doc = _makeDocument(fileSize: 1536);
      expect(doc.fileSizeDisplay, '1.5 KB');
    });

    test('1 MB = 1048576 bytes のとき「1.0 MB」', () {
      final doc = _makeDocument(fileSize: 1024 * 1024);
      expect(doc.fileSizeDisplay, '1.0 MB');
    });

    test('2.5 MB のとき「2.5 MB」', () {
      final doc = _makeDocument(fileSize: (2.5 * 1024 * 1024).toInt());
      expect(doc.fileSizeDisplay, '2.5 MB');
    });

    test('0 bytes のとき「0 B」', () {
      final doc = _makeDocument(fileSize: 0);
      expect(doc.fileSizeDisplay, '0 B');
    });

    test('1023 * 1024 bytes (< 1MB) のとき KB 表示', () {
      final doc = _makeDocument(fileSize: 1023 * 1024);
      expect(doc.fileSizeDisplay, contains('KB'));
      expect(doc.fileSizeDisplay, isNot(contains('MB')));
    });
  });

  // ── Document equality ─────────────────────────────────────────────────────

  group('Document equality', () {
    test('同じ id は等しい', () {
      final a = _makeDocument(id: 'doc1', type: DocumentType.invoice);
      final b = _makeDocument(id: 'doc1', type: DocumentType.manual);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeDocument(id: 'doc1');
      final b = _makeDocument(id: 'doc2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（ドキュメントサービスエラーシナリオ）', () {
    test('network error は isRetryable=true', () {
      const error = AppError.network('接続失敗');
      expect(error.isRetryable, true);
    });

    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('ドキュメントが見つかりません');
      expect(error.isRetryable, false);
    });

    test('auth error は isRetryable=false', () {
      const error = AppError.auth('認証が必要です');
      expect(error.isRetryable, false);
    });

    test('Result.success に Document を格納できる', () {
      final now = DateTime.now();
      final doc = Document(
        id: 'd1', userId: 'u1', type: DocumentType.other,
        title: 'T', fileUrl: 'url', mimeType: FileMimeType.pdf,
        uploadedAt: now, createdAt: now, updatedAt: now,
      );
      final result = Result<Document, AppError>.success(doc);
      expect(result.isSuccess, true);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<Document, AppError>.failure(
        AppError.server('failed'),
      );
      expect(result.isFailure, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('DocumentType と FileMimeType のデフォルト値が存在する', () {
      expect(DocumentType.other, isNotNull);
      expect(FileMimeType.other, isNotNull);
    });

    test('isExpiringSoon: 過去でも未来でも例外にならない', () {
      final past = _makeDocument(
        expiryDate: DateTime(2000, 1, 1),
      );
      final future = _makeDocument(
        expiryDate: DateTime(2099, 12, 31),
      );
      expect(() => past.isExpiringSoon, returnsNormally);
      expect(() => future.isExpiringSoon, returnsNormally);
    });

    test('fileSizeDisplay: 非常に大きなファイルサイズも例外にならない', () {
      final doc = _makeDocument(fileSize: 10 * 1024 * 1024 * 1024); // 10GB
      expect(() => doc.fileSizeDisplay, returnsNormally);
    });
  });
}
